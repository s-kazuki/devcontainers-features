## Deprecated

This feature is superseded and receives no further updates. On REVONEO's Coder, glab is now injected into the dev container by the Coder template (the `kubernetes-2026` template in [revoneo/_company/coder/manifests](https://gitlab.com/revoneo/_company/coder/manifests)) instead of being declared in each project's `devcontainer.json`. Customer repositories should not carry company or personal tooling, so remove `glab` from them. Existing `:1` references keep working.

## What it does

`/usr/local/bin/glab` is a wrapper around a pinned glab binary. On every call it fetches a token with `coder external-auth access-token <externalAuthId>`, but only when glab targets the configured host, so a gitlab.com token is never sent to another GitLab. A caller-provided `GITLAB_TOKEN` / `GITLAB_HOST` always wins. Nothing is written to disk.
