# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "mcp",
#   "httpx",
#   "rbx-skills-mcp-gateway",
# ]
#
# [tool.uv]
# upgrade-package = ["rbx-skills-mcp-gateway"]
#
# [[tool.uv.index]]
# url = "https://artifactory.rbx.com/api/pypi/pypi-all/simple"
# default = true
# ///
"""Smoke-test a Gateway server through the Claude-style HTTP MCP path.

Claude Code registers Gateway MCPs as Streamable HTTP servers and uses
headersHelper for fresh RBX-LCA-v1 auth. This script uses the same HTTP MCP
transport and shared auth library in-process, then reports timings without
printing credential values.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import time
from typing import Any

import httpx
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client
from rbx_skills_mcp_gateway.auth import get_lca_token
from rbx_skills_mcp_gateway.client import ENV_BASE_URL


_VALID_ENVS = {"st1", "st2", "st3", "prod"}


class FreshLCAAuth(httpx.Auth):
    requires_request_body = False

    def __init__(self, env: str) -> None:
        self.env = env

    def auth_flow(self, request):  # type: ignore[override]
        result = get_lca_token(self.env)
        request.headers["RBX-LCA-v1"] = result.token
        yield request


def _content_preview(content: list[Any], limit: int) -> list[str]:
    previews: list[str] = []
    for item in content:
        text = getattr(item, "text", None)
        if isinstance(text, str):
            previews.append(text[:limit])
        else:
            previews.append(repr(item)[:limit])
    return previews


async def _check(args: argparse.Namespace) -> dict[str, Any]:
    url = f"{ENV_BASE_URL[args.env]}/mcp/server/{args.server_id}"
    t0 = time.monotonic()
    async with streamablehttp_client(url, auth=FreshLCAAuth(args.env)) as (
        read,
        write,
        _,
    ):
        t1 = time.monotonic()
        async with ClientSession(read, write) as session:
            await asyncio.wait_for(session.initialize(), timeout=args.timeout)
            t2 = time.monotonic()
            tools = await asyncio.wait_for(session.list_tools(), timeout=args.timeout)
            t3 = time.monotonic()
            result: dict[str, Any] = {
                "server": args.server_id,
                "env": args.env,
                "context_sec": round(t1 - t0, 3),
                "initialize_sec": round(t2 - t1, 3),
                "list_tools_sec": round(t3 - t2, 3),
                "total_sec": round(t3 - t0, 3),
                "tool_count": len(tools.tools),
                "tools": [tool.name for tool in tools.tools],
            }
            if args.call_tool:
                tool_args = json.loads(args.args_json)
                call_t0 = time.monotonic()
                call = await asyncio.wait_for(
                    session.call_tool(args.call_tool, tool_args),
                    timeout=args.timeout,
                )
                result["call"] = {
                    "tool": args.call_tool,
                    "call_sec": round(time.monotonic() - call_t0, 3),
                    "is_error": bool(call.isError),
                    "content_items": len(call.content),
                    "text_preview": _content_preview(call.content, args.preview_chars),
                }
            return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Smoke-test a Claude-style HTTP Gateway MCP without printing secrets."
    )
    parser.add_argument("server_id", help="Gateway server id, for example sourcegraph")
    parser.add_argument(
        "env",
        nargs="?",
        default=os.environ.get("MCP_GW_ENV", "prod"),
        help="Gateway env: st1, st2, st3, or prod",
    )
    parser.add_argument("--timeout", type=float, default=90.0)
    parser.add_argument("--call-tool", help="Optional tool name to invoke")
    parser.add_argument("--args-json", default="{}")
    parser.add_argument("--preview-chars", type=int, default=1000)
    args = parser.parse_args()

    if args.env not in _VALID_ENVS:
        parser.error(f"unknown env '{args.env}' (expected {', '.join(sorted(_VALID_ENVS))})")
    if args.call_tool and not isinstance(json.loads(args.args_json), dict):
        parser.error("--args-json must decode to a JSON object")

    print(json.dumps(asyncio.run(_check(args)), sort_keys=True))


if __name__ == "__main__":
    main()
