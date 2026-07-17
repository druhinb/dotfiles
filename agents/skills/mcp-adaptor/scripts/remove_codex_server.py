# /// script
# requires-python = ">=3.10"
# dependencies = []
#
# [[tool.uv.index]]
# url = "https://artifactory.rbx.com/api/pypi/pypi-all/simple"
# default = true
# ///
"""Remove a Roblox MCP Gateway server from Codex.

Usage: uv run remove_codex_server.py <server_id> [env]
  env in {st1, st2, st3, prod}; defaults to $MCP_GW_ENV or prod.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys


_VALID_ENVS = {"st1", "st2", "st3", "prod"}


def _server_name(server_id: str, env: str) -> str:
    return f"mcp-gateway-{server_id}" if env == "prod" else f"mcp-gateway-{server_id}-{env}"


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: uv run remove_codex_server.py <server_id> [env]", file=sys.stderr)
        sys.exit(2)

    server_id = sys.argv[1]
    env = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("MCP_GW_ENV", "prod")
    if env not in _VALID_ENVS:
        print(
            f"remove_codex_server.py: unknown env '{env}' "
            f"(expected {', '.join(sorted(_VALID_ENVS))})",
            file=sys.stderr,
        )
        sys.exit(2)

    codex = shutil.which("codex")
    if not codex:
        print("remove_codex_server.py: codex binary not found on PATH", file=sys.stderr)
        sys.exit(3)

    name = _server_name(server_id, env)
    subprocess.run([codex, "mcp", "remove", name], check=True)
    print(f"ok: {name} removed from Codex")
    print(
        "\n  NEXT STEP: start a new Codex session so the removal is picked up."
    )


if __name__ == "__main__":
    main()
