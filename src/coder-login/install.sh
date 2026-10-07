#!/usr/bin/env bash
set -e

# Dev container tooling does not always hand us a login name here. With a
# docker-compose service that pins `user: "1000:1000"`, _REMOTE_USER arrives as
# a "uid:gid" pair, and a bare numeric uid is possible too. `id`, `su` and
# `chown` do not accept those interchangeably, so normalise once:
#   _REMOTE_USER_OWNER - a "user:group" spec chown understands
#   _REMOTE_USER_NAME  - a login name for su, empty when there is no passwd entry
#   _REMOTE_USER_UID   - the numeric uid, for comparing against `id -u`
: "${_REMOTE_USER:?coder-login: _REMOTE_USER is not set}"

_REMOTE_USER_ID="${_REMOTE_USER%%:*}"
_REMOTE_GROUP_ID=""
if [[ "$_REMOTE_USER" == *:* ]]; then
    _REMOTE_GROUP_ID="${_REMOTE_USER##*:}"
fi

_REMOTE_USER_NAME=""
_REMOTE_USER_UID="$_REMOTE_USER_ID"
if _remote_user_passwd="$(getent passwd "$_REMOTE_USER_ID" 2>/dev/null)"; then
    IFS=':' read -r _remote_name _ _remote_uid _remote_gid _ <<<"$_remote_user_passwd"
    _REMOTE_USER_NAME="$_remote_name"
    _REMOTE_USER_UID="$_remote_uid"
    if [[ -z "$_REMOTE_GROUP_ID" ]]; then
        _REMOTE_GROUP_ID="$_remote_gid"
    fi
    unset _remote_name _remote_uid _remote_gid
fi

# Without a group, chown leaves the existing group in place, which is the
# right fallback for a uid that has no passwd entry at all.
_REMOTE_USER_OWNER="${_REMOTE_USER_ID}${_REMOTE_GROUP_ID:+:${_REMOTE_GROUP_ID}}"

# su only takes a name. Anything that needs to run as the remote user has to
# fail loudly rather than silently run as root.
run_as_remote_user() {
    if [[ -z "$_REMOTE_USER_NAME" ]]; then
        echo "coder-login: no passwd entry for uid '$_REMOTE_USER_ID'; cannot run commands as the remote user." >&2
        return 1
    fi
    su "$_REMOTE_USER_NAME" -c "$1"
}

CODE_SERVER_INSTALL_ARGS=""

if [[ -n $VERSION ]]; then
	CODE_SERVER_INSTALL_ARGS="$CODE_SERVER_INSTALL_ARGS --version=\"$VERSION\""
fi

curl -fsSL https://code-server.dev/install.sh | sh -s -- $CODE_SERVER_INSTALL_ARGS

if [[ -n "$EXTENSIONS" ]]; then
    IFS=',' read -ra extensions <<<"$EXTENSIONS"

    for extension in "${extensions[@]}"
    do
        if ! run_as_remote_user "code-server --install-extension '$extension'"; then
            echo "ERROR: Failed to install extension '$extension' as user '$_REMOTE_USER'" >&2
            exit 1
        fi
    done
fi

CODE_SERVER_WORKSPACE="$_REMOTE_USER_HOME"

if [[ -n $WORKSPACE ]]; then
    CODE_SERVER_WORKSPACE="$WORKSPACE"
fi

FLAGS=()
FLAGS+=(--auth "$AUTH")
FLAGS+=(--bind-addr "$HOST:$PORT")

if [[ "$DISABLEFILEDOWNLOADS" == "true" ]]; then
    FLAGS+=(--disable-file-downloads)
fi

if [[ "$DISABLEFILEUPLOADS" == "true" ]]; then
    FLAGS+=(--disable-file-uploads)
fi

if [[ "$DISABLEGETTINGSTARTEDOVERRIDE" == "true" ]]; then
    FLAGS+=(--disable-getting-started-override)
fi

if [[ "$DISABLEPROXY" == "true" ]]; then
    FLAGS+=(--disable-proxy)
fi

if [[ "$DISABLETELEMETRY" == "true" ]]; then
    FLAGS+=(--disable-telemetry)
fi

if [[ "$DISABLEUPDATECHECK" == "true" ]]; then
    FLAGS+=(--disable-update-check)
fi

if [[ "$DISABLEWORKSPACETRUST" == "true" ]]; then
    FLAGS+=(--disable-workspace-trust)
fi

if [[ -n "$CERT" ]]; then
    FLAGS+=(--cert "$CERT")
fi

if [[ -n "$CERTHOST" ]]; then
    FLAGS+=(--cert-host "$CERTHOST")
fi

if [[ -n "$CERTKEY" ]]; then
    FLAGS+=(--cert-key "$CERTKEY")
fi

if [[ -n "$SOCKET" ]]; then
    FLAGS+=(--socket "$SOCKET")
fi

if [[ -n "$SOCKETMODE" ]]; then
    FLAGS+=(--socket-mode "$SOCKETMODE")
