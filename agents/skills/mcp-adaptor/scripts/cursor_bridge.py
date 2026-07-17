# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "mcp>=1.2",
#   "httpx",
#   "anyio",
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
"""Cursor stdio bridge for the Roblox MCP gateway.

Cursor spawns this script as a stdio MCP server. The bridge accepts
JSON-RPC over stdin/stdout from Cursor and proxies every message to the
gateway's Streamable-HTTP MCP endpoint, attaching a fresh LCA token to
each outgoing request via httpx.Auth.

This gives Cursor the same auto-refresh behaviour Claude gets through
its `headersHelper` callback: tokens rotate transparently, no
re-registration needed when one expires.

Usage:
    uv run cursor_bridge.py <server_id>

Env:
    MCP_GW_ENV   one of {st1, st2, st3, prod}; defaults to prod.

Exit codes:
    0  normal shutdown (Cursor closed stdin).
    1  unexpected auth or network failure during startup probe.
    2  bad arguments, unknown env, or user-actionable setup needed.
"""

from __future__ import annotations

import os
import sys

import anyio
import httpx
from mcp.client.streamable_http import streamablehttp_client
from mcp.server.stdio import stdio_server
from rbx_skills_mcp_gateway.auth import (
    AuthError,
    SetupRequired,
    get_lca_token,
)

_BASES = {
    "st1": "https://snc2-apis.sitetest1.simulpong.com/mcp-gateway",
    "st2": "https://snc2-apis.sitetest2.simulpong.com/mcp-gateway",
    "st3": "https://apis.sitetest3.simulpong.com/mcp-gateway",
    "prod": "https://apis.simulprod.com/mcp-gateway",
}


class FreshLCAAuth(httpx.Auth):
    """Attach a fresh ``RBX-LCA-v1`` header to each outgoing request.

    The shared library checks injected token freshness and can fall through to
    refreshed files or exchange flows, so the value we attach is current at
    the moment of the request.
    """

    requires_request_body = False

    def __init__(self, env: str) -> None:
        self._env = env

    def auth_flow(self, request):  # type: ignore[override]
        try:
            result = get_lca_token(self._env)
        except SetupRequired as exc:
            print(f"cursor_bridge: {exc}", file=sys.stderr)
            raise
        except AuthError as exc:
            print(f"cursor_bridge: {exc}", file=sys.stderr)
            raise
        request.headers["RBX-LCA-v1"] = result.token
        yield request


async def _pump(source, sink) -> None:
    """Forward messages from source to sink until source closes."""
    try:
        async for item in source:
            if isinstance(item, Exception):
                print(f"cursor_bridge: stream error: {item}", file=sys.stderr)
                break
            await sink.send(item)
    finally:
        await sink.aclose()


async def run_bridge(server_id: str, env: str) -> None:
    url = f"{_BASES[env]}/mcp/server/{server_id}"

    async with stdio_server() as (cursor_in, cursor_out):
        async with streamablehttp_client(url, auth=FreshLCAAuth(env)) as gw:
            gw_in, gw_out, _get_session_id = gw
            async with anyio.create_task_group() as tg:
                tg.start_soon(_pump, cursor_in, gw_out)
                tg.start_soon(_pump, gw_in, cursor_out)


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: uv run cursor_bridge.py <server_id>", file=sys.stderr)
        sys.exit(2)
    server_id = sys.argv[1]
    env = os.environ.get("MCP_GW_ENV", "prod")
    if env not in _BASES:
        print(
            f"cursor_bridge: unknown env '{env}' "
            f"(expected {', '.join(_BASES)})",
            file=sys.stderr,
        )
        sys.exit(2)

    try:
        get_lca_token(env)
    except SetupRequired as exc:
        print(f"cursor_bridge: {exc}", file=sys.stderr)
        sys.exit(2)
    except AuthError as exc:
        print(f"cursor_bridge: {exc}", file=sys.stderr)
        sys.exit(1)

    try:
        anyio.run(run_bridge, server_id, env)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
