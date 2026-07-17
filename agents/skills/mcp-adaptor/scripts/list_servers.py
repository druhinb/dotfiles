# /// script
# requires-python = ">=3.10"
# dependencies = ["rbx-skills-mcp-gateway"]
#
# [tool.uv]
# upgrade-package = ["rbx-skills-mcp-gateway"]
#
# [[tool.uv.index]]
# url = "https://artifactory.rbx.com/api/pypi/pypi-all/simple"
# default = true
# ///
"""List MCP-gateway servers for the registration picker.

Used by the agent in :file:`SKILL.md`: list the servers available on the
gateway, render them as a menu, let the user pick, then call
``register_server.sh <id>`` for each selection.

Emits JSON on stdout:

    {"env": "prod", "servers": [{"id": "...", "name": "...", "description": "..."}, ...]}
"""

from __future__ import annotations

import argparse
import json
import sys

from rbx_skills_mcp_gateway import (
    AuthError,
    GatewayClient,
    GatewayError,
    SetupRequired,
    VALID_ENVS,
)


def main() -> None:
    parser = argparse.ArgumentParser(description="List MCP gateway servers.")
    parser.add_argument(
        "--env",
        choices=VALID_ENVS,
        default=None,
        help="Gateway env. Defaults to prod in declawd, else $MCP_GW_ENV or prod.",
    )
    args = parser.parse_args()

    try:
        with GatewayClient(env=args.env) as c:
            servers = c.list_servers()
            print(json.dumps({"env": c.env, "servers": servers}, indent=2))
    except SetupRequired as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(2)
    except (AuthError, GatewayError) as exc:
        print(f"list_servers: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
