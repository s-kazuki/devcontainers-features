### **IMPORTANT NOTE**
- **This Feature is deprecated, and will no longer receive any further updates/support.**

# Coder Login Feature (coder-login)

Automatically login to Coder on container creation

## Example Usage

```json
"features": {
    "ghcr.io/s-kazuki/devcontainers-features/coder-login:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| absProxyBasePath | The base path to prefix to all absproxy requests | string | - |
| appName | The name to use in branding. Will be shown in titlebar and welcome message. | string | - |
| auth | The type of authentication to use. When 'password' is selected, code-server will auto-generate a password. 'none' disables authentication entirely. | string | none |
| cert | Path to certificate. A self signed certificate is generated if none is provided. | string | - |
| certHost | Hostname to use when generating a self signed certificate. | string | - |
| certKey | Path to certificate key when using non-generated cert. | string | - |
| disableFileDownloads | Disable file downloads from Code. When enabled, users will not be able to download files from the editor. | boolean | false |
| disableFileUploads | Disable file uploads to Code. When enabled, users will not be able to upload files to the editor. | boolean | false |
| disableGettingStartedOverride | Disable the coder/coder override in the Help: Getting Started page. | boolean | false |
| disableProxy | Disable domain and path proxy routes. | boolean | false |
| disableTelemetry | Disable telemetry reporting. | boolean | false |
| disableUpdateCheck | Disable update check. Without this flag, code-server checks every 6 hours against the latest GitHub release and notifies once a week when updates are available. | boolean | false |
| disableWorkspaceTrust | Disable Workspace Trust feature. This only affects the current session. | boolean | false |
| enableProposedAPI | Comma-separated list of VS Code extension IDs to enable proposed API features for. | string | - |
| extensions | Comma-separated list of VS Code extensions to install. Format: 'publisher.extension[@version]' (e.g., 'ms-python.python,ms-azuretools.vscode-docker'). | string | - |
| githubAuthTokenFile | Path to a file containing your GitHub auth token. | string | - |
| hashedPasswordFile | Path to a file containing the hashed password used for authentication. The password should be hashed with argon2 and be in the encoded form. This takes priority over `passwordFile`. | string | - |
| host | The address to bind to for the code-server. Use '0.0.0.0' to listen on all interfaces. | string | 127.0.0.1 |
| locale | Set VS Code display language and language shown on the login page. Format should be an IETF language tag (e.g., 'en', 'fr', 'zh-CN'). | string | - |
| logFile | Path to a file to send stdout and stderr logs to from code-server. | string | /tmp/code-server.log |
| passwordFile | Path to a file containing the password used for authentication. | string | - |
| port | The port to bind to for the code-server. | string | 8080 |
| proxyDomain | Domain used for proxying ports. | string | - |
| socket | Path to a socket. When specified, host and port will be ignored. | string | - |
| socketMode | File mode of the socket when using the socket option. | string | - |
| trustedOrigins | Comma-separated list of trusted-origins to disable origin check for. Useful if not able to access reverse proxy configuration. | string | - |
| verbose | Enable verbose logging. | boolean | false |
| version | The version of code-server to install. If empty, installs the latest version. | string | - |
| welcomeText | Text to show on login page. | string | - |
| workspace | Path to the workspace or folder to open on startup. Can be a directory or a .code-workspace file. | string | - |
| appOpenIn | The way to open the app in Coder. Defaults to 'slim-window'. | string | slim-window |
| appShare | The group to use for the app in Coder. Defaults to 'owner'. | string | owner |
| appGroup | The group to use for the app in Coder. Defaults to 'Web Editors'. | string | Web Editors |
| coder | - | string | - |
| coderUrl | The URL of your Coder instance | string | - |
| coderAgentUrl | - | string | - |
| coderAgentAuth | - | string | - |
| coderAgentToken | - | string | - |
| coderSessionToken | The SESSION TOKEN of your Coder instance | string | - |
| coderWorkspaceId | - | string | - |
| coderWorkspaceName | - | string | - |
| coderWorkspaceAgentName | - | string | - |
| coderWorkspaceOwnerName | - | string | - |
| gitAuthorName | - | string | - |
| gitAuthorEmail | - | string | - |
| gitCommitterName | - | string | - |
| gitCommitterEmail | - | string | - |

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


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/s-kazuki/devcontainers-features/blob/main/src/coder-login/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