fi

if [[ -n "$LOCALE" ]]; then
    FLAGS+=(--locale "$LOCALE")
fi

if [[ -n "$APPNAME" ]]; then
	FLAGS+=(--app-name "$APPNAME")
fi

if [[ -n "$WELCOMETEXT" ]]; then
    FLAGS+=(--welcome-text "$WELCOMETEXT")
fi

if [[ "$VERBOSE" == "true" ]]; then
    FLAGS+=(--verbose)
fi

IFS=',' read -ra trusted_origins <<<"$TRUSTEDORIGINS"

for trusted_origin in "${trusted_origins[@]}"; do
    FLAGS+=(--trusted-origins "$trusted_origin")
done

IFS=',' read -ra proposed_api_extensions <<<"$ENABLEPROPOSEDAPI"

for extension in "${proposed_api_extensions[@]}"; do
    FLAGS+=(--enable-proposed-api "$extension")
done

if [[ "$PROXYDOMAIN" ]]; then
    FLAGS+=(--proxy-domain "$PROXYDOMAIN")
fi

if [[ "$ABSPROXYBASEPATH" ]]; then
    FLAGS+=(--abs-proxy-base-path "$ABSPROXYBASEPATH")
fi

cat > /usr/local/bin/code-server-entrypoint <<EOF
#!/usr/bin/env bash
set -e

if [[ \$(id -u) != "$_REMOTE_USER_UID" ]]; then
	exec su ${_REMOTE_USER_NAME:-$_REMOTE_USER} -c /usr/local/bin/code-server-entrypoint
fi

$(declare -p FLAGS)

if [[ -f "$PASSWORDFILE" ]]; then
	export PASSWORD="\$(<"$PASSWORDFILE")"
fi

if [[ -f "$HASHEDPASSWORDFILE" ]]; then
	export HASHED_PASSWORD="\$(<"$HASHEDPASSWORDFILE")"
fi

if [[ -f "$GITHUBAUTHTOKENFILE" ]]; then
    export GITHUB_TOKEN="\$(<"$GITHUBAUTHTOKENFILE")"
fi

code-server "\${FLAGS[@]}" "$CODE_SERVER_WORKSPACE" >"$LOGFILE" 2>&1
EOF

chmod +x /usr/local/bin/code-server-entrypoint

##########

# Generating the env file below does not need the Coder CLI: the references to
# it in $CODER_ENV_PATH are resolved when a shell starts, not now. Only the
# `coder login` branch at the end of this script actually invokes it, so the
# hard error lives there instead of here. Warn, so a feature ordering mistake
# is still visible in the build log.
if ! command -v coder >/dev/null 2>&1; then
    echo "coder-login: Coder CLI not found on PATH at install time." >&2
fi

CODER_ENV_PATH=/etc/profile.d/coder-env.sh

# Only non-secret, build-stable values are baked into the image.
#
# Credentials are deliberately excluded. Agent tokens are re-issued on every
# workspace build (they are valid only while their build is the latest one),
# so a snapshot taken at feature-install time goes stale the first time the
# workspace restarts. Worse, anything written here is readable by every user
# in the container and is captured in the image layer.
{
    echo '# Generated by the coder-login dev container feature. Do not edit.'
    for key in CODER CODER_URL \
               CODER_WORKSPACE_ID CODER_WORKSPACE_NAME \
               CODER_WORKSPACE_OWNER_NAME CODER_WORKSPACE_AGENT_NAME \
               GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL \
               GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL; do
        value="${!key-}"
        [[ -n "$value" ]] || continue
        printf 'export %s=%q\n' "$key" "$value"
    done
} > "$CODER_ENV_PATH"

# Agent credentials rotate on every workspace build (a token is only valid
# while its build is the latest one), so they are resolved from the running
# sub-agent rather than baked in. Coder execs the sub-agent inside this
# container with the current credentials in its environment.
#
# v1.2.0: the live sub-agent always wins. v1.1.x kept whatever was already
# set, but a devcontainer is restarted, not recreated, when the workspace
# restarts, so `docker exec` shells (VS Code attach included) inherit the
# token frozen in the container's Config.Env at creation time. "Already set"
# cannot tell that stale value from a correct one; the live agent can.
_CODER_LIB=/usr/local/lib/coder-login
mkdir -p "$_CODER_LIB"
cat > "$_CODER_LIB/agent-env.sh" <<'CODER_AGENT_ENV'
# Sourced, POSIX sh. Exports CODER_AGENT_TOKEN / CODER_AGENT_URL from the
# newest running sub-agent. Leaves the inherited values alone only when no
# readable sub-agent exists (e.g. outside Coder, or before it has started).
_coder_pids="$(pgrep -n -f '/\.coder-agent/coder agent' 2>/dev/null) $(pgrep -f '/\.coder-agent/coder agent' 2>/dev/null)"
for _coder_pid in $_coder_pids; do
    [ -r "/proc/${_coder_pid}/environ" ] || continue
    _coder_tok=$(tr '\0' '\n' < "/proc/${_coder_pid}/environ" | sed -n 's/^CODER_AGENT_TOKEN=//p')
    [ -n "${_coder_tok}" ] || continue
    _coder_url=$(tr '\0' '\n' < "/proc/${_coder_pid}/environ" | sed -n 's/^CODER_AGENT_URL=//p')
    export CODER_AGENT_TOKEN="${_coder_tok}"
    [ -n "${_coder_url}" ] && export CODER_AGENT_URL="${_coder_url}"
    break
