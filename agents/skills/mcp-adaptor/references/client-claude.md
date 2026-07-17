# Claude Code MCP Registration

Claude Code supports Streamable HTTP MCP servers and a per-request
`headersHelper`. Use the Claude scripts for Claude Code; do not use Codex or
Cursor scripts for this client.

## Register

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/register_server.py <server-id> [env]
```

The script:

- runs `claude mcp add --transport http --scope user`;
- patches `headersHelper` so each MCP request gets fresh `RBX-LCA-v1` auth;
- adds the matching `mcp__mcp-gateway-<id>` permission rule;
- registers the Cursor bridge too only when Cursor is installed.
- verifies the local Claude config entry without running a network health
  check, so registering multiple servers does not repeatedly health-check the
  full MCP set.

If Python registration hits a sandbox `PermissionError`, use the shell fallback:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/register_server.sh <server-id> [env]
```

## Remove

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/remove_server.py <server-id> [env]
```

Use the shell fallback only for the same sandbox permission issue:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/remove_server.sh <server-id> [env]
```

## Refresh Behavior

- Auth refresh: Claude Code calls `headersHelper` on MCP requests, so the
  helper can pick up refreshed token files without re-registering the server.
- Config refresh: after add/remove, tell the user:
  > Restart your Claude session now, or reconnect MCP from Claude Code, so the
  > MCP server list is reloaded. If the current session was already running,
  > a full restart is the reliable path.

## Useful Checks

```bash
claude mcp list
claude mcp get mcp-gateway-<server-id>
uv run ${CLAUDE_SKILL_DIR}/scripts/debug_auth.py --env prod
uv run ${CLAUDE_SKILL_DIR}/scripts/smoke_claude_server.py <server-id> prod
```

Use `claude mcp get mcp-gateway-<server-id>` for a single-server check. The
full `claude mcp list` command health-checks configured servers and can be
slow when many Gateway MCPs are registered.

In declawd, prefer the bundled Claude binary for `mcp` subcommands if the app
wrapper suppresses output:

```bash
/Applications/declawd.app/Contents/Helpers/claude mcp list
```
