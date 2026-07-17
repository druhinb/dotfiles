# MCP Gateway Troubleshooting

Use this reference for failed registration, failed MCP connection, or tools
that worked before but stopped after a few hours or days.

## Start With Non-Secret Auth Diagnostics

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/debug_auth.py --env prod
```

The output intentionally omits token values. It reports source, claim status,
expiry time, and whether the audience matches the selected gateway env.

## Common Failures

- **Stale `MCP_GATEWAY_TOKEN`:** older runtimes inject an env var that can
  outlive the token. The auth library skips it when JWT claims prove it is
  expired, then falls through to refreshed files or `coder external-auth`.
- **Wrong audience / 401:** the token was minted for another env. Re-run with
  the right env or refresh auth so the token audience is
  `rbx.<env>.mcp-gateway`.
- **Gateway 403 for one server:** if `smoke_codex_server.py <server-id> prod`
  reaches `https://apis.simulprod.com/mcp-gateway/mcp/server/<server-id>` and
  gets `403 Forbidden`, the Codex registration and proxy path are working but
  the caller is not authorized for that Gateway server. Check the server's
  access requirements, OAuth grant, or pre-provisioning; re-registering or
  increasing startup timeouts will not fix a server-side authorization denial.
- **OAuth grant missing:** visit the credential broker grant page for the
  underlying tool and accept the OAuth grant, then retry.
- **Codex or Cursor works initially then fails later:** confirm the stdio proxy
  is being used. Hand-registered direct HTTP entries cannot refresh
  `RBX-LCA-v1` headers.
- **Codex says an MCP server timed out at startup:** do not assume this is only
  a startup budget problem. Run
  `uv run ${CLAUDE_SKILL_DIR}/scripts/smoke_codex_server.py <server-id> prod`
  to separate real proxy/auth/gateway connectivity failures from Codex client
  startup timing. Normal Codex registrations use fast empty fallback for an
  unavailable upstream; the strict smoke script disables that fallback so
  Gateway errors are visible. If the direct smoke is healthy, benchmark a fresh
  Codex session with:
  ```bash
  /usr/bin/time -f 'codex_exec_elapsed_sec %e' \
    codex exec --json --ephemeral --skip-git-repo-check \
      --sandbox read-only 'Reply with exactly OK.'
  ```
  Compare with the same command plus `--ignore-user-config`.
- **BuilderAI or another Codex app-server client lists MCP servers with no
  tools, or tool calls fail with a 30s handshake timeout:** run
  `uv run ${CLAUDE_SKILL_DIR}/scripts/smoke_codex_app_server.py --reload`.
  If the app-server path has empty tool inventories while
  `smoke_codex_server.py` works, re-run
  `uv run ${CLAUDE_SKILL_DIR}/scripts/register_codex_server.py <server-id> prod`
  for the affected servers. This rewrites non-secret proxy and CA env
  passthrough that the app server needs when launching MCP subprocesses.
- **BuilderAI plugins page is slow to load:** the plugins page uses the Codex
  app-server MCP status path, which starts and lists tools for registered MCP
  servers. More registered servers means more stdio proxy subprocesses and
  Gateway `list_tools` calls. Current Codex registrations should use the
  reusable `rbx-skills-codex-mcp-proxy` executable instead of starting each
  server through `uv run --with ...`; re-run `register_codex_server.py` for
  older entries whose `codex mcp get ... --json` shows `.transport.command ==
  "uv"`. Then run
  `uv run ${CLAUDE_SKILL_DIR}/scripts/smoke_codex_app_server.py --reload` and
  inspect `list_sec` plus `empty_tool_servers`. For each empty server, run the
  strict `smoke_codex_server.py <server-id> prod` check. If the strict check
  fails with an upstream auth or connectivity error, remove the server or fix
  access; leaving unnecessary unavailable servers registered still adds
  startup work even though the Codex proxy now fails open with zero tools.
- **Claude registration is slow when adding many servers:** avoid using
  `claude mcp list` in a loop. The list command health-checks all configured
  MCPs, so repeated list calls create quadratic work during bulk setup. The
  registration scripts verify local config only; use `claude mcp get
  mcp-gateway-<server-id>` or `smoke_claude_server.py <server-id> prod` for
  targeted network checks.
- **Codex lists the server but the model cannot see the tool:** if
  `codex mcp list/get`, `smoke_codex_server.py`,
  `smoke_codex_app_server.py`, and a fresh `codex exec --json` session check
  all pass, the Gateway server is registered and reachable. Treat the
  remaining failure as Codex tool exposure/version behavior; start a new Codex
  session, then check `codex --version` and `codex doctor`.
- **Claude entry uses inline `printf`, `headers.sh`, or old Windows helper:**
  re-run `register_server.py <server-id>` so the entry is rewritten with the
  current helper.

## Client Reloads

- Claude Code: restart or reconnect the Claude session after add/remove.
- Codex: restart the Codex session or IDE extension after add/remove. If a
  Codex app-server daemon is in use, run `codex app-server daemon restart` or
  restart the IDE extension that owns it.
- Cursor: restart Cursor or toggle the MCP server off/on after add/remove.

Auth refresh and client config reload are different. A fresh token does not
make a newly registered MCP server appear in a client that has not reloaded its
MCP configuration.

## Exit Codes

| Code | Meaning |
|---|---|
| 0 | Registered, removed, or diagnosed successfully. |
| 2 | User-actionable setup is needed. |
| 3 | Missing client binary or required dependency. |
| 4 | Missing bundled helper script. |
| 5 | Registration command ran but the client did not list the server. |
