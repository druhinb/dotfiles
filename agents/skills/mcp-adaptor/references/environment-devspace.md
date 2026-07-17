# Devspace Environment Notes

Devspaces usually have `claude`, `codex`, `uv`, `python3`, `jq`, and `gh` on
`PATH`. Auth comes from refreshed token files, `gh auth token -h
github.rbx.com`, or the `coder external-auth` fallback.

Codex MCP registrations are written to `~/.codex/config.toml`, which lives
under `/home/coder`. On devspaces, `/home/coder` persists across workspace
stop/start and restart, so registered Codex MCP servers survive devspace
restarts. They do not survive only if the home volume is deleted or the config
is manually removed.

Devspaces rely on proxy and internal CA environment variables for Gateway
networking. The Codex registration script writes those non-secret values into
each MCP entry so Codex app-server clients can start MCP subprocesses even when
they do not inherit the interactive shell environment.

## Auth Setup

The shared auth library tries `gh auth token -h github.rbx.com` before Coder
external auth. If setup reports GitHub Enterprise is not connected through the
Coder fallback, ask the user to run:

```bash
coder external-auth github-enterprise
```

Then retry the original registration or debug command.

If setup says it is not inside a coder workspace, the command is running on a
local machine without injected MCP Gateway auth. The user should run it inside
the devspace, or use a local auth source such as `sapi`.

## Windows Devspaces

Windows devspaces may store Claude config under `D:\.claude\`. The Python
Claude scripts honor `CLAUDE_CONFIG_DIR`; set it when needed:

```bash
CLAUDE_CONFIG_DIR='D:/.claude' uv run ${CLAUDE_SKILL_DIR}/scripts/register_server.py <server-id> [env]
```

Do not use custom `$SKILL_DIR` variables in skill instructions. Use
`${CLAUDE_SKILL_DIR}` for bundled scripts.

## Auth Debugging

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/debug_auth.py --env prod
```

If `MCP_GATEWAY_TOKEN` is expired, the shared auth library should skip it and
fall through to `~/.agent-keys/mcp-gateway`, `gh auth token -h
github.rbx.com`, or `coder external-auth`.

## Codex Devspace Validation

Devspace Codex images can lag the latest CLI behavior. When debugging Codex
MCPs, verify the layers separately:

```bash
codex --version
codex doctor
codex mcp list --json
uv run ${CLAUDE_SKILL_DIR}/scripts/smoke_codex_server.py sourcegraph prod
uv run ${CLAUDE_SKILL_DIR}/scripts/smoke_codex_app_server.py --reload
```

If `codex doctor` reports configured MCP servers, the stdio smoke test lists
tools, and the app-server smoke test also reports non-zero tool counts, the
auth/proxy/gateway path is working in the devspace. If a new Codex session
still cannot discover or call those tools, report it as a Codex CLI,
app-server, or devspace-image issue rather than an MCP Gateway credential
issue.
