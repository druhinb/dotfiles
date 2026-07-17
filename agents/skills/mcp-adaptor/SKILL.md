---
name: mcp-adaptor
description: >
  Register Roblox MCP Gateway servers with Claude Code, Codex, or Cursor.
  Use this skill whenever a user asks for an MCP/tool integration that is not
  installed yet, asks to set up Slack, TeamCity, Sentry, Grafana, Kibana,
  logs, VictoriaMetrics, Sourcegraph, Glean, Google Drive write access, or
  another Roblox MCP Gateway server, or asks to debug MCP auth/refresh issues.
  Always list matching servers and get explicit confirmation for the exact
  server before registering it, even in auto-approve or Yolo mode.
---

# MCP Gateway Adaptor

Use this skill to discover Roblox MCP Gateway servers, register them with the
user's MCP client, remove them, or debug MCP Gateway auth.

## Core Workflow

1. **List available servers.** Do not hard-code IDs or ask the user to type an
   ID when discovery can answer it:
   ```bash
   uv run ${CLAUDE_SKILL_DIR}/scripts/list_servers.py --env prod
   ```
   The script prints a JSON object with a `servers` array. Parse
   `.servers[]`; do not treat the root as an array. Pick the relevant
   candidate servers from that array and show the user each `id`,
   `description`, and `tool_count` when present.
2. **Ask before registering.** Never register a server without explicit user
   confirmation for that exact server in the current session. Broad approval
   like "do what you need" is not enough. Prefer a small set of servers that
   matches the user's workflow; do not register every available Gateway server
   unless the user explicitly asks for all of them.
3. **Choose the client reference.**
   - Claude Code: read `references/client-claude.md`.
   - Codex: read `references/client-codex.md`.
   - Cursor: read `references/client-cursor.md`.
   - For Codex, if the user confirmed several servers, pass all confirmed
     server IDs to one `register_codex_server.py` invocation instead of
     looping one server at a time.
4. **Choose the environment reference when relevant.**
   - Declawd: read `references/environment-declawd.md`.
   - Devspace, including Windows devspaces: read
     `references/environment-devspace.md`.
5. **For auth failures or stale credentials**, read `references/troubleshooting.md`
   and use:
   ```bash
   uv run ${CLAUDE_SKILL_DIR}/scripts/debug_auth.py --env prod
   ```

## Hard Rules

- Do not edit `.mcp.json`, `~/.claude.json`, `~/.codex/config.toml`, or Cursor
  MCP config by hand. Use this skill's scripts or the native client CLI they
  wrap.
- Do not call `claude mcp add` or `codex mcp add` by hand. Use the bundled
  register/remove scripts so auth helpers, naming, and refresh behavior stay
  consistent.
- Register only servers the user just confirmed. Do not register adjacent or
  related servers without asking again.
- After add/remove, tell the user to restart or reconnect the affected client
  as described in the client reference.

## Shared Concepts

- Server names are `mcp-gateway-<id>` for `prod` and
  `mcp-gateway-<id>-<env>` for non-prod environments.
- Default gateway env is `prod`; override with an explicit script argument or
  `MCP_GW_ENV`.
- Token source order is fresh declawd token path, injected env var if still
  usable, refreshed `~/.agent-keys/mcp-gateway`, `gh auth token -h
  github.rbx.com` exchange, devspace `coder` exchange, then local `sapi`.
- Claude Code refreshes auth through `headersHelper` per request. Codex and
  Cursor use stdio proxies that attach fresh auth per outgoing gateway request.
- Codex registrations must also carry non-secret proxy and CA environment
  variables, because integrations that use the Codex app server may launch MCP
  subprocesses without inheriting the interactive shell environment.
- Codex app-server startup cost scales with the number of registered servers
  and each server's upstream health. Use `smoke_codex_app_server.py --reload`
  to benchmark actual tool availability; `codex mcp list` only proves config
  registration.

## Oversized MCP Results

Claude Code may save large MCP tool responses to a JSON file. When that
happens, unwrap the file with:

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/parse_mcp_result.py /path/to/result.json
python3 ${CLAUDE_SKILL_DIR}/scripts/parse_mcp_result.py /path/to/result.json --raw | jq '...'
```

Use this script before writing ad-hoc JSON-unwrapping commands.
