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
"""Print an LCA token for the MCP gateway to stdout.

Usage: uv run get_token.py [env]
  env ∈ {st1, st2, st3, prod}; defaults to prod.

Exit codes:
  0 — token on stdout (no trailing newline).
  1 — unexpected runtime error.
  2 — ACTION REQUIRED: user needs to do a one-time setup step.
"""

import sys

from rbx_skills_mcp_gateway.auth import AuthError, SetupRequired, get_lca_token

_VALID_ENVS = {"st1", "st2", "st3", "prod"}

env = sys.argv[1] if len(sys.argv) > 1 else "prod"
if env not in _VALID_ENVS:
    print(
        f"get_token.py: unknown env '{env}' (expected {', '.join(sorted(_VALID_ENVS))})",
        file=sys.stderr,
    )
    sys.exit(1)

try:
    result = get_lca_token(env)
    print(result.token, end="")
except SetupRequired as exc:
    print(str(exc), file=sys.stderr)
    sys.exit(2)
except AuthError as exc:
    print(str(exc), file=sys.stderr)
    sys.exit(1)
