---
name: ros-cli
description: ROS is the source of truth for Roblox internal employee and organization information, Work Tracker data, and Nexus 1:1 planning data. Use the ROS CLI when asked to look up employees/orgs; find employees by id, email, Slack handle/id, GitHub Cloud username, or GitHub Enterprise username; find managers/direct reports; map people to group/team/pod/org membership or leadership; manage Nexus priorities, growth/development goals, notes, follow-ups, and feedback prep; or work with Work Tracker items such as work items, DRIs, status/health, ship dates, Jira/GDoc links, TLDR updates, contributing items, and key work.
---

# ROS CLI

Use `ros` before inventing another data path for PeopleHub, Nexus, or Work Tracker questions.

## First Principles

- **Detect your shell/OS before running any block.** The command blocks in this skill are POSIX shell (bash). If you are on **Windows PowerShell**, do not run them — `command -v`, `which -a`, `[ -z ... ]`, `case`, `printf`, `sed`, `export`, `hash -r`, and `:` as a PATH separator do not work there. Jump to the [Windows / PowerShell](#windows--powershell) section for the probe, install, verify, and auth commands. The `ros` CLI itself is fully cross-platform (it resolves both `sapi`/`sapi.exe` and `coder`/`coder.exe`); only the shell snippets differ.
- Treat `--help` as the source of truth. This skill is only a trigger and quick-start guide.
- **IMPORTANT: managed binary installs win over Node/npm installs on Roblox laptops.** A laptop may have both a Jamf/pkg binary (`/opt/rbx/ros/bin/ros`, normally symlinked from `/usr/local/bin/ros`) and an older Node/npm shim (`~/.nvm/.../bin/ros`, `~/.local/.../bin/ros`, `~/.volta/.../bin/ros`). Inspect the active command with `command -v ros` and all PATH candidates with `which -a ros`. If both managed binary and Node/npm installs exist, prefer the managed binary; do not install or update over it with npm. Runtime-local sandbox installs are different: npm installs inside Docker/SBX/deCLAWd/Cowork affect only that runtime.
- For "who am I", "my org", or context about the authenticated caller, start with `ros me` when the installed CLI exposes it. JSON is already the default; it returns the active employee row plus the current Group / Team / Pod path.
- Start with the nearest help command before using non-trivial flags: `ros --help`, then `ros <domain> --help`, then `ros <domain> <operation> --help`.
- Check observable runtime signals before installing anything. Treat the current shell's files, environment variables, and command results as the source of truth.
- Keep install and auth separate. A runtime may inject a ROS token without installing `ros`, or install `ros` without a usable token.
- Never print raw tokens. Do not `cat ~/.agent-keys/rosapi`; use `ros auth status` and file metadata checks instead.
- Before install/auth/debug steps, send a `USER UPDATE:` that states the detected runtime, expected auth category, and next command family. Do not include raw tokens or token file paths in user-facing updates. Example: `USER UPDATE: Detected Docker Sandbox; I expect runtime-injected ROS auth and will check ROS CLI freshness before validating with ros auth login/status.`
- Before auth debugging, identify which `ros` install this shell will actually run. Use `ros update --check` before auth validation, but only run `ros update` for npm installs. If the active CLI is a precompiled/managed binary, do not replace it with npm; report that updates come from the managed deployment channel and continue with the installed binary when it supports the needed command.
- `ros auth status` shows the auth source this shell will actually use, not just the host/global saved preference.
- Runtime-provided auth wins before saved host/global preference: `ROS_CLI_LCA_TOKEN_PATH`, `ROS_CLI_LCA_TOKEN`, `~/.agent-keys/rosapi`, then Coder GHE exchange in Coder runtimes. Default `ros auth login` in a runtime validates injected auth without rewriting host/global `auth.json`.
- If ROS CLI warns that it is targeting a non-production environment, treat returned data as validation-only. Unless the user intentionally asked for that env, tell them to return to prod with `unset ROS_CLI_ENV` or `ROS_CLI_ENV=production`.
- Rely on the default JSON output for agent work. Use `jq` to inspect, filter, and compose results.

## Probe

Run this first **in bash / POSIX shells**. On **Windows PowerShell**, skip this block and run the probe in the [Windows / PowerShell](#windows--powershell) section instead. It prints only command/token/runtime signals, never raw token contents or token paths. The probe also exports Cowork token env vars for the current shell only; repeat the Cowork token prelude in later shell commands because agent tool calls usually run in fresh shells.

```bash
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  candidate="${HOME:-}/mnt/.local-plugins/marketplaces/org-provisioned/roblox"
  if [ -d "$candidate" ]; then
    export CLAUDE_PLUGIN_ROOT="$candidate"
  fi
fi
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$CLAUDE_PLUGIN_ROOT" ]; then
  if [ -z "${ROS_CLI_LCA_TOKEN_PATH:-}" ] && [ -s "$CLAUDE_PLUGIN_ROOT/.tokens/rosapi-token" ]; then
    export ROS_CLI_LCA_TOKEN_PATH="$CLAUDE_PLUGIN_ROOT/.tokens/rosapi-token"
  fi
fi
printf 'ros_path=%s\n' "$(command -v ros || true)"
printf 'all_ros_on_path=\n'
which -a ros 2>/dev/null | sed 's/^/  /' || true
ros --version 2>/dev/null | sed 's/^/ros_version=/'
echo "ros_env=${ROS_CLI_ENV:-production-default}"
if [ -n "${ROS_CLI_LCA_TOKEN_PATH:-}" ]; then
  token_source_category="env-token-path"
elif [ -n "${ROS_CLI_LCA_TOKEN:-}" ]; then
  token_source_category="env-token"
elif [ -s "$HOME/.agent-keys/rosapi" ]; then
  token_source_category="agent-key-file"
else
  token_source_category="none"
fi
echo "token_source_category=$token_source_category"
declawd_token_path_signal=none
case "${ROS_CLI_LCA_TOKEN_PATH:-}" in
  *declawd-rosapi-token*|*/.tokens/rosapi-token) declawd_token_path_signal=present ;;
esac
cowork_session_signal=none
case "${PWD:-}:${HOME:-}" in
  /sessions/*/mnt/*:/sessions/*|/sessions/*:/sessions/*) cowork_session_signal=present ;;
esac
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  runtime_signal=claude-cowork
elif [ "$cowork_session_signal" = "present" ]; then
  runtime_signal=firecracker-or-claude-cowork
elif [ -n "${DECLAWD_LLM_GATEWAY_TOKEN_PATH:-}${DECLAWD_MCPGW_TOKEN_PATH:-}" ] || [ "$declawd_token_path_signal" = "present" ]; then
  runtime_signal=declawd
elif [ -n "${CODER_AGENT_URL:-}" ] && [ -n "${CODER_AGENT_TOKEN:-}" ]; then
  runtime_signal=devspace
elif [ -n "${CODER_AGENT_URL:-}${CODER_AGENT_TOKEN:-}" ]; then
  runtime_signal=partial-coder-env
elif [ -r /etc/agentid/sandbox-identity.json ] && python3 -c 'import json,sys; data=json.load(open("/etc/agentid/sandbox-identity.json")); sys.exit(0 if data.get("sandbox_name") else 1)' 2>/dev/null; then
  runtime_signal=docker-sandbox-or-sbx
elif [ -f /etc/fleet-host-machine ] && [ -f /etc/fleet-host-user ]; then
  runtime_signal=docker-sandbox-or-sbx
else
  runtime_signal=local-or-unknown
fi
echo "runtime_signal=$runtime_signal"
```

## Windows / PowerShell

Use this section instead of the bash blocks when the shell is Windows PowerShell. The container/sandbox runtimes (Claude Cowork, Firecracker, deCLAWd, Docker Sandbox/SBX) are Linux-only, so a PowerShell session is effectively `local-or-unknown` (or `devspace` if `CODER_AGENT_URL` and `CODER_AGENT_TOKEN` are both set). Native Windows has no runtime-injected ROS token, so **skip the Cowork/Docker preludes and authenticate with SAPI.** Key shell differences: read env vars with `$env:NAME`, use `$env:USERPROFILE` for the home dir, the PATH separator is `;`, and there is no `export` / `hash -r`.

Probe (PowerShell equivalent — prints signals only, never raw token contents):

```powershell
$ros = (Get-Command ros -ErrorAction SilentlyContinue).Source
"ros_path=$ros"
if ($ros) { "ros_version=$(ros --version 2>$null)" }
"ros_env=$(if ($env:ROS_CLI_ENV) { $env:ROS_CLI_ENV } else { 'production-default' })"
if     ($env:ROS_CLI_LCA_TOKEN_PATH) { $tok = 'env-token-path' }
elseif ($env:ROS_CLI_LCA_TOKEN)      { $tok = 'env-token' }
elseif (Test-Path "$env:USERPROFILE\.agent-keys\rosapi") { $tok = 'agent-key-file' }
else   { $tok = 'none' }
"token_source_category=$tok"
if     ($env:CODER_AGENT_URL -and $env:CODER_AGENT_TOKEN) { $rt = 'devspace' }
elseif ($env:CODER_AGENT_URL -or  $env:CODER_AGENT_TOKEN) { $rt = 'partial-coder-env' }
else   { $rt = 'local-or-unknown' }
"runtime_signal=$rt"
```

Install and verify when `ros` is missing (same package and registry as everywhere else). Existing managed installs may appear as a precompiled binary such as `ros` / `ros.exe`; npm installs on Windows usually expose `ros.ps1` / `ros.cmd`:

```powershell
npm install -g "@rbx/ros-cli" --registry https://artifactory.rbx.com/api/npm/npm-all/
(Get-Command ros).Source   # -> ...\ros.ps1 (or ros.cmd)
ros --version
```

If npm succeeds but `Get-Command ros` is still empty, inspect the npm global bin and PATH (note the `;` separator):

```powershell
"npm_global_bin=$(npm prefix -g)"
$env:PATH -split ';'
```

Auth (`local-or-unknown` → SAPI; SAPI lives at `C:\Users\<user>\.sapi\sapi.exe`):

```powershell
(Get-Command sapi -ErrorAction SilentlyContinue).Source   # -> C:\Users\<user>\.sapi\sapi.exe
ros auth login --sapi
ros auth status
ros me
```

If `ros me` is not present, update the CLI when appropriate; otherwise use `ros orgs list-orgs --limit 1` as the minimal auth/API smoke.

If `runtime_signal=devspace` on a Windows VM, use `ros auth login` (or explicit `ros auth login --ghe-exchange`) instead of `--sapi`, matching the Devspaces note below.

## Cowork Token Prelude

In Claude Cowork / Firecracker sessions, prepend this to every later shell command that runs `ros`, because each tool call may start a fresh shell:

```bash
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  candidate="${HOME:-}/mnt/.local-plugins/marketplaces/org-provisioned/roblox"
  if [ -d "$candidate" ]; then
    export CLAUDE_PLUGIN_ROOT="$candidate"
  fi
fi
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$CLAUDE_PLUGIN_ROOT" ]; then
  export ROS_CLI_LCA_TOKEN_PATH="${ROS_CLI_LCA_TOKEN_PATH:-$CLAUDE_PLUGIN_ROOT/.tokens/rosapi-token}"
fi
export PATH="$HOME/.local/bin:$PATH"
```

## Install Rule

**On Windows PowerShell, use the install/verify commands in the [Windows / PowerShell](#windows--powershell) section** — the bash snippets below assume a POSIX shell. The npm package and registry are identical across platforms, but an existing `ros` may be a managed precompiled binary rather than an npm shim.

On managed Roblox macOS laptops, the Jamf/pkg install is authoritative. The package installs the real binary at `/opt/rbx/ros/bin/ros` and symlinks it into `/usr/local/bin/ros`; if an older Node/npm shim appears first in `which -a ros`, prefer the managed binary unless the user explicitly says they are testing a pinned/beta npm install. Do not run `npm install -g` or `ros update` to replace the managed binary.

Run `npm install -g` only in the shell where `ros` is missing, or when the user explicitly wants to replace the current install with the npm package. It installs into that shell's npm global prefix and filesystem. For example, installing inside deCLAWd only makes `ros` available inside that deCLAWd session; installing in a host Terminal only makes it available on the host. If `command -v ros` already works, use the probe's `which -a ros` output to decide whether that executable is the managed binary, an intended runtime-local npm install, or an npm shim shadowing the managed binary.

To validate a shadowed managed binary immediately, run it by absolute path:

```bash
/opt/rbx/ros/bin/ros --version
/opt/rbx/ros/bin/ros auth status
/opt/rbx/ros/bin/ros me
```

To remove an old npm install on a laptop, suggest these commands but do not run them if the user intentionally pinned or beta-installed the npm package:

```bash
npm uninstall -g @rbx/ros-cli
npm --prefix "$HOME/.local" uninstall -g @rbx/ros-cli
hash -r 2>/dev/null || true
rehash 2>/dev/null || true
command -v ros
which -a ros 2>/dev/null || true
ros --version
```

In Docker/SBX, use the agent user's writable npm prefix before `ros update` or `npm install -g`:

```bash
export NPM_CONFIG_PREFIX="$HOME/.local"
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
hash -r 2>/dev/null || true
```

When this skill says to install the CLI package, run and verify in the same shell:

```bash
npm install -g @rbx/ros-cli --registry https://artifactory.rbx.com/api/npm/npm-all/
command -v ros
ros --version
```

Before auth debugging or sandbox validation, check ROS CLI freshness in the current runtime:

```bash
ros update --check
ros --version
```

If `updateAvailable` is `true` and the user is not intentionally using a pinned or beta version, run `ros update` only for npm installs. If `ros update` says this is a precompiled binary and self-update is unsupported, report that this install must be updated through the managed deployment channel. If update fails, keep diagnosing with the existing CLI and note the update failure. If npm succeeds but `command -v ros` is still empty, debug the current shell's npm global bin and `PATH`:

```bash
echo "npm_global_bin=$(npm prefix -g)/bin"
echo "$PATH" | tr ':' '\n'
```

Do not move to auth debugging until `command -v ros` works in the same shell.

## Decision Flow

1. Run the probe. On Windows PowerShell, run the [Windows / PowerShell](#windows--powershell) probe and follow that section for install and auth instead of the bash blocks.
2. Send a `USER UPDATE:` before changing install/auth state. Name the runtime, expected auth category, and that ROS CLI freshness will be checked before auth validation. Do not include token file paths.
3. If `which -a ros` shows a Node/npm shim before `/usr/local/bin/ros` on a local macOS laptop, prefer the managed binary. Tell the user the npm shim is first on PATH, validate with `/opt/rbx/ros/bin/ros ...` when needed, and recommend the npm uninstall commands from the Install Rule unless the user intentionally pinned or beta-installed npm. If continuing before uninstalling, invoke `/opt/rbx/ros/bin/ros` explicitly so the shadowed npm shim is not used by accident.
4. If `ros_path` is empty:
   - `runtime_signal=claude-cowork` or `runtime_signal=firecracker-or-claude-cowork`: run the Cowork Token Prelude, follow the Install Rule, and keep `ROS_CLI_LCA_TOKEN_PATH` intact.
   - `runtime_signal=docker-sandbox-or-sbx`: set the Docker/SBX npm prefix from the Install Rule, then install only if needed; auth can use the injected ROS auth source when `token_source_category=agent-key-file`.
   - `runtime_signal=declawd`: follow the Install Rule; keep `ROS_CLI_LCA_TOKEN_PATH` / `ROS_CLI_LCA_TOKEN` intact.
   - `runtime_signal=devspace`: follow the Install Rule only if needed; auth uses Coder GHE exchange, not SAPI or injected agent-key auth.
   - `runtime_signal=partial-coder-env`: report the missing Coder env before trying GHE exchange.
   - `runtime_signal=local-or-unknown` and `token_source_category=none`: on macOS, check for `/opt/rbx/ros/bin/ros` before installing; use the managed binary if it exists. Otherwise follow the Install Rule, then use SAPI for auth.
5. Check ROS CLI freshness in the current runtime before auth validation:
   - If `runtime_signal=docker-sandbox-or-sbx`, set the Docker/SBX npm prefix from the Install Rule first.
   ```bash
   ros update --check
   ros --version
   ```
   If `updateAvailable` is `true` and the user is not intentionally using a pinned or beta version, run `ros update` only for npm installs, then rerun `ros --version`. If `ros update` reports a precompiled binary, do not replace it with npm by default; tell the user it needs the managed deployment update channel. If `ros update --check` is unavailable or fails because the installed CLI is too old or broken, follow the Install Rule, then rerun `ros --version`.
6. Run the runtime-specific auth command:
   - Claude Cowork / Firecracker: prepend the Cowork Token Prelude, then run `ros auth login` and expect source `ROS_CLI_LCA_TOKEN_PATH`.
   - deCLAWd: `ros auth login` and expect runtime-injected ROS auth.
   - Docker Sandbox V1/V2: `ros auth login` and expect runtime-injected ROS auth.
   - Devspaces/Coder: `ros auth login` (or explicit `ros auth login --ghe-exchange`) and expect source `Coder external auth GHE exchange`.
   - Local or unknown: `ros auth login --sapi` and expect source `SAPI`.
7. Verify auth and a real API call:
   ```bash
   ros auth status
   ros me
   ```
   If `ros me` is not present, update the CLI when appropriate; otherwise use `ros orgs list-orgs --limit 1` as the minimal auth/API smoke.
8. If `ros auth status` fails, do not reinstall blindly. Diagnose the token source for the detected runtime first.

## Runtime Notes

- **Claude Cowork / Firecracker:** detect it by the `/sessions/<name>/mnt/...` working tree and the Roblox org-plugin root at `/sessions/<name>/mnt/.local-plugins/marketplaces/org-provisioned/roblox`. The ROS API token is plugin-injected at `.tokens/rosapi-token`; do not use `.tokens/credbroker-token` for ROS CLI because its audience is not `rbx.prod.rosapi`. Prepend the Cowork Token Prelude to every shell command that runs `ros`.
- **deCLAWd:** `ROS_CLI_LCA_TOKEN_PATH` is the preferred fresh token source. Run `ros auth login` to validate the runtime token; default login should not rewrite host/global `auth.json`. Do not overwrite injected token files. If the token is expired or invalid, tell the user to exit/restart deCLAWd and complete any host SAPI/Okta prompt.
- **Docker Sandbox V1:** use `docker sandbox exec -it <sandbox-name> bash`; `docker sandbox run` launches the configured agent, not a shell.
- **Docker `sbx` V2:** use `sbx exec -it <sandbox-name> -- bash`.
- **Docker V1/V2:** if `runtime_signal=docker-sandbox-or-sbx` and `token_source_category=agent-key-file`, run `ros auth login` to validate runtime-injected ROS auth. If the token is expired or invalid, tell the user to exit/restart the sandbox so the launcher can re-inject a fresh token. `UNDICI-EHPA` warnings are informational if commands succeed.
- **Devspaces:** validate inside the VM. Only treat the shell as Devspace when both `CODER_AGENT_URL` and `CODER_AGENT_TOKEN` are present; a local `coder` CLI on `PATH` is not enough. Use `ros auth login` or explicit `ros auth login --ghe-exchange`. If it fails with `audience not allowed` for `rbx.prod.rosapi`, report that the SAPI Authorization production GHE exchange allowlist is not deployed yet; do not fall back to local `gh auth token`.
- **Local macOS laptop:** managed Jamf/pkg installs live at `/opt/rbx/ros/bin/ros` with `/usr/local/bin/ros` as the stable symlink. If `which -a ros` shows an npm shim before `/usr/local/bin/ros`, the npm install is shadowing the managed binary; prefer the managed binary and recommend removing the old npm install unless the user intentionally pinned/beta-installed it. Do not edit shell startup files just to reorder PATH.
- **Local or unknown:** use SAPI unless an injected token source is already present:
  ```bash
  command -v sapi
  ros auth login --sapi
  ros auth status
  ```
  On Windows PowerShell this is the common case (the sandbox runtimes are Linux-only). Use the PowerShell commands in the [Windows / PowerShell](#windows--powershell) section; SAPI resolves to `C:\Users\<user>\.sapi\sapi.exe`.

## Command Areas

- `me`: authenticated employee and current Group / Team / Pod path. Use this first for caller context, then pivot to `employees` or `orgs` only when you need more detail.
- `employees`: REST-backed employee lookup by id, ids, email, Slack id/handle, GitHub Cloud username, GitHub Enterprise username, combined GitHub username, name, manager id, and org id. List commands return ids by default; use `--expand` when you need full rows or org labels.
- `orgs`: REST-backed org lookup and tree reads by id, ids, parent org id, level id, exact org `key`, or human-readable `orgSchema`; leadership is `orgs get-org-leadership`.
- `nexus`: manager/direct-report 1:1 planning, priorities, growth/development goals, notes, follow-ups.
- `work-tracker`: REST-backed Work Tracker work items, DRIs, status/health, ship dates, Jira/GDoc links, TLDR updates, tracker links, search, key work. Work item ids are numeric public ids. Legacy `worktracker` may still execute for compatibility but should not be the recommended surface.
- `update`: check for and install newer CLI versions.

Some local branches, binary deployments, or installed package versions may lag the latest command surface. If a command is missing from `ros --help`, run `ros update --check`; if the active install is npm and an update is available, run `ros update` unless the user intentionally pinned a beta/versioned package. If the install is precompiled/managed, or the command is still missing after an npm update, report that this installed CLI does not expose it yet.

## Starting Points

```bash
ros me

ros employees get-employee --id <employeeId>
ros employees list-employees --email user@example.com --expand
ros employees list-employees --slack-handle slack-handle --expand
ros employees list-employees --manager-employee-id <managerId> --expand
ros employees list-employees --github-username manager-github --expand
ros employees lookup-employees --ids "<employeeId>,<employeeId>"

ros orgs get-org --id <orgId>
ros orgs list-orgs --key "team:creator > studio" --expand
ros orgs list-orgs --org-schema "<orgSchema>" --expand
ros orgs list-orgs --parent-org-id <parentOrgId> --expand --limit 50
ros orgs lookup-orgs --ids "<orgId>,<orgId>"
ros employees list-employees --org-id <resolvedOrgId> --expand
ros orgs get-org-leadership --id <resolvedOrgId>

ros nexus spaces list
ros nexus topics list <spaceId> --limit 20

ros work-tracker list-work-items --org-id <orgId> --limit 50
ros work-tracker search-work-items --q "invoicing" --limit 25
ros work-tracker lookup-work-items --ids "<workItemId>,<workItemId>"
ros work-tracker get-work-item --id <workItemId>
```

When chaining commands, inspect JSON with `jq`. For paginated ROS CLI responses, pass the returned top-level `nextCursor` back with `--cursor <nextCursor>` only when the user asks for the next page or a complete result set.
