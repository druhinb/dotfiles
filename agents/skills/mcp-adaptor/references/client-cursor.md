# Cursor MCP Registration

Cursor uses stdio MCP servers. The mcp-adaptor registers a stdio bridge that
proxies Cursor's JSON-RPC stream to the MCP Gateway over Streamable HTTP.

## Register

Cursor registration is currently handled by the Claude registration script when
`~/.cursor/` exists:

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/register_server.py <server-id> [env]
```

The Cursor entry launches:

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/cursor_bridge.py <server-id>
```

with `MCP_GW_ENV` set for the selected env.

## Remove

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/remove_server.py <server-id> [env]
```

## Refresh Behavior

- Auth refresh: `cursor_bridge.py` attaches fresh auth per outgoing gateway
  request.
- Config refresh: after add/remove, tell the user to restart Cursor or toggle
  the MCP server off/on in Cursor Settings -> Tools & Integrations.

## Useful Checks

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/debug_auth.py --env prod
```

If Cursor was launched from a GUI and cannot find `sapi`, the shared auth
library probes common local install paths in addition to `$PATH`.
