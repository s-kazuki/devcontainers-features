#!/bin/bash
set -e

source dev-container-features-test-lib

check "glab runs" bash -c "glab --version | grep -q 'glab'"
check "wrapper is on PATH" bash -c '[ "$(command -v glab)" = /usr/local/bin/glab ]'
check "binary pinned to the requested version" bash -c "/usr/local/lib/glab/glab --version | grep -q '1.121.0'"
check "default host applied" grep -qF '_target="gitlab.com"' /usr/local/bin/glab

# Never bake a token: it must be fetched per call.
check "no token baked into the wrapper" bash -c '! grep -qE "glpat-|GITLAB_TOKEN=[\"\x27]?[A-Za-z0-9_-]{16}" /usr/local/bin/glab'
check "caller-provided token wins" bash -c "grep -q 'GITLAB_TOKEN:-' /usr/local/bin/glab"

# Regression: a gitlab.com token must not be sent to another GitLab when the
# repository's origin points elsewhere (e.g. a client's self-hosted GitLab).
check "token only injected for the configured host" grep -qF '[ "$_target" = "gitlab.com" ]' /usr/local/bin/glab

reportResults
