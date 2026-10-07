
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



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/s-kazuki/devcontainers-features/blob/main/src/glab/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
