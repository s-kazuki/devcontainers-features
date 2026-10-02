#!/bin/bash
# A docker-compose service that pins `user: "1000:1000"` makes the dev
# container tooling hand the feature a "uid:gid" pair in $_REMOTE_USER instead
# of a login name. `id -gn 1000:1000` then fails and the chown that follows
# dies with `chown: invalid group: '1000:1000:'`, aborting the whole build.
# This scenario pins the same shape of remoteUser so install.sh has to
# normalise it.
set -e

source dev-container-features-test-lib

check "config dir exists in the remote user's home" test -d "$HOME/.config/coderv2"
check "config dir belongs to the remote user" bash -c '
  [ "$(stat -c %u "$HOME/.config/coderv2")" = "$(id -u)" ]
'
check "config dir is private" bash -c '
  [ "$(stat -c %a "$HOME/.config/coderv2")" = "700" ]
'

# The entrypoint drops privileges itself, so it must not carry the raw
# "uid:gid" string into a `su` that cannot parse it.
check "entrypoint installed" test -x /usr/local/bin/code-server-entrypoint
check "entrypoint compares numeric uids" grep -q 'id -u' /usr/local/bin/code-server-entrypoint
check "entrypoint does not su a uid:gid pair" bash -c '
  ! grep -qE "^\s*exec su [0-9]+:[0-9]+ " /usr/local/bin/code-server-entrypoint
'

reportResults
