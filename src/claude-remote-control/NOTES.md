## Deprecated

This feature is superseded and receives no further updates. On REVONEO's Coder, Claude Code Remote Control is now started by the Coder template rather than from inside each project's dev container: see `coder_script.devcontainer_claude_rc` and the `enable_claude_rc` workspace parameter in the `kubernetes-2026` template of [revoneo/_company/coder/manifests](https://gitlab.com/revoneo/_company/coder/manifests). Customer repositories' `devcontainer.json` should not carry company or personal tooling, so remove `claude-remote-control` from them and turn on `enable_claude_rc` in the workspace instead.

Existing `:1` references keep working with the behaviour described below.

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
