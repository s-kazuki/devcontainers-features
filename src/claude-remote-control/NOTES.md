## First run

Remote Control needs a claude.ai login (an API key is not enough), so the very first start only prints a hint:

1. Open a terminal in the container and run `claude`. Sign in, and accept the folder trust prompt.
2. Restart the container, or run `/usr/local/share/claude-remote-control/start.sh`.

After that, every container start brings up `claude remote-control` in a detached tmux session and the workspace shows up in [claude.ai/code](https://claude.ai/code) and the Claude mobile app. `tmux attach -t claude-rc` shows what it is doing.

## Where the login lives

`CLAUDE_CONFIG_DIR` points at `/claude-config`, which is the `claude-code-config` named volume. Every dev container using this feature on the same Docker host shares that volume, so you sign in once per host, not once per project. The volume takes its ownership from the first container that mounts it; images whose remote user has a different uid cannot write to it, and the start script says so and skips.

## Requirements

- A Claude subscription. On Team / Enterprise, an admin has to enable Remote Control for the organisation.
- `apt-get` on the base image if `tmux` or `curl` is missing.
