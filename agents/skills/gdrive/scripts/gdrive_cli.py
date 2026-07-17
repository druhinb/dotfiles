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
Google Drive CLI for Claude Code — gdrive skill.

Auth is handled automatically via the credential broker.
Tokens are cached in ~/.cache/gdrive/token_cache.json.

Usage examples:
    # Search by name keyword (searches across all drives)
    uv run gdrive_cli.py search "agent gateway"
    uv run gdrive_cli.py search "design doc" --limit 5

    # Get file metadata (by ID or URL)
    uv run gdrive_cli.py get FILE_ID
    uv run gdrive_cli.py get --url "https://docs.google.com/document/d/FILE_ID/edit"

    # Export a Google Doc/Sheet/Slides as plain text
    uv run gdrive_cli.py export FILE_ID
    uv run gdrive_cli.py export --url "https://docs.google.com/document/d/FILE_ID/edit"
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import requests
from rbx_skills_auth import CredentialBrokerAuth

# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

_auth = CredentialBrokerAuth(
    service_name="google_workspace",
    display_name="Google Drive",
    cache_dir=Path.home() / ".cache" / "gdrive",
    connect_url="https://apis.simulprod.com/credential-broker/v1/connect/google_workspace",
)

_DRIVE_BASE = "https://www.googleapis.com/drive/v3"

_GDOC_EXPORT_TYPES = {
    "application/vnd.google-apps.document": "text/plain",
    "application/vnd.google-apps.spreadsheet": "text/csv",
    "application/vnd.google-apps.presentation": "text/plain",
}


def _token(force: bool = False) -> str:
    return _auth.get_token(force_refresh=force)["access_token"]


def _get(path: str, *, params: dict | None = None, force_refresh: bool = False) -> requests.Response:
    # Files that live in a Shared Drive return 404 from files.get / files.export
    # unless supportsAllDrives is set. It's a no-op for My Drive files, so apply it
    # to every request. A caller-supplied value (e.g. search) still takes precedence.
    params = {"supportsAllDrives": "true", **(params or {})}
    tok = _token(force_refresh)
    # supportsAllDrives=true is a no-op for files in My Drive but is required
    # for any file that lives in a shared drive — without it, get/export 404
    # even when the user clearly has access.
    merged = {"supportsAllDrives": "true", **(params or {})}
    resp = requests.get(
        _DRIVE_BASE + path,
        headers={"Authorization": f"Bearer {tok}"},
        params=merged,
        timeout=30,
    )
    if resp.status_code == 401 and not force_refresh:
        return _get(path, params=params, force_refresh=True)
    return resp


def _handle_error(resp: requests.Response) -> None:
    try:
        msg = resp.json().get("error", {}).get("message", resp.text[:300])
    except Exception:
        msg = resp.text[:300]
    print(f"Error ({resp.status_code}): {msg}", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# URL helpers
# ---------------------------------------------------------------------------

def _file_id_from_url(url: str) -> str:
    """Extract file ID from a Google Drive or Docs/Sheets/Slides URL."""
    m = re.search(r"/(?:d|folders)/([a-zA-Z0-9_-]{20,})", url)
    if not m:
        print(f"Error: could not extract file ID from URL: {url}", file=sys.stderr)
        sys.exit(1)
    return m.group(1)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_search(query: str, limit: int) -> None:
    q = f"name contains '{query}' and trashed = false"
    params = {
        "q": q,
        "fields": "files(id,name,mimeType,modifiedTime,webViewLink)",
        "pageSize": min(limit, 100),
        "orderBy": "modifiedTime desc",
        "corpora": "allDrives",
        "includeItemsFromAllDrives": "true",
        "supportsAllDrives": "true",
    }
    resp = _get("/files", params=params)
    if not resp.ok:
        _handle_error(resp)

    files = resp.json().get("files", [])
    print(f"Results ({len(files)}):\n")
    for f in files[:limit]:
        mime = f.get("mimeType", "")
        kind = mime.split(".")[-1] if "google-apps" in mime else mime.split("/")[-1]
        modified = f.get("modifiedTime", "")[:10]
        print(f"  [{f['id']}] {f['name']}  ({kind}, {modified})")
        if f.get("webViewLink"):
            print(f"    {f['webViewLink']}")
        print()


def cmd_get(file_id: str) -> None:
    params = {"fields": "id,name,mimeType,size,modifiedTime,webViewLink,owners"}
    resp = _get(f"/files/{file_id}", params=params)
    if not resp.ok:
        _handle_error(resp)

    f = resp.json()
    mime = f.get("mimeType", "")
    kind = mime.split(".")[-1] if "google-apps" in mime else mime
    owners = ", ".join(o.get("displayName", "") for o in f.get("owners", []))
    print(f"ID:       {f['id']}")
    print(f"Name:     {f['name']}")
    print(f"Type:     {kind}")
    print(f"Modified: {f.get('modifiedTime', '')[:10]}")
    if owners:
        print(f"Owners:   {owners}")
    if f.get("size"):
        print(f"Size:     {f['size']} bytes")
    if f.get("webViewLink"):
        print(f"URL:      {f['webViewLink']}")
    if mime in _GDOC_EXPORT_TYPES:
        print(f"\nTip: run `export {f['id']}` to read the contents.")


def cmd_export(file_id: str) -> None:
    # Determine MIME type first
    meta_resp = _get(f"/files/{file_id}", params={"fields": "mimeType,name"})
    if not meta_resp.ok:
        _handle_error(meta_resp)
    meta = meta_resp.json()
    mime = meta.get("mimeType", "")

    if mime in _GDOC_EXPORT_TYPES:
        export_mime = _GDOC_EXPORT_TYPES[mime]
        resp = _get(f"/files/{file_id}/export", params={"mimeType": export_mime})
    else:
        # Binary / plain file — download directly (with 401 retry like _get)
        resp = _get(f"/files/{file_id}", params={"alt": "media"})

    if not resp.ok:
        _handle_error(resp)

    print(resp.text)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _resolve_id(args: argparse.Namespace) -> str:
    if hasattr(args, "url") and args.url:
        return _file_id_from_url(args.url)
    if args.file_id:
        return args.file_id
    print("Error: provide a file_id or --url", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Google Drive CLI — gdrive skill",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="command", metavar="COMMAND")

    # search
    p = sub.add_parser("search", help="Search files by name keyword")
    p.add_argument("query", help="Keyword to search for in file names")
    p.add_argument("--limit", "-l", type=int, default=20)

    # get
    p = sub.add_parser("get", help="Get file metadata by ID or URL")
    p.add_argument("file_id", nargs="?", help="Google Drive file ID")
    p.add_argument("--url", "-u", help="Google Drive/Docs/Sheets URL")

    # export
    p = sub.add_parser("export", help="Print file contents (exports Google Docs as text)")
    p.add_argument("file_id", nargs="?", help="Google Drive file ID")
    p.add_argument("--url", "-u", help="Google Drive/Docs/Sheets URL")

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    if args.command == "search":
        cmd_search(args.query, args.limit)
    elif args.command == "get":
        cmd_get(_resolve_id(args))
    elif args.command == "export":
        cmd_export(_resolve_id(args))


if __name__ == "__main__":
    main()
