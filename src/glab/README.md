### **IMPORTANT NOTE**
- **This Feature is deprecated, and will no longer receive any further updates/support.**

# GitLab CLI (glab) (glab)

Installs a pinned glab and authenticates it from Coder external auth on every call, so no token is ever written to disk.

## Example Usage

```json
"features": {
    "ghcr.io/s-kazuki/devcontainers-features/glab:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | glab version to install (x.y.z). glab has no permanent 'latest' download URL, so this must be pinned. | string | 1.121.0 |
| host | Default GitLab host (GITLAB_HOST) when the caller has not set one. | string | gitlab.com |
| externalAuthId | Coder external auth provider ID to take the token from. Empty disables it (then use GITLAB_TOKEN or `glab auth login`). | string | primary-gitlab |

## Deprecated

This feature is superseded and receives no further updates. On REVONEO's Coder, glab is now injected into the dev container by the Coder template (the `kubernetes-2026` template in [revoneo/_company/coder/manifests](https://gitlab.com/revoneo/_company/coder/manifests)) instead of being declared in each project's `devcontainer.json`. Customer repositories should not carry company or personal tooling, so remove `glab` from them. Existing `:1` references keep working.

Known issue, fixed only in the template version (`coder/modules/glab`): Coder external auth hands out an **OAuth** token, but this wrapper does not set `GLAB_IS_OAUTH2=true`, so glab sends it as a personal access token (`PRIVATE-TOKEN`) and API calls fail with `401 Unauthorized`.

## What it does

`/usr/local/bin/glab` is a wrapper around a pinned glab binary. On every call it fetches a token with `coder external-auth access-token <externalAuthId>`, but only when glab targets the configured host, so a gitlab.com token is never sent to another GitLab. A caller-provided `GITLAB_TOKEN` / `GITLAB_HOST` always wins. Nothing is written to disk.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/s-kazuki/devcontainers-features/blob/main/src/glab/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
