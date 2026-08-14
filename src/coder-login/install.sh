#!/usr/bin/env bash
set -e

CODE_SERVER_INSTALL_ARGS=""

if [[ -n $VERSION ]]; then
	CODE_SERVER_INSTALL_ARGS="$CODE_SERVER_INSTALL_ARGS --version=\"$VERSION\""
fi

curl -fsSL https://code-server.dev/install.sh | sh -s -- $CODE_SERVER_INSTALL_ARGS

if [[ -n "$EXTENSIONS" ]]; then
    IFS=',' read -ra extensions <<<"$EXTENSIONS"

    for extension in "${extensions[@]}"
    do
        if ! su "$_REMOTE_USER" -c "code-server --install-extension '$extension'"; then
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

if [[ \$(whoami) != "$_REMOTE_USER" ]]; then
	exec su $_REMOTE_USER -c /usr/local/bin/code-server-entrypoint
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

if ! command -v coder >/dev/null 2>&1; then
    echo "Coder CLI could not be found. Please ensure it is installed by another feature."
    exit 1
fi

CODER_ENV_PATH=/etc/profile.d/coder-env.sh

> "$CODER_ENV_PATH"
chmod +x "$CODER_ENV_PATH"

env | grep '^CODER' | while IFS='=' read -r key value; do
  echo "export ${key}='${value}'" >> "$CODER_ENV_PATH"
done
env | grep '^GIT' | while IFS='=' read -r key value; do
  echo "export ${key}='${value}'" >> "$CODER_ENV_PATH"
done
echo "export GIT_SSH_COMMAND='coder gitssh --'" >> "$CODER_ENV_PATH"

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

# Also register the same values in /etc/environment for processes that
# never go through a shell init file at all (e.g. an editor's extension
# host attaching directly via `docker exec`).
env | grep -E '^(CODER|GIT)' | while IFS='=' read -r key value; do
    if ! grep -qF "${key}=" /etc/environment 2>/dev/null; then
        echo "${key}=\"${value}\"" >> /etc/environment
    fi
done
if ! grep -qF "GIT_SSH_COMMAND=" /etc/environment 2>/dev/null; then
    echo 'GIT_SSH_COMMAND="coder gitssh --"' >> /etc/environment
fi

coder login --url=${CODER_URL} --token=${CODER_SESSION_TOKEN}
