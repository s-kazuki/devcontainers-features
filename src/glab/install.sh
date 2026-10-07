#!/usr/bin/env bash
set -euo pipefail

GLAB_VERSION="${VERSION:-1.121.0}"
GLAB_VERSION="${GLAB_VERSION#v}"
GLAB_HOST="${HOST:-gitlab.com}"
GLAB_EXTERNAL_AUTH_ID="${EXTERNALAUTHID:-}"

# The install script runs inside the target container, so the architecture is
# whatever this container is. glab's asset names use the Go spelling.
case "$(uname -m)" in
    x86_64)        arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "glab: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac

for tool in curl tar sha256sum; do
    command -v "$tool" >/dev/null 2>&1 && continue
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq && apt-get install -y -qq --no-install-recommends curl ca-certificates tar coreutils
        rm -rf /var/lib/apt/lists/*
        break
    fi
    echo "glab: $tool is required" >&2; exit 1
done

# No permanent "latest" link exists (gitlab-org/cli#1221), so build the URL
# from the pinned version and verify it against the published checksums.
base="https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads"
asset="glab_${GLAB_VERSION}_linux_${arch}.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/$asset" "$base/$asset"
curl -fsSL -o "$tmp/checksums.txt" "$base/checksums.txt"
(cd "$tmp" && grep " ${asset}\$" checksums.txt | sha256sum -c -)

mkdir -p "$tmp/x" /usr/local/lib/glab
tar -xzf "$tmp/$asset" -C "$tmp/x"
install -m 0755 "$(find "$tmp/x" -type f -name glab -perm -u+x | head -1)" /usr/local/lib/glab/glab

# The token is fetched on every call and only lives in this process's
# environment. Snapshotting it into a file or an image layer is the
# 2026-09-08 stale-agent-token incident all over again.
cat > /usr/local/bin/glab <<WRAPPER
#!/bin/sh
# Which host will glab talk to? GITLAB_HOST if set, else the origin remote of
# the current repository (glab infers it from there), else the default.
_target="\${GITLAB_HOST:-}"
if [ -z "\$_target" ]; then
    _url=\$(git remote get-url origin 2>/dev/null || true)
    _target=\$(printf '%s' "\$_url" | sed -E 's#^[a-z+]+://##; s#^[^@/]*@##; s#[:/].*##')
fi
[ -n "\$_target" ] || _target="${GLAB_HOST}"

# Only hand over the Coder token when glab is going to the host that token is
# for. GITLAB_TOKEN is sent to whatever host glab targets, so injecting it in a
# repository on another GitLab (e.g. a client's) would leak it there.
if [ -z "\${GITLAB_TOKEN:-}\${GITLAB_ACCESS_TOKEN:-}\${OAUTH_TOKEN:-}" ] \
   && [ -n "${GLAB_EXTERNAL_AUTH_ID}" ] && [ "\$_target" = "${GLAB_HOST}" ]; then
    # Agent credentials rotate on every workspace build; reuse coder-login's
    # resolver when it is installed so a stale shell still authenticates.
    [ -r /usr/local/lib/coder-login/agent-env.sh ] && . /usr/local/lib/coder-login/agent-env.sh
    _coder=/.coder-agent/coder
    [ -x "\$_coder" ] || _coder=coder
    if _tok=\$("\$_coder" external-auth access-token "${GLAB_EXTERNAL_AUTH_ID}" 2>/dev/null) && [ -n "\$_tok" ]; then
        export GITLAB_TOKEN="\$_tok"
    fi
    unset _coder _tok
fi
export GITLAB_HOST="\${GITLAB_HOST:-\$_target}"
unset _target _url
exec /usr/local/lib/glab/glab "\$@"
WRAPPER
chmod 0755 /usr/local/bin/glab

/usr/local/lib/glab/glab --version
