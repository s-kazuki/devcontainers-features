#!/bin/bash
# The install has to land in the remote user's home and leave the config
# volume writable by them; as root both look fine regardless.
set -e

source dev-container-features-test-lib

check "claude runs as the remote user" claude --version
check "config dir belongs to the remote user" bash -c '
  [ "$(stat -c %U /claude-config)" = "$(id -un)" ]
'
check "config dir is private" bash -c '[ "$(stat -c %a /claude-config)" = "700" ]'
check "options honoured" grep -q '^RC_PERMISSION_MODE=acceptEdits$' /usr/local/share/claude-remote-control/options.env

# Without a login there is nothing to start. The script must not fail the
# container start, and must not leave an empty tmux session behind.
check "start without login exits 0" /usr/local/share/claude-remote-control/start.sh
check "no tmux session without login" bash -c '! tmux has-session -t claude-rc 2>/dev/null'

reportResults
