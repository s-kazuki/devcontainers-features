#!/usr/bin/env bash
# Feature entrypoint: runs on every container start as the container user,
# which is root in the dev container base images.
#
# The uid that install.sh chowned /claude-config to is not the one the remote
# user ends up with. On Linux the dev container CLI rewrites the remote user's
# uid to the host user's after the features are installed (updateRemoteUserUID)
# and re-owns only their home directory. The shared volume can also have been
# seeded by a container whose remote user had another uid. Either way the
# remote user cannot write their own config, so fix the ownership here, where
# the final uid is known and there is still root to do it.
set -u

SHARE_DIR=/usr/local/share/claude-remote-control
CLAUDE_CONFIG_DIR=/claude-config

# shellcheck source=/dev/null
. "$SHARE_DIR/options.env"

owner="$RC_REMOTE_USER_OWNER"
if [[ -n "$RC_REMOTE_USER_NAME" ]] && uid="$(id -u "$RC_REMOTE_USER_NAME" 2>/dev/null)"; then
    owner="$uid:$(id -g "$RC_REMOTE_USER_NAME")"
fi

if [[ -d "$CLAUDE_CONFIG_DIR" && "$(stat -c %u "$CLAUDE_CONFIG_DIR")" != "${owner%%:*}" ]]; then
    if [[ "$(id -u)" == 0 ]]; then
        chown -R "$owner" "$CLAUDE_CONFIG_DIR"
    elif sudo -n true 2>/dev/null; then
        sudo -n chown -R "$owner" "$CLAUDE_CONFIG_DIR"
    else
        echo "claude-remote-control: cannot re-own $CLAUDE_CONFIG_DIR to $owner without root." >&2
    fi
fi

# Never stand in the way of the container starting.
if [[ $# -gt 0 ]]; then
    exec "$@"
fi
