# /// script
# requires-python = ">=3.10"
# dependencies = []
#
# [[tool.uv.index]]
# url = "https://artifactory.rbx.com/api/pypi/pypi-all/simple"
# default = true
# ///
"""Remove a previously registered MCP Gateway server from Claude Code.

Usage: uv run remove_server.py <server_id> [env]
  env ∈ {st1, st2, st3, prod}  (default: prod, or $MCP_GW_ENV)

Drops the claude mcp entry, strips the headersHelper patch from
~/.claude.json, and removes the wildcard permission from
~/.claude/settings.json. Safe to run if the entry is already gone.

Exit codes:
  0 — removed successfully.
  2 — missing server_id argument.
  3 — claude binary not found.
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def _claude_config_paths() -> tuple[Path, Path]:
    config_dir_env = os.environ.get("CLAUDE_CONFIG_DIR")
    if config_dir_env:
        config_dir = Path(config_dir_env)
        return config_dir / ".claude.json", config_dir / "settings.json"
    home = Path.home()
    return home / ".claude.json", home / ".claude" / "settings.json"


def _cursor_config_path() -> Path | None:
    """Return Cursor's MCP config file path when Cursor is installed, else None."""
    cursor_dir = Path.home() / ".cursor"
    if not cursor_dir.is_dir():
        return None
    return cursor_dir / "mcp.json"

_VALID_ENVS = {"st1", "st2", "st3", "prod"}

if len(sys.argv) < 2:
    print("usage: uv run remove_server.py <server_id> [env]", file=sys.stderr)
    sys.exit(2)

server_id = sys.argv[1]
env = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("MCP_GW_ENV", "prod")

if env not in _VALID_ENVS:
    print(f"remove_server.py: unknown env '{env}' (expected {', '.join(sorted(_VALID_ENVS))})", file=sys.stderr)
    sys.exit(2)

name = f"mcp-gateway-{server_id}" if env == "prod" else f"mcp-gateway-{server_id}-{env}"

# Locate the claude binary.
_declawd = Path("/Applications/declawd.app/Contents/Helpers/claude")
claude = str(_declawd) if _declawd.is_file() else shutil.which("claude")
if not claude:
    print("remove_server.py: claude binary not found on PATH", file=sys.stderr)
    sys.exit(3)

# Remove from claude mcp.
subprocess.run([claude, "mcp", "remove", name, "--scope", "user"], capture_output=True)

# Prune from the correct claude.json.
cfg_path, settings_path = _claude_config_paths()
if cfg_path.exists():
    try:
        data = json.loads(cfg_path.read_text(encoding="utf-8"))
    except ValueError:
        data = {}
    changed = data.get("mcpServers", {}).pop(name, None) is not None
    if changed:
        cfg_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"pruned ~/.claude.json for {name} (changed={changed})")
else:
    print(f"no ~/.claude.json to prune for {name}")

# Remove permission rule from settings.json.
rule = f"mcp__{name}"
if settings_path.exists():
    try:
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
    except ValueError:
        settings = {}
    allow: list = settings.get("permissions", {}).get("allow", [])
    if rule in allow:
        allow.remove(rule)
        settings_path.write_text(json.dumps(settings, indent=2), encoding="utf-8")
        print(f"stripped permission rule: {rule}")

# Cursor: drop the stdio-bridge entry too, if Cursor is installed.
cursor_path = _cursor_config_path()
if cursor_path is not None and cursor_path.exists():
    try:
        cursor_data = json.loads(cursor_path.read_text(encoding="utf-8"))
    except ValueError:
        cursor_data = {}
    cursor_changed = (
        cursor_data.get("mcpServers", {}).pop(name, None) is not None
    )
    if cursor_changed:
        cursor_path.write_text(
            json.dumps(cursor_data, indent=2), encoding="utf-8"
        )
        print(f"pruned {cursor_path} for {name}")

print(f"ok: {name} removed")
print("""
  NEXT STEP: restart or reconnect Claude so the removal takes effect.
    \u2022 full restart is the reliable path for an already-running session
    \u2022 use Claude's MCP reconnect flow only if you know it reloads config""")
if cursor_path is not None:
    print(
        "  If you also use Cursor, restart Cursor (or toggle the MCP server "
        "off/on in Settings \u2192 Tools & Integrations) so the removal "
        "is picked up."
    )
