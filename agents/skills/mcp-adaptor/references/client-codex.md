# Codex MCP Registration

Codex uses `~/.codex/config.toml` and supports stdio MCP servers. Codex does
not have Claude Code's `headersHelper`, so register Roblox MCP Gateway servers
through the Codex stdio proxy.

## Register

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/register_codex_server.py <server-id> [env]
uv run ${CLAUDE_SKILL_DIR}/scripts/register_codex_server.py <server-id> <server-id> ... --env prod
```

This installs or reuses a per-user proxy executable, then wraps:

```bash
codex mcp add mcp-gateway-<server-id> \
  --env MCP_GW_ENV=<env> \
  -- ~/.local/bin/rbx-skills-codex-mcp-proxy <server-id>
```

Use the script instead of running this by hand so naming, env handling, and
verification stay consistent. The reusable executable avoids paying
`uv run --with ...` startup/resolution cost for every MCP server every time
Codex or the Codex app server loads MCP inventories. If the reusable install
fails, the script falls back to the older `uv run --with` command shape.
When registering several servers the user already confirmed, pass all of those
server IDs to one script invocation. The script installs/checks the proxy once,
upserts each Codex entry with native `codex mcp add`, and verifies the final
server list once.
Register only the servers the user needs. Codex and the Codex app server start
registered MCP processes and ask each one for tools; loading 20+ servers is
valid, but it is slower than loading a focused set.

In devspaces, the script also copies non-secret proxy and CA environment
variables into the Codex MCP entry. This matters for the Codex app server path
used by integrations such as BuilderAI; `codex mcp list` can show a server as
registered even when the app server cannot start it because the MCP subprocess
did not inherit proxy or CA settings.

## Remove

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/remove_codex_server.py <server-id> [env]
```

## Refresh Behavior

- Auth refresh: the Codex proxy attaches fresh `RBX-LCA-v1` auth on outgoing
  gateway requests. This replaces Claude's `headersHelper` behavior.
- Upstream startup: by default the Codex proxy waits up to
  `MCP_GW_UPSTREAM_STARTUP_TIMEOUT_SEC` seconds (default: 5) while opening the
  Gateway stream. If the Gateway server is unreachable or unauthorized, the
  proxy keeps Codex responsive by serving a valid MCP session with zero tools
  instead of making the whole app-server list wait for Codex's 30s startup
  budget. Set `MCP_GW_UNAVAILABLE_MODE=exit` for strict diagnostics.
- Config refresh: new `codex mcp list/get` CLI processes read
  `~/.codex/config.toml` immediately, but already-running Codex sessions do
  not get a reliable hot reload. After add/remove, tell the user:
  > Start a new Codex session so the MCP server list is reloaded.

## Useful Checks

```bash
codex mcp list --json
codex mcp get mcp-gateway-<server-id> --json
uv run ${CLAUDE_SKILL_DIR}/scripts/debug_auth.py --env prod
```

`codex mcp get --json` stores command details under `.transport`. For a
registered prod Gateway server, verify:

```bash
codex mcp get mcp-gateway-<server-id> --json | jq \
  '.enabled == true
   and .transport.type == "stdio"
   and (.transport.command | test("rbx-skills-codex-mcp-proxy$|uv$"))
   and .transport.env.MCP_GW_ENV == "prod"'
```

For Codex, split validation into three layers:

1. **Registration:** `codex mcp list/get` shows the server enabled.
2. **Proxy/auth/gateway connectivity:** run the bundled stdio smoke test:
   ```bash
   uv run ${CLAUDE_SKILL_DIR}/scripts/smoke_codex_server.py <server-id> prod
   ```
   This preserves the current devspace environment and launches the same
   proxy command Codex launches, but forces strict unavailable handling so
   auth, proxy, and Gateway failures surface as failures. If this fails with
   `codex_proxy:` auth or connect errors, debug auth/proxy connectivity;
   increasing Codex startup timeout alone will not fix it.
3. **Codex app-server exposure:** if BuilderAI or another app-server client is
   involved, check the app-server path directly:
   ```bash
   uv run ${CLAUDE_SKILL_DIR}/scripts/smoke_codex_app_server.py --reload
   uv run ${CLAUDE_SKILL_DIR}/scripts/smoke_codex_app_server.py \
     --call-server mcp-gateway-sourcegraph \
     --call-tool search \
     --args-json '{"query":"repo:Roblox/skills mcp-adaptor count:3"}'
   ```
   If the app-server list shows the server but `tool_count` is zero, run the
   strict `smoke_codex_server.py <server-id> prod` check. If it fails with a
   Gateway authorization or connectivity error, remove that server or fix the
   upstream access; the proxy intentionally exposes zero tools so one bad
   server does not delay all other Codex MCPs. If the strict smoke test works,
   re-run the Codex registration script so proxy and CA env passthrough is
   rewritten, then start a new Codex session or restart the IDE extension.
4. **Fresh Codex session startup:** if the symptom is the interactive Codex
   startup banner showing MCP timeouts, validate a new session instead of only
   checking app-server:
   ```bash
   /usr/bin/time -f 'codex_exec_elapsed_sec %e' \
     codex exec --json --ephemeral --skip-git-repo-check \
       --sandbox read-only 'Reply with exactly OK.'
   ```
   Compare with the same command plus `--ignore-user-config` to estimate MCP
   startup overhead apart from model latency. The JSON event stream should
   complete without MCP timeout events. For the TUI path, run a short
   `codex --no-alt-screen ...` capture and inspect the visible startup text;
   it should not show `MCP client ... timed out after 30 seconds`.
5. **Model-visible tool exposure:** start a new Codex session and ask it to
   use the tool. If `codex mcp list/get` and the direct/app-server/session
   checks all pass, but Codex says the MCP tool is not available, treat that
   as a Codex tool-exposure/version issue rather than a Gateway auth failure.

If Codex can list the server but tools fail after some time, debug auth first.
The common failure is a stale injected `MCP_GATEWAY_TOKEN`; the shared auth
library should now skip that env var when JWT claims prove it is expired or
minted for another gateway audience.

## Timeout vs Connectivity

Codex reports slow MCP startup as a startup timeout, but the underlying cause
can still be an auth exchange, proxy, or gateway connection failure. Do not
assume the fix is only `startup_timeout_sec`. First run:

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/smoke_codex_server.py <server-id> prod
```

If the smoke test succeeds quickly, the proxy and auth path are healthy. If a
fresh Codex session or app-server client still cannot see or use the MCP
tools, run `smoke_codex_app_server.py --reload` to check whether the app server
has loaded tool inventories.
