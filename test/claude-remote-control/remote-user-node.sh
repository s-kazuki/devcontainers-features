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
# On a host whose uid is not 1000 (GitHub runners are 1001) the CLI remaps
# node's uid after install, leaving whatever install.sh chowned behind. Hand
# the volume to a foreign uid and make sure the entrypoint takes it back.
check "entrypoint re-owns the config dir" bash -c '
  sudo chown -R 4242:4242 /claude-config &&
  sudo /usr/local/share/claude-remote-control/entrypoint.sh &&
  [ "$(stat -c %u /claude-config)" = "$(id -u)" ]
'
check "entrypoint execs its arguments" bash -c '
  [ "$(/usr/local/share/claude-remote-control/entrypoint.sh echo ok)" = ok ]
'
check "options honoured" grep -q '^RC_PERMISSION_MODE=acceptEdits$' /usr/local/share/claude-remote-control/options.env

# Without a login there is nothing to start. The script must not fail the
# container start, and must not leave an empty tmux session behind.
check "start without login exits 0" /usr/local/share/claude-remote-control/start.sh
check "no tmux session without login" bash -c '! tmux has-session -t claude-rc 2>/dev/null'

# In a VS Code dev container `claude auth status` answered on a terminal but
# came back empty to this script, which then refused to start. An unreadable
# status must not be taken for "signed out".
fake=$(mktemp -d)
cat > "$fake/claude" <<'FAKE'
#!/bin/bash
[ "$1 $2" = "auth status" ] && exit 0
exec sleep 600
FAKE
chmod +x "$fake/claude"
check "empty auth status does not block the start" bash -c "
  PATH='$fake':\$PATH /usr/local/share/claude-remote-control/start.sh 2>&1 | grep -q 'started in tmux session'
"
check "remote control running in tmux" tmux has-session -t claude-rc
tmux kill-session -t claude-rc 2>/dev/null || true

# Session name: the Coder workspace name when one can be found, else the
# workspace folder name. The stand-in claude above lets start.sh run through.
started_as() {
    local out
    out="$(env "$@" PATH="$fake:$PATH" /usr/local/share/claude-remote-control/start.sh 2>&1)"
    tmux kill-session -t claude-rc 2>/dev/null || true
    sed -n "s/.* as '\([^']*\)' from .*/\1/p" <<<"$out"
}
export -f started_as
export fake
check "outside Coder the folder name is used" bash -c '
  [ "$(started_as -u CODER_WORKSPACE_NAME)" = "$(basename "$PWD")" ]
'
check "CODER_WORKSPACE_NAME is used" bash -c '
  [ "$(started_as CODER_WORKSPACE_NAME=my-ws)" = my-ws ]
'
# Lifecycle commands may lack CODER_* while the Coder sub-agent in the
# container has them. Stand in for that agent with a process of the same name.
check "the Coder sub-agent's environment is used" bash -c '
  sudo mkdir -p /.coder-agent &&
  printf "#!/bin/bash\nsleep 600\n" | sudo tee /.coder-agent/coder >/dev/null &&
  sudo chmod +x /.coder-agent/coder &&
  (CODER_WORKSPACE_NAME=agent-ws setsid /.coder-agent/coder agent >/dev/null 2>&1 &) &&
  sleep 1 &&
  name="$(started_as -u CODER_WORKSPACE_NAME)"
  pkill -f "^/bin/bash /\.coder-agent/coder agent"
  [ "$name" = agent-ws ]
'
check "/etc/environment is used when the variable is missing" bash -c '
  echo "CODER_WORKSPACE_NAME=\"etc-ws\"" | sudo tee -a /etc/environment >/dev/null &&
  [ "$(started_as -u CODER_WORKSPACE_NAME)" = etc-ws ]
'

reportResults
