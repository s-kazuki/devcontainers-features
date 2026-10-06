#!/usr/bin/env bash
# postStartCommand: runs as the remote user from the workspace folder on every
# container start. A failure here would abort the whole container start, so
# anything short of a broken install only warns and exits 0.
set -u

SHARE_DIR=/usr/local/share/claude-remote-control
TMUX_SESSION=claude-rc

# shellcheck source=/dev/null
. "$SHARE_DIR/options.env"

log() { echo "claude-remote-control: $*" >&2; }

if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    log "already running (tmux attach -t $TMUX_SESSION)"
    exit 0
fi

CLAUDE_BIN="$(command -v claude || true)"
if [[ -z "$CLAUDE_BIN" && -x "$HOME/.local/bin/claude" ]]; then
    CLAUDE_BIN="$HOME/.local/bin/claude"
fi
if [[ -z "$CLAUDE_BIN" ]]; then
    log "claude not found on PATH; skipping."
    exit 0
fi

if [[ -n "${CLAUDE_CONFIG_DIR:-}" && ! -w "$CLAUDE_CONFIG_DIR" ]]; then
    log "$CLAUDE_CONFIG_DIR is not writable by $(id -un) and the entrypoint could not re-own it. Skipping."
    exit 0
fi

# Remote Control only works with a claude.ai login, not an API key. Without
# one there is nothing to start; leave a hint instead of a dead tmux pane.
#
# In a VS Code dev container `claude auth status` was seen to answer on a
# terminal but leave nothing in a command substitution, which this script used
# to read as "not logged in". Read it from a file with stdin closed, and only
# treat an explicit "loggedIn": false as signed out.
auth_file="$(mktemp)"
timeout 15 "$CLAUDE_BIN" auth status </dev/null >"$auth_file" 2>/dev/null
auth_rc=$?
auth_status="$(<"$auth_file")"
rm -f "$auth_file"

if grep -q '"loggedIn": *false' <<<"$auth_status"; then
    log "not logged in. Run 'claude' once in this container to sign in, then restart the container or run $SHARE_DIR/start.sh."
    exit 0
elif ! grep -q '"loggedIn": *true' <<<"$auth_status"; then
    # Unknown is not the same as signed out. Start anyway: if there really is
    # no login, the error stays readable in the tmux pane.
    log "could not read 'claude auth status' (exit $auth_rc); starting anyway."
elif ! grep -q '"authMethod": *"claude.ai"' <<<"$auth_status"; then
    log "logged in without a claude.ai account; Remote Control needs one. Skipping."
    exit 0
fi

# Inside Coder the workspace name says more than the folder name (often just
# /workspaces/<repo> or /node). Lifecycle commands do not always inherit the
# CODER_* variables a Coder terminal has, so also look where the coder-login
# feature finds them: the sub-agent's environment, then /etc/environment.
coder_workspace_name() {
    local pid value
    if [[ -n "${CODER_WORKSPACE_NAME:-}" ]]; then
        echo "env:$CODER_WORKSPACE_NAME"
        return
    fi
    for pid in $(pgrep -f '/\.coder-agent/coder agent' 2>/dev/null); do
        value="$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | sed -n 's/^CODER_WORKSPACE_NAME=//p')"
        if [[ -n "$value" ]]; then
            echo "agent:$value"
            return
        fi
    done
    value="$(sed -n 's/^CODER_WORKSPACE_NAME="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' /etc/environment 2>/dev/null)"
    if [[ -n "$value" ]]; then
        echo "/etc/environment:$value"
    fi
}

if [[ -n "$RC_SESSION_NAME" ]]; then
    name="$RC_SESSION_NAME" name_source="option"
elif found="$(coder_workspace_name)" && [[ -n "$found" ]]; then
    name="${found#*:}" name_source="Coder workspace (${found%%:*})"
else
    name="$(basename "$PWD")" name_source="folder"
fi
args=("$CLAUDE_BIN" remote-control --name "$name" --spawn "$RC_SPAWN")
if [[ "$RC_PERMISSION_MODE" != "default" ]]; then
    args+=(--permission-mode "$RC_PERMISSION_MODE")
fi

# tmux rather than nohup: the first run in an untrusted folder asks whether to
# trust it, and that prompt needs a terminal someone can attach to.
tmux new-session -d -s "$TMUX_SESSION" -c "$PWD" "$(printf '%q ' "${args[@]}")"
# Keep the pane around if claude exits, so the error stays readable.
tmux set-option -t "$TMUX_SESSION" remain-on-exit on >/dev/null

log "started in tmux session '$TMUX_SESSION' as '$name' from $name_source (tmux attach -t $TMUX_SESSION)"
