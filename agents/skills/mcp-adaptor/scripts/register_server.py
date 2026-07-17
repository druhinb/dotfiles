# /// script
# requires-python = ">=3.10"
# dependencies = []
#
# [[tool.uv.index]]
# url = "https://artifactory.rbx.com/api/pypi/pypi-all/simple"
# default = true
# ///
"""Register (or re-register) a single MCP Gateway server with Claude Code.

Usage: uv run register_server.py <server_id> [env]
  env ∈ {st1, st2, st3, prod}  (default: prod, or $MCP_GW_ENV)

Idempotent: upserts the claude mcp entry, patches headersHelper in
~/.claude.json, and adds a wildcard mcp__mcp-gateway-<id> permission to
~/.claude/settings.json. Only the named server's entry is touched.

Exit codes:
  0 — registered successfully.
  2 — bad arguments / unknown env.
  3 — missing dependency (claude binary).
  4 — missing headers helper script.
  5 — registration command ran but the local config entry was not present.
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def _claude_config_paths() -> tuple[Path, Path]:
    """Return (claude.json path, settings.json path) honouring CLAUDE_CONFIG_DIR.

    When CLAUDE_CONFIG_DIR is set (e.g. D:\\.claude on Windows devspaces),
    both files live inside that directory.  Otherwise they follow the default
    XDG-style layout: ~/.claude.json and ~/.claude/settings.json.
    """
    config_dir_env = os.environ.get("CLAUDE_CONFIG_DIR")
    if config_dir_env:
        config_dir = Path(config_dir_env)
        return config_dir / ".claude.json", config_dir / "settings.json"
    home = Path.home()
    return home / ".claude.json", home / ".claude" / "settings.json"


def _cursor_config_path() -> Path | None:
    """Return Cursor's MCP config file path when Cursor is installed.

    Detection checks for Cursor's config directory under the user home.
    Returns None when that directory is missing so Cursor registration
    is skipped.
    """
    cursor_dir = Path.home() / ".cursor"
    if not cursor_dir.is_dir():
        return None
    return cursor_dir / "mcp.json"

_BASES = {
    "st1": "https://snc2-apis.sitetest1.simulpong.com/mcp-gateway",
    "st2": "https://snc2-apis.sitetest2.simulpong.com/mcp-gateway",
    "st3": "https://apis.sitetest3.simulpong.com/mcp-gateway",
    "prod": "https://apis.simulprod.com/mcp-gateway",
}

if len(sys.argv) < 2:
    print("usage: uv run register_server.py <server_id> [env]", file=sys.stderr)
    sys.exit(2)

server_id = sys.argv[1]
env = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("MCP_GW_ENV", "prod")

if env not in _BASES:
    print(f"register_server.py: unknown env '{env}' (expected {', '.join(_BASES)})", file=sys.stderr)
    sys.exit(2)

# Locate the claude binary.
_declawd = Path("/Applications/declawd.app/Contents/Helpers/claude")
claude = str(_declawd) if _declawd.is_file() else shutil.which("claude")
if not claude:
    print("register_server.py: claude binary not found on PATH", file=sys.stderr)
    sys.exit(3)

# Resolve the headersHelper for this platform.
script_dir = Path(__file__).parent
headers_py = script_dir / "headers.py"
if not headers_py.exists():
    print(f"register_server.py: headers.py not found at {headers_py}", file=sys.stderr)
    sys.exit(4)

if sys.platform == "win32":
    # Node.js (v18.20+) cannot spawn .cmd files without shell:true; use the
    # compiled .exe wrapper instead so spawnSync works without a shell.
    headers_helper_exe = script_dir / "headers_helper.exe"
    if not headers_helper_exe.exists():
        print(f"register_server.py: headers_helper.exe not found at {headers_helper_exe}", file=sys.stderr)
        sys.exit(4)
    headers_helper = str(headers_helper_exe)
else:
    headers_helper = f"MCP_GW_ENV={env} uv run {headers_py}"

# Register with claude. For non-prod environments, suffix the name so multiple envs can coexist.
name = f"mcp-gateway-{server_id}" if env == "prod" else f"mcp-gateway-{server_id}-{env}"
url = f"{_BASES[env]}/mcp/server/{server_id}"

subprocess.run([claude, "mcp", "remove", name, "--scope", "user"], capture_output=True)
subprocess.run([claude, "mcp", "add", "--transport", "http", "--scope", "user", name, url], check=True)

# Patch headersHelper in the correct claude.json.
cfg_path, settings_path = _claude_config_paths()
data: dict = {}
if cfg_path.exists():
    try:
        data = json.loads(cfg_path.read_text(encoding="utf-8"))
    except ValueError:
        pass
data.setdefault("mcpServers", {}).setdefault(name, {})["headersHelper"] = headers_helper
cfg_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
print(f"patched headersHelper for {name} -> {headers_helper}")

# Add wildcard permission to settings.json.
rule = f"mcp__{name}"
settings: dict = {}
if settings_path.exists():
    try:
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
    except ValueError:
        pass
allow: list = settings.setdefault("permissions", {}).setdefault("allow", [])
if rule not in allow:
    allow.append(rule)
settings_path.parent.mkdir(parents=True, exist_ok=True)
settings_path.write_text(json.dumps(settings, indent=2), encoding="utf-8")
print(f"allowed rule: {rule}")

# Cursor: stdio-bridge entry, only when the user has Cursor installed.
cursor_path = _cursor_config_path()
if cursor_path is None:
    print("note: ~/.cursor/ not found — skipping Cursor registration", file=sys.stderr)
else:
    bridge_py = script_dir / "cursor_bridge.py"
    if not bridge_py.exists():
        print(
            f"register_server.py: cursor_bridge.py not found at {bridge_py}",
            file=sys.stderr,
        )
        sys.exit(4)
    uv_path = shutil.which("uv") or "uv"
    cursor_data: dict = {}
    if cursor_path.exists():
        try:
            cursor_data = json.loads(cursor_path.read_text(encoding="utf-8"))
        except ValueError:
            cursor_data = {}
    cursor_data.setdefault("mcpServers", {})[name] = {
        "command": uv_path,
        "args": ["run", str(bridge_py), server_id],
        "env": {"MCP_GW_ENV": env},
    }
    cursor_path.write_text(
        json.dumps(cursor_data, indent=2), encoding="utf-8"
    )
    print(f"patched {cursor_path} with stdio bridge for {name}")

# Verify only the local entry we just wrote. `claude mcp list/get` performs
# network health checks, so using it here makes bulk registration slow.
if name in data.get("mcpServers", {}):
    print(f"ok: {name} registered against {env}")
else:
    print(f"warning: {name} not visible in local Claude config", file=sys.stderr)
    sys.exit(5)

print("""
  NEXT STEP: restart or reconnect Claude so the server becomes visible.
    \u2022 full restart is the reliable path for an already-running session
    \u2022 use Claude's MCP reconnect flow only if you know it reloads config""")
if cursor_path is not None:
    print(
        "  If you also use Cursor, restart Cursor (or toggle the MCP server "
        "off/on in Settings \u2192 Tools & Integrations) so the new entry "
        "is loaded."
    )
