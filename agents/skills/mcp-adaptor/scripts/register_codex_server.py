# /// script
# requires-python = ">=3.10"
# dependencies = []
#
# [[tool.uv.index]]
# url = "https://artifactory.rbx.com/api/pypi/pypi-all/simple"
# default = true
# ///
"""Register Roblox MCP Gateway servers with Codex.

Usage:
  uv run register_codex_server.py <server_id> [env]
  uv run register_codex_server.py <server_id> [<server_id> ...] --env prod

  env in {st1, st2, st3, prod}; defaults to $MCP_GW_ENV or prod.

Codex does not support Claude Code's per-request headersHelper, so this
registers a stdio proxy that attaches fresh MCP Gateway auth on outgoing HTTP
requests. It also stores non-secret proxy and CA environment variables in the
Codex MCP entry because app-server launched MCP subprocesses may not inherit
the interactive shell environment.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


_VALID_ENVS = {"st1", "st2", "st3", "prod"}
_ARTIFACTORY_INDEX = "https://artifactory.rbx.com/api/pypi/pypi-all/simple"
_PROXY_PACKAGE = "rbx-skills-mcp-gateway[codex-proxy]"
_PROXY_SHARED_PACKAGE = "rbx-skills-mcp-gateway"
_PROXY_BINARY = "rbx-skills-codex-mcp-proxy"
_PASSTHROUGH_ENV_VARS = (
    "MCP_GW_UPSTREAM_STARTUP_TIMEOUT_SEC",
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "NO_PROXY",
    "http_proxy",
    "https_proxy",
    "no_proxy",
    "SSL_CERT_FILE",
    "REQUESTS_CA_BUNDLE",
    "NODE_EXTRA_CA_CERTS",
    "PIP_CERT",
)


def _server_name(server_id: str, env: str) -> str:
    return f"mcp-gateway-{server_id}" if env == "prod" else f"mcp-gateway-{server_id}-{env}"


def _uv_tool_env() -> dict[str, str]:
    env = os.environ.copy()
    env["UV_TOOL_DIR"] = _writable_dir(
        os.environ.get("UV_TOOL_DIR"),
        Path.home() / ".local" / "share" / "uv" / "tools",
    )
    env["UV_TOOL_BIN_DIR"] = _writable_dir(
        os.environ.get("UV_TOOL_BIN_DIR"),
        Path.home() / ".local" / "bin",
    )
    return env


def _writable_dir(configured: str | None, fallback: Path) -> str:
    candidates = [Path(configured).expanduser()] if configured else []
    candidates.append(fallback)
    for candidate in candidates:
        try:
            candidate.mkdir(parents=True, exist_ok=True)
        except OSError:
            continue
        if os.access(candidate, os.W_OK):
            return str(candidate)
    tried = ", ".join(map(str, candidates))
    raise OSError(f"no writable uv tool directory found; tried: {tried}")


def _local_proxy_package() -> Path | None:
    """Return a sibling shared package when running from a repo checkout."""
    for parent in Path(__file__).resolve().parents:
        candidate = parent / "shared" / _PROXY_SHARED_PACKAGE
        if (candidate / "pyproject.toml").is_file():
            return candidate
    return None


def _proxy_install_args() -> list[str]:
    local_package = _local_proxy_package()
    if local_package is not None:
        return [
            "--editable",
            f"{local_package}[codex-proxy]",
            "--index",
            _ARTIFACTORY_INDEX,
        ]
    return [
        _PROXY_PACKAGE,
        "--index",
        _ARTIFACTORY_INDEX,
    ]


def _proxy_executable(uv: str) -> str | None:
    tool_env = _uv_tool_env()
    install = subprocess.run(
        [
            uv,
            "tool",
            "install",
            *_proxy_install_args(),
            "--quiet",
        ],
        env=tool_env,
        text=True,
        capture_output=True,
        check=False,
    )
    if install.returncode != 0:
        print(
            "warning: could not install reusable Codex MCP proxy; falling back "
            "to per-start uv run",
            file=sys.stderr,
        )
        if install.stderr.strip():
            print(install.stderr.strip(), file=sys.stderr)
        return None

    bin_dir = subprocess.run(
        [uv, "tool", "dir", "--bin"],
        env=tool_env,
        text=True,
        capture_output=True,
        check=False,
    )
    if bin_dir.returncode == 0 and bin_dir.stdout.strip():
        candidate = Path(bin_dir.stdout.strip()) / _PROXY_BINARY
        if candidate.is_file():
            return str(candidate)

    path = f"{tool_env['UV_TOOL_BIN_DIR']}{os.pathsep}{os.environ.get('PATH', '')}"
    return shutil.which(_PROXY_BINARY, path=path)


def _proxy_command(server_id: str, uv: str, proxy: str | None) -> list[str]:
    if proxy:
        return [proxy, server_id]
    local_package = _local_proxy_package()
    if local_package is not None:
        return [
            uv,
            "run",
            "--with-editable",
            f"{local_package}[codex-proxy]",
            "--index",
            _ARTIFACTORY_INDEX,
            _PROXY_BINARY,
            server_id,
        ]
    return [
        uv,
        "run",
        "--with",
        _PROXY_PACKAGE,
        "--index",
        _ARTIFACTORY_INDEX,
        _PROXY_BINARY,
        server_id,
    ]


def _parse_args(argv: list[str]) -> tuple[list[str], str]:
    parser = argparse.ArgumentParser(
        description="Register one or more Roblox MCP Gateway servers with Codex."
    )
    parser.add_argument("items", nargs="+", help="Server ids, with optional legacy trailing env")
    parser.add_argument(
        "--env",
        choices=sorted(_VALID_ENVS),
        help="Gateway env. Defaults to $MCP_GW_ENV or prod.",
    )
    parsed = parser.parse_args(argv)

    items = list(parsed.items)
    if parsed.env:
        return items, parsed.env

    if len(items) > 1 and items[-1] in _VALID_ENVS:
        return items[:-1], items[-1]

    env = os.environ.get("MCP_GW_ENV", "prod")
    if env not in _VALID_ENVS:
        parser.error(f"unknown env '{env}' (expected {', '.join(sorted(_VALID_ENVS))})")
    return items, env


def main() -> None:
    server_ids, env = _parse_args(sys.argv[1:])

    codex = shutil.which("codex")
    if not codex:
        print("register_codex_server.py: codex binary not found on PATH", file=sys.stderr)
        sys.exit(3)
    uv = shutil.which("uv")
    if not uv:
        print("register_codex_server.py: uv binary not found on PATH", file=sys.stderr)
        sys.exit(3)

    env_args = [
        "--env",
        f"MCP_GW_ENV={env}",
        "--env",
        f"MCP_GW_UNAVAILABLE_MODE={os.environ.get('MCP_GW_UNAVAILABLE_MODE', 'empty')}",
    ]
    for var in _PASSTHROUGH_ENV_VARS:
        value = os.environ.get(var)
        if value:
            env_args.extend(["--env", f"{var}={value}"])

    proxy = _proxy_executable(uv)
    expected_names = []
    for server_id in server_ids:
        name = _server_name(server_id, env)
        expected_names.append(name)
        cmd = [
            codex,
            "mcp",
            "add",
            name,
            *env_args,
            "--",
            *_proxy_command(server_id, uv, proxy),
        ]
        subprocess.run(cmd, check=True)

    listed = subprocess.run(
        [codex, "mcp", "list", "--json"],
        capture_output=True,
        text=True,
        check=False,
    )
    try:
        registered_names = {
            item["name"] for item in json.loads(listed.stdout) if isinstance(item, dict)
        }
    except (KeyError, TypeError, ValueError):
        registered_names = set()
    missing = [name for name in expected_names if name not in registered_names]
    if missing:
        print(
            "warning: these servers are not visible in 'codex mcp list --json': "
            + ", ".join(missing),
            file=sys.stderr,
        )
        sys.exit(5)

    print(
        f"ok: {len(expected_names)} server(s) registered for Codex against {env}: "
        + ", ".join(expected_names)
    )
    print(
        "\n  NEXT STEP: start a new Codex session so the new MCP server is "
        "loaded."
    )


if __name__ == "__main__":
    main()
