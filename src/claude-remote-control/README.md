
# Claude Code Remote Control (claude-remote-control)

Start `claude remote-control` in a detached tmux session on container start, so the workspace is reachable from claude.ai/code and the Claude mobile app

## Example Usage

```json
"features": {
    "ghcr.io/s-kazuki/devcontainers-features/claude-remote-control:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| installClaude | Install Claude Code with the native installer when `claude` is not already on PATH. | boolean | true |
| sessionName | Name shown in claude.ai/code. Defaults to the Coder workspace name, or the workspace folder name outside Coder. | string | - |
| permissionMode | Permission mode for sessions spawned through Remote Control. | string | default |
| spawn | How Remote Control spawns sessions. 'worktree' requires a git repository. | string | same-dir |

## First run

Remote Control needs a claude.ai login (an API key is not enough), so the very first start only prints a hint:

1. Open a terminal in the container and run `claude`. Sign in, and accept the folder trust prompt.
2. Restart the container, or run `/usr/local/share/claude-remote-control/start.sh`.

After that, every container start brings up `claude remote-control` in a detached tmux session and the workspace shows up in [claude.ai/code](https://claude.ai/code) and the Claude mobile app. `tmux attach -t claude-rc` shows what it is doing.

## Where the login lives

`CLAUDE_CONFIG_DIR` points at `/claude-config`, which is the `claude-code-config` named volume. Every dev container using this feature on the same Docker host shares that volume, so you sign in once per host, not once per project. On every container start the feature's entrypoint re-owns the volume to the remote user's current uid, so it keeps working when the dev container CLI remaps that uid to the host user's, or when another project's image uses a different uid.

## Requirements

- A Claude subscription. On Team / Enterprise, an admin has to enable Remote Control for the organisation.
- `apt-get` on the base image if `tmux` or `curl` is missing.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/s-kazuki/devcontainers-features/blob/main/src/claude-remote-control/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
