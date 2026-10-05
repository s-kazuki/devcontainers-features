#!/bin/bash
# Runs against the base images with the feature's default options, as root.
set -e

source dev-container-features-test-lib

check "claude installed" bash -c 'command -v claude'
check "tmux installed" bash -c 'command -v tmux'
check "start script installed" test -x /usr/local/share/claude-remote-control/start.sh
check "options generated" grep -q '^RC_SPAWN=same-dir$' /usr/local/share/claude-remote-control/options.env
check "config dir is the volume" bash -c '[ "$CLAUDE_CONFIG_DIR" = /claude-config ] && test -d /claude-config'

reportResults
