# /// script
# requires-python = ">=3.10"
# dependencies = ["mcp"]
#
# [tool.uv]
# upgrade-package = ["rbx-skills-auth"]
#
# [[tool.uv.index]]
# url = "https://artifactory.rbx.com/api/pypi/pypi-all/simple"
# default = true
# ///
"""Smoke-test a Roblox MCP Gateway server through the Codex stdio proxy.

Usage:
  uv run smoke_codex_server.py <server_id> [env]
  uv run smoke_codex_server.py <server_id> [env] --call-tool <name> --args-json '{}'

This does not read Codex config. It launches the same stdio proxy command that
register_codex_server.py writes, preserves the current process environment, and
prints only non-secret timing/tool metadata plus an optional tool result
preview.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
from pathlib import Path
import shutil
import time
from typing import Any

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


_VALID_ENVS = {"st1", "st2", "st3", "prod"}
_ARTIFACTORY_INDEX = "https://artifactory.rbx.com/api/pypi/pypi-all/simple"
_PROXY_PACKAGE = "rbx-skills-mcp-gateway[codex-proxy]"
_PROXY_BINARY = "rbx-skills-codex-mcp-proxy"


def _installed_proxy() -> str | None:
    candidates = [
        Path.home() / ".local" / "bin" / _PROXY_BINARY,
        shutil.which(_PROXY_BINARY),
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(candidate)
    return None


def _proxy_params(server_id: str, env_name: str) -> StdioServerParameters:
    env = os.environ.copy()
    env["MCP_GW_ENV"] = env_name
    env["MCP_GW_UNAVAILABLE_MODE"] = "exit"
    proxy = _installed_proxy()
    if proxy:
        return StdioServerParameters(command=proxy, args=[server_id], env=env)
    return StdioServerParameters(
        command="uv",
        args=[
            "run",
            "--with",
            _PROXY_PACKAGE,
            "--index",
            _ARTIFACTORY_INDEX,
            _PROXY_BINARY,
            server_id,
        ],
        env=env,
    )


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
    params = _proxy_params(args.server_id, args.env)
    t0 = time.monotonic()
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await asyncio.wait_for(session.initialize(), timeout=args.timeout)
            t1 = time.monotonic()
            tools = await asyncio.wait_for(session.list_tools(), timeout=args.timeout)
            t2 = time.monotonic()
            result: dict[str, Any] = {
                "server": args.server_id,
                "env": args.env,
                "initialize_sec": round(t1 - t0, 3),
                "list_tools_sec": round(t2 - t1, 3),
                "tool_count": len(tools.tools),
                "tools": [tool.name for tool in tools.tools],
            }
            if args.call_tool:
                tool_args = json.loads(args.args_json)
                call = await asyncio.wait_for(
                    session.call_tool(args.call_tool, tool_args),
                    timeout=args.timeout,
                )
                result["call"] = {
                    "tool": args.call_tool,
                    "is_error": call.isError,
                    "content_items": len(call.content),
                    "text_preview": _content_preview(call.content, args.preview_chars),
                }
            return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Smoke-test a Codex MCP Gateway stdio proxy without printing secrets."
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
    parser.add_argument(
        "--args-json",
        default="{}",
        help="JSON object to pass to --call-tool",
    )
    parser.add_argument("--preview-chars", type=int, default=1000)
    args = parser.parse_args()

    if args.env not in _VALID_ENVS:
        parser.error(f"unknown env '{args.env}' (expected {', '.join(sorted(_VALID_ENVS))})")
    if args.call_tool and not isinstance(json.loads(args.args_json), dict):
        parser.error("--args-json must decode to a JSON object")

    print(json.dumps(asyncio.run(_check(args)), sort_keys=True))


if __name__ == "__main__":
    main()
