#!/usr/bin/env bash
# Remove a previously registered MCP Gateway server from Claude Code.
#
# Usage: remove_server.sh <server_id> [env]
#   env ∈ {st1, st2, st3, prod}.
#   Resolution: explicit arg -> $MCP_GW_ENV -> prod.
#
# Drops the claude mcp entry, strips the headersHelper patch from
# ~/.claude.json, and removes the wildcard permission from
# ~/.claude/settings.json. Safe to run if the entry is already gone.
set -euo pipefail

id="${1:?server id required}"
env="${2:-${MCP_GW_ENV:-prod}}"

if [ "$env" = "prod" ]; then
  name="mcp-gateway-${id}"
else
  name="mcp-gateway-${id}-${env}"
fi

for dep in jq python3; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo "remove_server.sh: missing required tool '$dep' on PATH" >&2
    exit 3
  fi
done

if [ -x "/Applications/declawd.app/Contents/Helpers/claude" ]; then
  CLAUDE="/Applications/declawd.app/Contents/Helpers/claude"
else
  CLAUDE="$(command -v claude || true)"
fi
[ -n "$CLAUDE" ] || { echo "remove_server.sh: claude binary not found on PATH" >&2; exit 3; }

"$CLAUDE" mcp remove "$name" --scope user >/dev/null 2>&1 || true

python3 - "$name" <<'PY'
import json, os, sys
name = sys.argv[1]
config_dir = os.environ.get("CLAUDE_CONFIG_DIR")
cfg = os.path.join(config_dir, ".claude.json") if config_dir else os.path.expanduser("~/.claude.json")
if not os.path.exists(cfg):
    print(f"no Claude config to prune for {name}")
    raise SystemExit(0)
with open(cfg) as f:
    try:
        data = json.load(f)
    except ValueError:
        data = {}
changed = False
if data.get("mcpServers", {}).pop(name, None) is not None:
    changed = True
if changed:
    with open(cfg, "w") as f:
        json.dump(data, f, indent=2)
print(f"pruned ~/.claude.json for {name} (changed={changed})")
PY

if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
  settings="$CLAUDE_CONFIG_DIR/settings.json"
else
  settings="$HOME/.claude/settings.json"
fi
rule="mcp__${name}"
if [ -f "$settings" ]; then
  tmp=$(mktemp)
  jq --arg r "$rule" \
    '.permissions.allow = ((.permissions.allow // []) | map(select(. != $r)))' \
    "$settings" > "$tmp" && mv "$tmp" "$settings"
  echo "stripped permission rule: $rule"
fi

# Cursor: drop the stdio-bridge entry too, if Cursor is installed.
cursor_cfg="$HOME/.cursor/mcp.json"
if [ -f "$cursor_cfg" ]; then
  python3 - "$cursor_cfg" "$name" <<'PY'
import json, os, sys
cfg, name = sys.argv[1], sys.argv[2]
with open(cfg) as f:
    try:
        data = json.load(f)
    except ValueError:
        data = {}
changed = data.get("mcpServers", {}).pop(name, None) is not None
if changed:
    with open(cfg, "w") as f:
        json.dump(data, f, indent=2)
    print(f"pruned {cfg} for {name}")
PY
fi

echo "ok: $name removed"

cat <<'EOF'

  NEXT STEP: restart or reconnect Claude so the removal takes effect.
    • full restart is the reliable path for an already-running session
    • use Claude's MCP reconnect flow only if you know it reloads config
EOF
if [ -d "$HOME/.cursor" ]; then
  echo "  If you also use Cursor, restart Cursor (or toggle the MCP server"
  echo "  off/on in Settings → Tools & Integrations) so the removal is picked up."
fi
