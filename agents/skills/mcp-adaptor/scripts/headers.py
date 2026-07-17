#!/usr/bin/env -S uv run --script
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
"""Claude Code headersHelper: emit {"RBX-LCA-v1":"<token>"} on each MCP request.

Env overrides:
  MCP_GW_ENV=st1|st2|st3|prod  (default: prod)

Replaces headers.sh. Uses the rbx-skills-mcp-gateway shared library so
requests are made via Python's requests module — no curl, no platform-
specific SSL revocation checks, works on Linux, macOS, and Windows.
"""

import json
import os
import sys

from rbx_skills_mcp_gateway.auth import AuthError, SetupRequired, get_lca_token

env = os.environ.get("MCP_GW_ENV", "prod")

try:
    result = get_lca_token(env)
    print(json.dumps({"RBX-LCA-v1": result.token}), end="")
except (SetupRequired, AuthError) as exc:
    print(str(exc), file=sys.stderr)
    print("{}", end="")
