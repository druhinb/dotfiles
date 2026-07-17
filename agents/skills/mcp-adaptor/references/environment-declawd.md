# Declawd Environment Notes

Declawd has two differences from a regular devspace:

- Claude Code may live at
  `/Applications/declawd.app/Contents/Helpers/claude`.
- Fresh MCP Gateway auth is normally exposed through
  `$DECLAWD_MCPGW_TOKEN_PATH`; the file is re-read so background token
  refreshes are picked up without restarting the skill scripts.

## Claude Binary

The Python registration scripts automatically prefer the bundled declawd
Claude binary when it exists. If manual inspection is needed and
`~/.local/bin/claude mcp list` prints nothing, run:

```bash
/Applications/declawd.app/Contents/Helpers/claude mcp list
```

## PermissionError Fallback

If declawd blocks a Python-side chmod or file permission operation, use the
shell fallback for Claude registration/removal:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/register_server.sh <server-id> [env]
bash ${CLAUDE_SKILL_DIR}/scripts/remove_server.sh <server-id> [env]
```

Use the Python scripts first unless this specific error occurs.

## Auth Debugging

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/debug_auth.py --env prod
```

Healthy declawd output should usually select `declawd_path`. If it selects
`env`, the user may be relying on a stale snapshot token instead of the
fresh-on-read token path.
