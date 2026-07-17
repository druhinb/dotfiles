# /// script
# requires-python = ">=3.10"
# dependencies = ["requests", "rbx-skills-auth"]
#
# [tool.uv]
# upgrade-package = ["rbx-skills-auth"]
#
# [[tool.uv.index]]
# url = "https://artifactory.rbx.com/api/pypi/pypi-all/simple"
# default = true
# ///
"""
Confluence CLI for Claude Code — Atlassian skill.

Uses the Confluence REST API v2 (at /wiki/api/v2/...).
Authentication is handled automatically via the credential broker.
Tokens are cached in ~/.cache/atlassian/token_cache.json and refreshed
only when expired. Credentials are never printed to stdout.

Usage examples:
    # List spaces
    uv run confluence_cli.py spaces

    # Get a space by ID or key
    uv run confluence_cli.py space ENG
    uv run confluence_cli.py space 262174

    # List pages in a space
    uv run confluence_cli.py pages --space ENG
    uv run confluence_cli.py pages --space ENG --title "Getting Started"

    # Get a page by ID
    uv run confluence_cli.py get 12345678

    # Create a page
    uv run confluence_cli.py create --space ENG --title "New Page" \\
        --body "<p>Page content here.</p>"
    uv run confluence_cli.py create --space ENG --title "Child Page" \\
        --body "<p>Content</p>" --parent 12345678

    # Update a page
    uv run confluence_cli.py update 12345678 --title "Updated Title"
    uv run confluence_cli.py update 12345678 --body "<p>New content</p>"

    # Get child pages
    uv run confluence_cli.py children 12345678

    # Manage labels
    uv run confluence_cli.py labels 12345678
    uv run confluence_cli.py labels 12345678 --add my-label
    uv run confluence_cli.py labels 12345678 --remove my-label
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

import requests

# ---------------------------------------------------------------------------
# Bootstrap: make auth module importable from the same directory
# ---------------------------------------------------------------------------
sys.path.insert(0, str(Path(__file__).parent))
from auth import get_credentials  # noqa: E402

# ---------------------------------------------------------------------------
# Confluence v2 API client
# ---------------------------------------------------------------------------

CONFLUENCE_BASE = "https://api.atlassian.com/ex/confluence/{cloud_id}/wiki/api/v2"


class ConfluenceClient:
    """Thin wrapper around the Confluence REST API v2 with automatic token refresh."""

    def __init__(self) -> None:
        self._token: str | None = None
        self._cloud_id: str | None = None

    def _ensure_auth(self, force: bool = False) -> None:
        self._token, self._cloud_id = get_credentials(force_refresh=force)

    def _base(self) -> str:
        return CONFLUENCE_BASE.format(cloud_id=self._cloud_id)

    def request(
        self,
        method: str,
        path: str,
        *,
        params: dict | None = None,
        body: dict | list | None = None,
    ) -> requests.Response:
        """
        Make an authenticated request. Retries once on 401.

        path: relative to /ex/confluence/{cloud_id}/wiki/api/v2
        """
        if self._token is None:
            self._ensure_auth()

        headers: dict[str, str] = {
            "Authorization": f"Bearer {self._token}",
            "Accept": "application/json",
        }
        if body is not None:
            headers["Content-Type"] = "application/json"

        url = self._base() + path
        resp = requests.request(
            method,
            url,
            headers=headers,
            params=params,
            json=body,
            timeout=30,
        )

        if resp.status_code == 401:
            self._ensure_auth(force=True)
            headers["Authorization"] = f"Bearer {self._token}"
            url = self._base() + path
            resp = requests.request(
                method,
                url,
                headers=headers,
                params=params,
                json=body,
                timeout=30,
            )

        return resp

    def call(
        self,
        method: str,
        path: str,
        *,
        params: dict | None = None,
        body: dict | list | None = None,
        allow_empty: bool = False,
    ) -> dict | list:
        """request() + error handling + JSON decode."""
        resp = self.request(method, path, params=params, body=body)

        if resp.status_code == 204 or (allow_empty and not resp.content):
            return {}

        if not resp.ok:
            _print_confluence_error(resp)
            sys.exit(1)

        return resp.json()

    def paginate(self, path: str, *, params: dict | None = None, limit: int = 250) -> list[dict]:
        """
        Follow Confluence v2 cursor-based pagination and return all results.

        Stops after `limit` total results to avoid runaway requests.
        """
        results: list[dict] = []
        p = dict(params or {})
        p.setdefault("limit", min(50, limit))

        while True:
            data = self.call("GET", path, params=p)
            assert isinstance(data, dict)
            batch = data.get("results", [])
            results.extend(batch)

            if len(results) >= limit:
                break

            next_link = (data.get("_links") or {}).get("next")
            if not next_link:
                break

            # Extract cursor from next link, e.g. "?cursor=abc&limit=50"
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(next_link).query)
            cursor = qs.get("cursor", [None])[0]
            if not cursor:
                break
            p["cursor"] = cursor

        return results[:limit]


_client = ConfluenceClient()


def _print_confluence_error(resp: requests.Response) -> None:
    """Print a human-readable Confluence error to stderr."""
    try:
        data = resp.json()
        msg = (
            data.get("message")
            or data.get("detail")
            or str(data)[:400]
        )
    except Exception:
        msg = resp.text[:400]
    print(f"Error ({resp.status_code}): {msg}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Space key → ID resolution
# ---------------------------------------------------------------------------


def _resolve_space(space_ref: str) -> dict:
    """
    Return the space object for a space key or numeric ID.

    Fetches /spaces?keys=KEY for alpha keys, /spaces/ID for numeric IDs.
    """
    if space_ref.isdigit():
        data = _client.call("GET", f"/spaces/{space_ref}")
        assert isinstance(data, dict)
        return data

    data = _client.call("GET", "/spaces", params={"keys": space_ref, "limit": 1})
    assert isinstance(data, dict)
    results = data.get("results", [])
    if not results:
        print(f"Error: Space '{space_ref}' not found.", file=sys.stderr)
        sys.exit(1)
    return results[0]


# ---------------------------------------------------------------------------
# Command implementations
# ---------------------------------------------------------------------------


def cmd_spaces(limit: int, space_type: str | None) -> None:
    params: dict = {"limit": min(limit, 250), "sort": "name"}
    if space_type:
        params["type"] = space_type

    results = _client.paginate("/spaces", params=params, limit=limit)
    print(f"Spaces ({len(results)}):\n")
    for s in results:
        print(f"  [{s['key']}] {s['name']}  (id={s['id']}, type={s.get('type', '?')})")


def cmd_space(space_ref: str) -> None:
    space = _resolve_space(space_ref)
    print(f"ID:       {space['id']}")
    print(f"Key:      {space['key']}")
    print(f"Name:     {space['name']}")
    print(f"Type:     {space.get('type', '?')}")
    print(f"Status:   {space.get('status', '?')}")
    homepage = space.get("homepageId")
    if homepage:
        print(f"Homepage: {homepage}")


def cmd_pages(
    space_ref: str | None,
    title: str | None,
    sort: str,
    limit: int,
    body_format: str,
) -> None:
    params: dict = {"sort": sort}
    if body_format:
        params["body-format"] = body_format

    if space_ref:
        space = _resolve_space(space_ref)
        params["space-id"] = space["id"]
    if title:
        params["title"] = title

    results = _client.paginate("/pages", params=params, limit=limit)
    print(f"Pages ({len(results)}):\n")
    for page in results:
        links = page.get("_links", {})
        web = links.get("webui", "")
        base = links.get("base", "")
        url = (base + web) if web else ""
        print(f"  [{page['id']}] {page['title']}")
        if url:
            print(f"    URL: {url}")
        if body_format and page.get("body"):
            body_val = (page["body"].get(body_format) or {}).get("value", "")
            if body_val:
                snippet = body_val[:200].replace("\n", " ")
                print(f"    Preview: {snippet}…" if len(body_val) > 200 else f"    Body: {body_val}")
        print()


def cmd_get(page_id: str, body_format: str) -> None:
    params = {
        "body-format": body_format,
        "include-labels": "true",
        "include-versions": "true",
    }
    data = _client.call("GET", f"/pages/{page_id}", params=params)
    assert isinstance(data, dict)

    links = data.get("_links", {})
    web = links.get("webui", "")
    base = links.get("base", "")

    print(f"ID:      {data['id']}")
    print(f"Title:   {data['title']}")
    print(f"Status:  {data.get('status', '?')}")
    version_info = data.get("version") or {}
    print(f"Version: {version_info.get('number', '?')}")
    if web:
        print(f"URL:     {base + web}")

    labels = [lbl.get("name", "") for lbl in (data.get("labels") or {}).get("results", [])]
    if labels:
        print(f"Labels:  {', '.join(labels)}")

    body_obj = data.get("body") or {}
    body_data = body_obj.get(body_format) or {}
    body_val = body_data.get("value", "")
    if body_val:
        print(f"\n--- Content ({body_format}) ---")
        print(body_val)


def cmd_create(
    space_ref: str,
    title: str,
    body: str,
    parent_id: str | None,
) -> None:
    space = _resolve_space(space_ref)

    payload: dict[str, Any] = {
        "spaceId": space["id"],
        "status": "current",
        "title": title,
        "body": {
            "representation": "storage",
            "value": body,
        },
    }
    if parent_id:
        payload["parentId"] = parent_id

    data = _client.call("POST", "/pages", body=payload)
    assert isinstance(data, dict)
    links = data.get("_links", {})
    web = links.get("webui", "")
    base = links.get("base", "")
    print(f"Created: {data['title']}")
    print(f"ID:      {data['id']}")
    if web:
        print(f"URL:     {base + web}")


def cmd_update(page_id: str, title: str | None, body: str | None) -> None:
    # Fetch current version and title to build the update payload
    current = _client.call(
        "GET",
        f"/pages/{page_id}",
        params={"include-versions": "true"},
    )
    assert isinstance(current, dict)

    version_info = current.get("version") or {}
    current_version = version_info.get("number", 1)
    current_title = current.get("title", "")

    payload: dict[str, Any] = {
        "id": page_id,
        "status": "current",
        "title": title if title is not None else current_title,
        "version": {"number": current_version + 1},
    }

    if body is not None:
        payload["body"] = {
            "representation": "storage",
            "value": body,
        }
    else:
        # Body is required in PUT even if unchanged — fetch it
        with_body = _client.call(
            "GET",
            f"/pages/{page_id}",
            params={"body-format": "storage"},
        )
        assert isinstance(with_body, dict)
        existing_body = ((with_body.get("body") or {}).get("storage") or {}).get("value", "")
        payload["body"] = {
            "representation": "storage",
            "value": existing_body,
        }

    data = _client.call("PUT", f"/pages/{page_id}", body=payload)
    assert isinstance(data, dict)
    links = data.get("_links", {})
    web = links.get("webui", "")
    base = links.get("base", "")
    version_out = (data.get("version") or {}).get("number", "?")
    print(f"Updated: {data['title']}")
    print(f"Version: {version_out}")
    if web:
        print(f"URL:     {base + web}")


def cmd_children(page_id: str, limit: int) -> None:
    results = _client.paginate(f"/pages/{page_id}/children", limit=limit)
    print(f"Child pages of {page_id} ({len(results)}):\n")
    for page in results:
        links = page.get("_links", {})
        web = links.get("webui", "")
        base = links.get("base", "")
        print(f"  [{page['id']}] {page['title']}")
        if web:
            print(f"    URL: {base + web}")
        print()


def cmd_labels(page_id: str, add: str | None, remove: str | None) -> None:
    if add:
        _client.call(
            "POST",
            f"/pages/{page_id}/labels",
            body=[{"name": add, "prefix": "global"}],
        )
        print(f"Added label '{add}' to page {page_id}")
    elif remove:
        _client.call(
            "DELETE",
            f"/pages/{page_id}/labels/{remove}",
            allow_empty=True,
        )
        print(f"Removed label '{remove}' from page {page_id}")
    else:
        data = _client.call("GET", f"/pages/{page_id}/labels")
        assert isinstance(data, dict)
        labels = data.get("results", [])
        print(f"Labels on page {page_id}:")
        for lbl in labels:
            print(f"  - {lbl['name']}")
        if not labels:
            print("  (none)")


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Confluence CLI (v2 API) — Atlassian skill",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="command", metavar="COMMAND")

    # --- spaces ---
    p = sub.add_parser("spaces", help="List Confluence spaces")
    p.add_argument("--limit", "-l", type=int, default=50)
    p.add_argument("--type", dest="space_type", choices=["global", "personal"])

    # --- space ---
    p = sub.add_parser("space", help="Get details for a single space")
    p.add_argument(
        "space_ref",
        help="Space key (e.g. ENG) or numeric space ID",
    )

    # --- pages ---
    p = sub.add_parser("pages", help="List or filter pages")
    p.add_argument("--space", "-s", dest="space_ref", help="Space key or ID")
    p.add_argument("--title", "-t", help="Exact title match")
    p.add_argument("--sort", default="-modified-date",
                   choices=["id", "-id", "title", "-title",
                            "created-date", "-created-date",
                            "modified-date", "-modified-date"])
    p.add_argument("--limit", "-l", type=int, default=25)
    p.add_argument("--body-format", default="",
                   choices=["", "storage", "atlas_doc_format", "view"],
                   help="Include page body in response (empty = no body)")

    # --- get ---
    p = sub.add_parser("get", help="Get a page by ID")
    p.add_argument("page_id", help="Numeric page ID")
    p.add_argument(
        "--body-format", default="storage",
        choices=["storage", "atlas_doc_format", "view"],
    )

    # --- create ---
    p = sub.add_parser("create", help="Create a new page")
    p.add_argument("--space", "-s", dest="space_ref", required=True,
                   help="Space key or ID")
    p.add_argument("--title", "-t", required=True)
    p.add_argument("--body", "-b", required=True,
                   help="Page body in HTML storage format")
    p.add_argument("--parent", "-p", dest="parent_id",
                   help="Parent page ID")

    # --- update ---
    p = sub.add_parser("update", help="Update an existing page")
    p.add_argument("page_id", help="Numeric page ID")
    p.add_argument("--title", "-t", help="New title")
    p.add_argument("--body", "-b", help="New body (HTML storage format)")

    # --- children ---
    p = sub.add_parser("children", help="List child pages")
    p.add_argument("page_id")
    p.add_argument("--limit", "-l", type=int, default=50)

    # --- labels ---
    p = sub.add_parser("labels", help="List, add, or remove page labels")
    p.add_argument("page_id")
    p.add_argument("--add", "-a", help="Label to add")
    p.add_argument("--remove", "-r", help="Label to remove")

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    if args.command == "spaces":
        cmd_spaces(args.limit, args.space_type)
    elif args.command == "space":
        cmd_space(args.space_ref)
    elif args.command == "pages":
        cmd_pages(
            space_ref=args.space_ref,
            title=args.title,
            sort=args.sort,
            limit=args.limit,
            body_format=args.body_format,
        )
    elif args.command == "get":
        cmd_get(args.page_id, args.body_format)
    elif args.command == "create":
        cmd_create(
            space_ref=args.space_ref,
            title=args.title,
            body=args.body,
            parent_id=args.parent_id,
        )
    elif args.command == "update":
        cmd_update(args.page_id, title=args.title, body=args.body)
    elif args.command == "children":
        cmd_children(args.page_id, args.limit)
    elif args.command == "labels":
        cmd_labels(args.page_id, add=args.add, remove=args.remove)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
