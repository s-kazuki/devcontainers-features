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
    log "$CLAUDE_CONFIG_DIR is not writable by $(id -un); the shared volume was probably created by a different uid. Skipping."
    exit 0
fi

# Remote Control only works with a claude.ai login, not an API key. Without
# one there is nothing to start; leave a hint instead of a dead tmux pane.
auth_status="$(timeout 30 "$CLAUDE_BIN" auth status 2>/dev/null || true)"
if ! grep -q '"loggedIn": *true' <<<"$auth_status"; then
    log "not logged in. Run 'claude' once in this container to sign in, then restart the container or run $SHARE_DIR/start.sh."
    exit 0
fi
if ! grep -q '"authMethod": *"claude.ai"' <<<"$auth_status"; then
    log "logged in without a claude.ai account; Remote Control needs one. Skipping."
    exit 0
fi

name="${RC_SESSION_NAME:-$(basename "$PWD")}"
args=("$CLAUDE_BIN" remote-control --name "$name" --spawn "$RC_SPAWN")
if [[ "$RC_PERMISSION_MODE" != "default" ]]; then
    args+=(--permission-mode "$RC_PERMISSION_MODE")
fi

# tmux rather than nohup: the first run in an untrusted folder asks whether to
# trust it, and that prompt needs a terminal someone can attach to.
tmux new-session -d -s "$TMUX_SESSION" -c "$PWD" "$(printf '%q ' "${args[@]}")"
# Keep the pane around if claude exits, so the error stays readable.
tmux set-option -t "$TMUX_SESSION" remain-on-exit on >/dev/null

log "started in tmux session '$TMUX_SESSION' as '$name' (tmux attach -t $TMUX_SESSION)"
