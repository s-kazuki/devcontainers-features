#!/bin/bash
# Runs against the base images with the feature's default options, as root.
# Nothing here may depend on who the remote user is -- the ownership
# assertions live in the `remote-user-node` scenario instead.
set -e

source dev-container-features-test-lib

CODER_ENV=/etc/profile.d/coder-env.sh

check "entrypoint installed" test -x /usr/local/bin/code-server-entrypoint
check "env file generated" test -f "$CODER_ENV"
check "env file is world readable" bash -c '[ "$(stat -c %a /etc/profile.d/coder-env.sh)" = "644" ]'

# Agent credentials rotate on every workspace build, so the feature must
# resolve them from the running sub-agent at shell start rather than bake a
# snapshot in. Assert the resolver, not just the absence of the snapshot.
check "agent token resolved at runtime" grep -q '/proc/' "$CODER_ENV"
check "GIT_SSH_COMMAND fallback present" grep -q 'gitssh' "$CODER_ENV"

# /etc/profile.d is only read by login shells; the feature also has to reach
# the non-login interactive shells that VS Code and `devcontainer exec` start.
check "sourced from /etc/bash.bashrc" grep -qF "$CODER_ENV" /etc/bash.bashrc

# Regression test for the 2026-09-08 incident: credentials were being written
# into the image. A plain `CODER_AGENT_TOKEN` search false-positives on the
# resolver's own `sed` expression, so match the assignment form and the shape
# of the value instead.
check "no credential assignment baked in" bash -c '
  ! grep -qE "^(export )?(CODER_AGENT_TOKEN|CODER_SESSION_TOKEN|CODER_AGENT_AUTH)=" \
      /etc/profile.d/coder-env.sh /etc/environment
'
check "no UUID-shaped secret baked in" bash -c '
  ! grep -qE "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" \
      /etc/profile.d/coder-env.sh /etc/environment /etc/bash.bashrc
'

reportResults
