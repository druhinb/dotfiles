# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets"]
#
# [[tool.uv.index]]
# url = "https://artifactory.rbx.com/api/pypi/pypi-all/simple"
# default = true
# ///
"""Smoke-test Codex app-server MCP visibility without printing secrets.

Usage:
  uv run smoke_codex_app_server.py --reload
  uv run smoke_codex_app_server.py --call-server mcp-gateway-sourcegraph \
    --call-tool search --args-json '{"query":"repo:Roblox/skills count:1"}'

The Codex app server is used by integrations such as BuilderAI. This script
checks the app-server path directly instead of only checking `codex mcp list`.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import time
from typing import Any

import websockets


DEFAULT_APP_SERVER_URL = "ws://127.0.0.1:8080"


class AppServerClient:
    def __init__(self, url: str, timeout: float) -> None:
        self.url = url
        self.timeout = timeout
        self._next_id = 1
        self.notifications: list[dict[str, Any]] = []

    async def __aenter__(self) -> "AppServerClient":
        self.ws = await websockets.connect(self.url, max_size=32 * 1024 * 1024)
        await self.request(
            "initialize",
            {"clientInfo": {"name": "mcp-adaptor-app-smoke", "version": "0"}},
        )
        return self

    async def __aexit__(self, exc_type: object, exc: object, tb: object) -> None:
        await self.ws.close()

    async def request(self, method: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        request_id = self._next_id
        self._next_id += 1
        payload: dict[str, Any] = {"id": request_id, "method": method}
        if params is not None:
            payload["params"] = params
        await self.ws.send(json.dumps(payload))

        while True:
            raw = await asyncio.wait_for(self.ws.recv(), timeout=self.timeout)
            message = json.loads(raw)
            if message.get("id") == request_id:
                if "error" in message:
                    raise RuntimeError(
                        f"{method} failed: {json.dumps(message['error'], sort_keys=True)}"
                    )
                return message
            self.notifications.append(message)


def _summarize_servers(
    response: dict[str, Any], max_tools: int
) -> tuple[list[dict[str, Any]], int | None]:
    result = response.get("result") or {}
    raw_servers = result.get("data") or []
    next_cursor = result.get("nextCursor")
    servers = []

    for server in raw_servers:
        tools = server.get("tools") or {}
        if isinstance(tools, dict):
            tool_names = sorted(tools)
        elif isinstance(tools, list):
            tool_names = sorted(
                tool.get("name", "") for tool in tools if isinstance(tool, dict)
            )
        else:
            tool_names = []

        servers.append(
            {
                "name": server.get("name"),
                "auth_status": server.get("authStatus"),
                "server_info_present": bool(server.get("serverInfo")),
                "tool_count": len(tool_names),
                "tools": tool_names[:max_tools],
            }
        )

    return servers, next_cursor


def _preview_call_result(response: dict[str, Any], preview_chars: int) -> dict[str, Any]:
    result = response.get("result") or {}
    content = result.get("content") or []
    previews = []
    for item in content:
        if isinstance(item, dict) and isinstance(item.get("text"), str):
            previews.append(item["text"][:preview_chars])
        else:
            previews.append(repr(item)[:preview_chars])

    return {
        "is_error": bool(result.get("isError", False)),
        "content_items": len(content),
        "text_preview": previews,
    }


async def _run(args: argparse.Namespace) -> dict[str, Any]:
    total_t0 = time.monotonic()
    async with AppServerClient(args.url, args.timeout) as client:
        output: dict[str, Any] = {"url": args.url}

        if args.reload:
            reload_t0 = time.monotonic()
            await client.request("config/mcpServer/reload")
            output["reload_sec"] = round(time.monotonic() - reload_t0, 3)
            output["reload"] = "ok"

        thread_id = args.thread_id
        if args.call_server or args.call_tool:
            if not args.call_server or not args.call_tool:
                raise SystemExit("--call-server and --call-tool must be used together")
            if not thread_id:
                started = await client.request(
                    "thread/start",
                    {
                        "cwd": args.cwd,
                        "sandbox": args.sandbox,
                        "approvalPolicy": "never",
                        "ephemeral": True,
                        "sessionStartSource": "startup",
                    },
                )
                start_result = started.get("result") or {}
                thread_id = start_result.get("threadId") or (
                    (start_result.get("thread") or {}).get("id")
                )
                if not thread_id:
                    raise RuntimeError("thread/start response did not include a thread id")
                output["started_thread"] = bool(thread_id)

        list_params: dict[str, Any] = {"detail": args.detail, "limit": args.limit}
        if thread_id:
            list_params["threadId"] = thread_id
        list_t0 = time.monotonic()
        status = await client.request("mcpServerStatus/list", list_params)
        output["list_sec"] = round(time.monotonic() - list_t0, 3)
        servers, next_cursor = _summarize_servers(status, args.max_tools)
        output["server_count"] = len(servers)
        output["next_cursor"] = next_cursor
        output["empty_tool_servers"] = [
            server["name"] for server in servers if server["tool_count"] == 0
        ]
        output["servers"] = servers

        if args.call_server and args.call_tool:
            tool_args = json.loads(args.args_json)
            if not isinstance(tool_args, dict):
                raise SystemExit("--args-json must decode to a JSON object")
            call_t0 = time.monotonic()
            call = await client.request(
                "mcpServer/tool/call",
                {
                    "server": args.call_server,
                    "threadId": thread_id,
                    "tool": args.call_tool,
                    "arguments": tool_args,
                },
            )
            output["call"] = {
                "server": args.call_server,
                "tool": args.call_tool,
                "call_sec": round(time.monotonic() - call_t0, 3),
                **_preview_call_result(call, args.preview_chars),
            }

        startup_notifications = [
            message
            for message in client.notifications
            if message.get("method") == "mcpServer/startupStatus/updated"
        ]
        output["startup_notification_count"] = len(startup_notifications)
        output["total_sec"] = round(time.monotonic() - total_t0, 3)
        return output


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Check Codex app-server MCP status and optional tool calls."
    )
    parser.add_argument("--url", default=os.environ.get("CODEX_APP_SERVER_URL", DEFAULT_APP_SERVER_URL))
    parser.add_argument("--reload", action="store_true", help="Reload MCP config before listing")
    parser.add_argument(
        "--detail",
        choices=["full", "toolsAndAuthOnly"],
        default="toolsAndAuthOnly",
    )
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--max-tools", type=int, default=20)
    parser.add_argument("--thread-id", help="Existing Codex app-server thread id")
    parser.add_argument("--cwd", default=os.getcwd())
    parser.add_argument("--sandbox", default="read-only")
    parser.add_argument("--timeout", type=float, default=90.0)
    parser.add_argument("--call-server", help="Server name, for example mcp-gateway-sourcegraph")
    parser.add_argument("--call-tool", help="Tool name to invoke through app-server")
    parser.add_argument("--args-json", default="{}")
    parser.add_argument("--preview-chars", type=int, default=1000)
    args = parser.parse_args()

    print(json.dumps(asyncio.run(_run(args)), sort_keys=True))


if __name__ == "__main__":
    main()
