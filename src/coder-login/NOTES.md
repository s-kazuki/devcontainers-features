## Deprecated

This feature is superseded and receives no further updates. On REVONEO's Coder, everything it did is now injected into the dev container at runtime by the Coder template (the `kubernetes-2026` template in [revoneo/_company/coder/manifests](https://gitlab.com/revoneo/_company/coder/manifests)), so remove `coder-login` from each project's `devcontainer.json` and rebuild. Customer repositories should not carry company or personal tooling.

| What this feature did | Where it lives now |
|---|---|
| Resolve the live sub-agent's `CODER_AGENT_TOKEN` and route git through `coder-gitssh` / `coder-gitaskpass` | `coder/modules/devcontainer-coder-env` (cron, `docker exec`) |
| `coder login` at build time so `coder port-forward` etc. work in the container | same module: writes `~/.config/coderv2/{url,session}` at runtime from the outer agent's session. Nothing lands in an image layer, and it is replaced on every workspace build |
| code-server inside the dev container | `coder/modules/code-server-devcontainer` (binary cached on the workspace PVC, `docker cp`, button on the sub-agent) |
| Bake non-secret `CODER_*` / `GIT_*` values | dropped: the sub-agent provides `CODER_*`, and the template pins the git identity |

**Why remove it rather than upgrade:** 1.0.x wrote `CODER_SESSION_TOKEN` and `CODER_AGENT_TOKEN` world-readable into `/etc/profile.d/coder-env.sh` and the image layer. 1.1.0 stopped that, but projects whose `devcontainer-lock.json` pins 1.0.x still have it, and even current versions leave the `coder login` session key in an image layer. Removing the feature and rebuilding clears both.

Existing `:1` references keep working until they are removed.
