#!/usr/bin/env bash
# Register (or re-register) a single MCP Gateway server with Claude Code.
#
# Usage: register_server.sh <server_id> [env]
#   env ∈ {st1, st2, st3, prod}.
#   Resolution: explicit arg -> $MCP_GW_ENV -> prod.
#
# Idempotent: upserts the `claude mcp add` entry, patches `headersHelper`
# in ~/.claude.json, and appends a wildcard `mcp__mcp-gateway-<id>` rule
# to ~/.claude/settings.json. Only the named server's entry is touched;
# other mcp-gateway-* entries are left alone.
set -euo pipefail

id="${1:?server id required (e.g. mosaic_mds, logs, grafana)}"
env="${2:-${MCP_GW_ENV:-prod}}"

case "$env" in
  st1)  base="https://snc2-apis.sitetest1.simulpong.com/mcp-gateway" ;;
  st2)  base="https://snc2-apis.sitetest2.simulpong.com/mcp-gateway" ;;
  st3)  base="https://apis.sitetest3.simulpong.com/mcp-gateway" ;;
  prod) base="https://apis.simulprod.com/mcp-gateway" ;;
  *) echo "unknown env: $env (expected st1|st2|st3|prod)" >&2; exit 2 ;;
esac

for dep in jq python3; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo "register_server.sh: missing required tool '$dep' on PATH" >&2
    exit 3
  fi
done

if [ -x "/Applications/declawd.app/Contents/Helpers/claude" ]; then
  CLAUDE="/Applications/declawd.app/Contents/Helpers/claude"
else
  CLAUDE="$(command -v claude || true)"
fi
[ -n "$CLAUDE" ] || { echo "register_server.sh: claude binary not found on PATH" >&2; exit 3; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
headers_script="$script_dir/headers.py"
if [ ! -r "$headers_script" ]; then
  echo "register_server.sh: headers.py missing at $headers_script" >&2
  exit 4
fi

# For non-prod environments, suffix the name so multiple envs can coexist.
if [ "$env" = "prod" ]; then
  name="mcp-gateway-${id}"
else
  name="mcp-gateway-${id}-${env}"
fi
url="${base}/mcp/server/${id}"

"$CLAUDE" mcp remove "$name" --scope user >/dev/null 2>&1 || true
"$CLAUDE" mcp add --transport http --scope user "$name" "$url"

python3 - "$headers_script" "$name" "$env" <<'PY'
import json, os, sys
headers_py, name, gw_env = sys.argv[1], sys.argv[2], sys.argv[3]
config_dir = os.environ.get("CLAUDE_CONFIG_DIR")
cfg = os.path.join(config_dir, ".claude.json") if config_dir else os.path.expanduser("~/.claude.json")
data = {}
if os.path.exists(cfg):
    with open(cfg) as f:
        try:
            data = json.load(f)
        except ValueError:
            data = {}
helper_cmd = f"MCP_GW_ENV={gw_env} uv run {headers_py}"
data.setdefault("mcpServers", {}).setdefault(name, {})["headersHelper"] = helper_cmd
os.makedirs(os.path.dirname(cfg), exist_ok=True)
with open(cfg, "w") as f:
    json.dump(data, f, indent=2)
print(f"patched headersHelper for {name} -> {helper_cmd}")
PY

if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
  settings="$CLAUDE_CONFIG_DIR/settings.json"
else
  settings="$HOME/.claude/settings.json"
fi
rule="mcp__${name}"
tmp=$(mktemp)
if [ -f "$settings" ]; then
  jq --arg r "$rule" \
    '.permissions.allow = ((.permissions.allow // []) + [$r] | unique)' \
    "$settings" > "$tmp" && mv "$tmp" "$settings"
else
  mkdir -p "$(dirname "$settings")"
  jq -n --arg r "$rule" '{permissions: {allow: [$r]}}' > "$settings"
fi
echo "allowed rule: $rule"

# Cursor: stdio-bridge entry, only when the user has Cursor installed.
if [ -d "$HOME/.cursor" ]; then
  bridge_py="$script_dir/cursor_bridge.py"
  if [ ! -r "$bridge_py" ]; then
    echo "register_server.sh: cursor_bridge.py missing at $bridge_py" >&2
    exit 4
  fi
  uv_path="$(command -v uv || echo uv)"
  cursor_cfg="$HOME/.cursor/mcp.json"
  python3 - "$cursor_cfg" "$name" "$bridge_py" "$id" "$env" "$uv_path" <<'PY'
import json, os, sys
cfg, name, bridge_py, server_id, gw_env, uv_path = sys.argv[1:7]
data = {}
if os.path.exists(cfg):
    with open(cfg) as f:
        try:
            data = json.load(f)
        except ValueError:
            data = {}
data.setdefault("mcpServers", {})[name] = {
    "command": uv_path,
    "args": ["run", bridge_py, server_id],
    "env": {"MCP_GW_ENV": gw_env},
}
os.makedirs(os.path.dirname(cfg), exist_ok=True)
with open(cfg, "w") as f:
    json.dump(data, f, indent=2)
print(f"patched {cfg} with stdio bridge for {name}")
PY
else
  echo "note: ~/.cursor/ not found — skipping Cursor registration" >&2
fi

if python3 - "$cfg" "$name" <<'PY'
import json, sys
cfg, name = sys.argv[1:3]
try:
    with open(cfg) as f:
        data = json.load(f)
except Exception:
    data = {}
raise SystemExit(0 if name in data.get("mcpServers", {}) else 1)
PY
then
  echo "ok: $name registered against $env"
else
  echo "warning: $name not visible in local Claude config" >&2
  exit 5
fi

cat <<'EOF'

  NEXT STEP: restart or reconnect Claude so the server becomes visible.
    • full restart is the reliable path for an already-running session
    • use Claude's MCP reconnect flow only if you know it reloads config
EOF
if [ -d "$HOME/.cursor" ]; then
  echo "  If you also use Cursor, restart Cursor (or toggle the MCP server"
  echo "  off/on in Settings → Tools & Integrations) so the new entry is loaded."
fi
