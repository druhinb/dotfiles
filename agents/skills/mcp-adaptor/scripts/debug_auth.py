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
"""Print non-secret MCP Gateway auth diagnostics.

This script reports token sources and JWT claim status without printing token
values. It is meant for troubleshooting stale injected tokens and audience
mismatches.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone

from rbx_skills_mcp_gateway import (
    expected_audience,
    injected_token,
    injected_token_statuses,
)


def _format_time(ts: int | None) -> str | None:
    if ts is None:
        return None
    return datetime.fromtimestamp(ts, timezone.utc).isoformat()


def main() -> None:
    parser = argparse.ArgumentParser(description="Debug MCP Gateway auth sources.")
    parser.add_argument(
        "--env",
        choices=("st1", "st2", "st3", "prod"),
        default="prod",
        help="Gateway env to validate against.",
    )
    args = parser.parse_args()

    expected = expected_audience(args.env)
    sources = []
    for candidate in injected_token_statuses(args.env):
        status = candidate.status
        sources.append(
            {
                "source": candidate.source,
                "usable": status.usable,
                "reason": status.reason,
                "expires_at": _format_time(status.expires_at),
                "audience_matches": (
                    None
                    if status.audience is None
                    else expected
                    in (
                        status.audience
                        if isinstance(status.audience, list)
                        else [status.audience]
                    )
                ),
            }
        )

    selected = injected_token(args.env)
    payload = {
        "env": args.env,
        "expected_audience": expected,
        "injected_sources": sources,
        "selected_injected_source": selected.source if selected is not None else None,
        "recommendation": _recommendation(sources, selected is not None),
    }
    print(json.dumps(payload, indent=2))


def _recommendation(sources: list[dict], has_selected: bool) -> str:
    if has_selected:
        return "An injected token source is usable. If MCP still fails, check OAuth grants and gateway connectivity."
    if sources:
        return "Injected tokens were found but are unusable. Reconnect the runtime or refresh coder external auth."
    return "No injected token was found. In devspace, run `coder external-auth github-enterprise`; in declawd, restart declawd or check its token path."


if __name__ == "__main__":
    main()