done
unset _coder_pids _coder_pid _coder_tok _coder_url
CODER_AGENT_ENV
chmod 0644 "$_CODER_LIB/agent-env.sh"

# git calls these on every fetch/push, so credentials are resolved per call
# and a long-lived shell cannot go stale even after the workspace restarts.
for _wrapper in gitssh gitaskpass; do
    cat > "/usr/local/bin/coder-${_wrapper}" <<CODER_WRAPPER
#!/bin/sh
. $_CODER_LIB/agent-env.sh
if [ -x /.coder-agent/coder ]; then
    exec /.coder-agent/coder ${_wrapper} "\$@"
fi
exec coder ${_wrapper} "\$@"
CODER_WRAPPER
    chmod 0755 "/usr/local/bin/coder-${_wrapper}"
done
unset _wrapper

cat >> "$CODER_ENV_PATH" <<CODER_AGENT_RESOLVER

. $_CODER_LIB/agent-env.sh

# Always route git through the wrappers. The value the agent sets points at
# the right binary but relies on the token in this shell's environment, which
# is exactly what goes stale.
export GIT_SSH_COMMAND='/usr/local/bin/coder-gitssh --'
case "\${GIT_ASKPASS:-}" in
    ''|*coder*) export GIT_ASKPASS=/usr/local/bin/coder-gitaskpass ;;
esac
CODER_AGENT_RESOLVER

chmod 0644 "$CODER_ENV_PATH"

# /etc/profile.d is only sourced by login shells. VS Code's integrated
# terminal and most devcontainer exec paths start non-login shells, so
# they never pick up $CODER_ENV_PATH from there. Source it from the
# files non-login interactive shells do read, for every shell we might
# find in the container.
touch /etc/bash.bashrc
if ! grep -qF "$CODER_ENV_PATH" /etc/bash.bashrc; then
    echo ". $CODER_ENV_PATH" >> /etc/bash.bashrc
fi

if [[ -d /etc/zsh ]]; then
    touch /etc/zsh/zshenv
    if ! grep -qF "$CODER_ENV_PATH" /etc/zsh/zshenv; then
        echo ". $CODER_ENV_PATH" >> /etc/zsh/zshenv
    fi
fi

# /etc/environment holds plain key=value pairs and is read before any shell
# init runs, so it cannot resolve anything at runtime. Only the same
# non-secret, stable values go here.
for key in CODER CODER_URL \
           CODER_WORKSPACE_ID CODER_WORKSPACE_NAME \
           CODER_WORKSPACE_OWNER_NAME CODER_WORKSPACE_AGENT_NAME \
           GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL \
           GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL; do
    value="${!key-}"
    [[ -n "$value" ]] || continue
    grep -qE "^${key}=" /etc/environment 2>/dev/null && continue
    printf '%s="%s"\n' "$key" "$value" >> /etc/environment
done

# `coder login --token` does not persist the token it is given: it uses it
# once to mint a fresh session key and stores that instead.
#
# $CODER_CONFIG_DIR defaults to ~/.config/coderv2, which resolves against
# root's home during feature install. The remote user then cannot read the
# session and every `coder` invocation reports "signed out". Point the config
# dir at the remote user's home and hand ownership over.
#
# An empty _REMOTE_USER_HOME would make _CODER_CFG /.config/coderv2 and point
# the chown -R below at the root of the filesystem.
: "${_REMOTE_USER_HOME:?coder-login: _REMOTE_USER_HOME is not set}"
_CODER_CFG="${_REMOTE_USER_HOME}/.config/coderv2"
mkdir -p "$_CODER_CFG"
chown -R "$_REMOTE_USER_OWNER" "${_REMOTE_USER_HOME}/.config"
chmod 700 "$_CODER_CFG"

if [[ -n "${CODER_URL:-}" && -n "${CODER_SESSION_TOKEN:-}" ]]; then
    command -v coder >/dev/null 2>&1 || {
        echo "coder-login: credentials were provided but the Coder CLI is missing." >&2
        exit 1
    }
    CODER_CONFIG_DIR="$_CODER_CFG" \
        coder login --url="$CODER_URL" --token="$CODER_SESSION_TOKEN" --use-keyring=false
    chown -R "$_REMOTE_USER_OWNER" "$_CODER_CFG"
else
    echo "coder-login: CODER_URL / CODER_SESSION_TOKEN not set; skipping 'coder login'." >&2
fi
