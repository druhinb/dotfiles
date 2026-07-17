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
"""Airtable CLI for Claude Code — read + write access to bases, tables, and records.

Authentication is handled automatically via the shared credential-broker
library. Tokens are cached in ``~/.cache/rbx-skills/airtable/token_cache.json``
and refreshed only when expired. Credentials are never printed to stdout.

Read commands::

    SKILL_DIR=".claude/skills/airtable"
    uv run $SKILL_DIR/scripts/airtable_cli.py bases
    uv run $SKILL_DIR/scripts/airtable_cli.py tables appXXXXXXXXXXXXX
    uv run $SKILL_DIR/scripts/airtable_cli.py records appXXXXXXXXXXXXX "My Table" --limit 10
    uv run $SKILL_DIR/scripts/airtable_cli.py record  appXXXXXXXXXXXXX "My Table" recXXXXXXXXXXXXX

Write commands (records)::

    # Create up to N records (auto-batched in groups of 10)
    uv run $SKILL_DIR/scripts/airtable_cli.py create-records appXXX "My Table" \\
        --records '[{"fields":{"Name":"Alice"}},{"fields":{"Name":"Bob"}}]'

    # Update (PATCH; preserves unspecified fields)
    uv run $SKILL_DIR/scripts/airtable_cli.py update-records appXXX "My Table" \\
        --records '[{"id":"recXXX","fields":{"Status":"Done"}}]'

    # Replace (PUT; clears unspecified fields)
    uv run $SKILL_DIR/scripts/airtable_cli.py replace-records appXXX "My Table" \\
        --records '[{"id":"recXXX","fields":{"Name":"Alice","Status":"Done"}}]'

    # Upsert by merge field(s)
    uv run $SKILL_DIR/scripts/airtable_cli.py upsert-records appXXX "My Table" \\
        --merge-on Email \\
        --records '[{"fields":{"Email":"a@x.com","Name":"Alice"}}]'

    # Delete (requires --yes; auto-batched)
    uv run $SKILL_DIR/scripts/airtable_cli.py delete-records appXXX "My Table" \\
        --record-ids recAAA recBBB --yes

Write commands (schema)::

    uv run $SKILL_DIR/scripts/airtable_cli.py create-base \\
        --workspace-id wspXXX --name "New Base" \\
        --tables '[{"name":"T1","fields":[{"name":"Name","type":"singleLineText"}]}]'

    uv run $SKILL_DIR/scripts/airtable_cli.py create-table appXXX \\
        --name "New Table" \\
        --fields '[{"name":"Name","type":"singleLineText"}]'

    uv run $SKILL_DIR/scripts/airtable_cli.py update-table appXXX tblXXX --name "Renamed"

    uv run $SKILL_DIR/scripts/airtable_cli.py create-field appXXX tblXXX \\
        --name "Status" --type singleSelect \\
        --options '{"choices":[{"name":"Todo"},{"name":"Done"}]}'

    uv run $SKILL_DIR/scripts/airtable_cli.py update-field appXXX tblXXX fldXXX --name "State"

All write commands support ``--dry-run`` (prints method, URL, and body without
sending). ``delete-records`` additionally requires ``--yes`` to execute.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path
from typing import Any
from urllib.parse import quote

import requests
from rbx_skills_auth import CredentialBrokerAuth

_API_ROOT = "https://api.airtable.com/v0"

_auth = CredentialBrokerAuth(
    service_name="airtable",
    display_name="Airtable",
    cache_dir=Path.home() / ".cache" / "rbx-skills" / "airtable",
    connect_url="https://apis.simulprod.com/credential-broker/v1/connect/airtable",
)

_BASE_ID_RE = re.compile(r"^app[A-Za-z0-9]{14,}$")
_TABLE_ID_RE = re.compile(r"^tbl[A-Za-z0-9]{14,}$")
_FIELD_ID_RE = re.compile(r"^fld[A-Za-z0-9]{14,}$")
_RECORD_ID_RE = re.compile(r"^rec[A-Za-z0-9]{14,}$")
_WORKSPACE_ID_RE = re.compile(r"^wsp[A-Za-z0-9]{14,}$")
_MAX_RATE_LIMIT_WAIT = 60
_RECORDS_PER_REQUEST = 10  # Airtable API hard cap for create/update/delete


def _id_validator(pattern: re.Pattern[str], expected: str):
    def _inner(value: str) -> str:
        if not pattern.match(value):
            raise argparse.ArgumentTypeError(
                f"invalid id {value!r} — expected format {expected}"
            )
        return value
    return _inner


_validated_base_id = _id_validator(_BASE_ID_RE, "appXXXXXXXXXXXXX")
_validated_table_id = _id_validator(_TABLE_ID_RE, "tblXXXXXXXXXXXXX")
_validated_field_id = _id_validator(_FIELD_ID_RE, "fldXXXXXXXXXXXXX")
_validated_record_id = _id_validator(_RECORD_ID_RE, "recXXXXXXXXXXXXX")
_validated_workspace_id = _id_validator(_WORKSPACE_ID_RE, "wspXXXXXXXXXXXXX")


class AirtableClient:
    """Thin wrapper around the Airtable REST API.

    Handles authentication automatically, retries once on auth errors,
    waits-and-retries on 429, and supports all HTTP methods.
    """

    def __init__(self) -> None:
        self._token: str | None = None

    def _ensure_auth(self, force: bool = False) -> None:
        self._token = _auth.get_token(force_refresh=force)["access_token"]

    def request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        body: Any = None,
    ) -> dict[str, Any]:
        """Send an authenticated request and return decoded JSON.

        ``path`` is relative to ``/v0`` (e.g. ``/appXXX/Table`` or ``/meta/bases``).
        Exits the process with a human-readable error on non-2xx responses.
        """
        if self._token is None:
            self._ensure_auth()

        url = _API_ROOT + path
        data, status = self._do_request(method, url, params, body)

        if status in (401, 403):
            self._ensure_auth(force=True)
            data, status = self._do_request(method, url, params, body)

        if status == 429:
            retry_after = min(int(data.get("Retry-After", 30)), _MAX_RATE_LIMIT_WAIT)
            print(f"Rate limited — waiting {retry_after}s...", file=sys.stderr)
            time.sleep(retry_after)
            data, status = self._do_request(method, url, params, body)

        if status >= 400:
            error = data.get("error", {}) if isinstance(data, dict) else {}
            msg = error.get("message", "") if isinstance(error, dict) else str(error)
            err_type = error.get("type", "UNKNOWN") if isinstance(error, dict) else "UNKNOWN"
            print(
                f"Error: Airtable API {err_type}: {msg} (HTTP {status})",
                file=sys.stderr,
            )
            sys.exit(1)

        return data

    def _do_request(
        self,
        method: str,
        url: str,
        params: dict[str, Any] | None,
        body: Any,
    ) -> tuple[dict[str, Any], int]:
        headers = {"Authorization": f"Bearer {self._token}"}
        if body is not None:
            headers["Content-Type"] = "application/json"

        try:
            response = requests.request(
                method,
                url,
                headers=headers,
                params=params,
                json=body,
                timeout=30,
            )
        except requests.RequestException as exc:
            print(f"Error: Request failed: {exc}", file=sys.stderr)
            sys.exit(1)

        if response.status_code == 429:
            return {"Retry-After": response.headers.get("Retry-After", "30")}, 429

        if response.status_code == 204 or not response.content:
            return {}, response.status_code

        try:
            data = response.json()
        except ValueError:
            print(
                f"Error: Non-JSON response (HTTP {response.status_code})",
                file=sys.stderr,
            )
            sys.exit(1)

        return data, response.status_code

    def paginate_records(
        self,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        max_results: int | None = None,
    ) -> list[dict[str, Any]]:
        base_params = dict(params or {})
        results: list[dict[str, Any]] = []

        while True:
            data = self.request("GET", path, params=base_params)
            results.extend(data.get("records", []))

            if max_results is not None and len(results) >= max_results:
                return results[:max_results]

            offset = data.get("offset")
            if not offset:
                return results

            base_params["offset"] = offset

    def paginate_bases(self) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        params: dict[str, Any] = {}

        while True:
            data = self.request("GET", "/meta/bases", params=params)
            results.extend(data.get("bases", []))

            offset = data.get("offset")
            if not offset:
                return results

            params["offset"] = offset


_client = AirtableClient()


def _print_json(data: Any) -> None:
    print(json.dumps(data, indent=2, default=str))


def _truncate(text: str, length: int = 120) -> str:
    text = str(text).replace("\n", " ").strip()
    if len(text) <= length:
        return text
    return text[: length - 3] + "..."


def _load_json_arg(inline: str | None, file_path: str | None, *, kind: str = "JSON") -> Any:
    """Load JSON from --records / --file / stdin (when file_path == '-')."""
    if inline and file_path:
        print("Error: pass --records or --file, not both", file=sys.stderr)
        sys.exit(1)

    if inline is not None:
        source = inline
    elif file_path == "-":
        source = sys.stdin.read()
    elif file_path:
        try:
            source = Path(file_path).read_text()
        except OSError as exc:
            print(f"Error: cannot read {file_path}: {exc}", file=sys.stderr)
            sys.exit(1)
    else:
        print(f"Error: must supply {kind} via --records or --file", file=sys.stderr)
        sys.exit(1)

    try:
        return json.loads(source)
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON: {exc}", file=sys.stderr)
        sys.exit(1)


def _chunks(items: list[Any], size: int) -> list[list[Any]]:
    return [items[i : i + size] for i in range(0, len(items), size)]


def _maybe_dry_run(method: str, path: str, body: Any, *, dry_run: bool) -> bool:
    """Print request details and return True if --dry-run was passed (caller should skip the call)."""
    if not dry_run:
        return False
    url = _API_ROOT + path
    print(f"[dry-run] {method} {url}", file=sys.stderr)
    if body is not None:
        print(json.dumps(body, indent=2))
    return True


def _records_path(base_id: str, table: str) -> str:
    return f"/{base_id}/{quote(table, safe='')}"


# ---------- read commands ----------


def cmd_bases(args: argparse.Namespace) -> None:
    bases = _client.paginate_bases()
    print(f"{len(bases)} base(s)\n", file=sys.stderr)
    for base in bases:
        print(f"[{base.get('id')}] {base.get('name', '?')}  ({base.get('permissionLevel', '?')})")


def cmd_tables(args: argparse.Namespace) -> None:
    data = _client.request("GET", f"/meta/bases/{args.base_id}/tables")
    tables = data.get("tables", [])
    print(f"{len(tables)} table(s)\n", file=sys.stderr)

    for table in tables:
        fields = [f.get("name", "?") for f in table.get("fields", [])]
        views = [v.get("name", "?") for v in table.get("views", [])]
        fields_str = ", ".join(fields[:10])
        if len(fields) > 10:
            fields_str += f", ... (+{len(fields) - 10})"
        views_str = ", ".join(views[:5])
        if len(views) > 5:
            views_str += f", ... (+{len(views) - 5})"
        print(f"[{table.get('id', '?')}] {table.get('name', '?')}")
        print(f"  Fields: {fields_str}")
        print(f"  Views: {views_str}")
        print()


def cmd_records(args: argparse.Namespace) -> None:
    params: dict[str, Any] = {}
    if args.view:
        params["view"] = args.view
    if args.formula:
        params["filterByFormula"] = args.formula
    if args.sort:
        params["sort[0][field]"] = args.sort
        params["sort[0][direction]"] = args.direction or "asc"
    if args.fields:
        for i, field in enumerate(args.fields):
            params[f"fields[{i}]"] = field
    if args.limit:
        params["pageSize"] = min(args.limit, 100)

    records = _client.paginate_records(
        _records_path(args.base_id, args.table),
        params=params,
        max_results=args.limit,
    )
    print(f"{len(records)} record(s)\n", file=sys.stderr)

    for rec in records:
        fields = rec.get("fields", {})
        summary = " | ".join(
            f"{k}: {_truncate(str(v), 60)}" for k, v in list(fields.items())[:5]
        )
        print(f"[{rec.get('id', '?')}] {summary}")


def cmd_record(args: argparse.Namespace) -> None:
    path = f"{_records_path(args.base_id, args.table)}/{args.record_id}"
    _print_json(_client.request("GET", path))


# ---------- write commands (records) ----------


def _write_records_batched(
    method: str,
    base_id: str,
    table: str,
    records: list[dict[str, Any]],
    *,
    dry_run: bool,
    extra_body: dict[str, Any] | None = None,
) -> None:
    if not isinstance(records, list) or not records:
        print("Error: --records must be a non-empty JSON array", file=sys.stderr)
        sys.exit(1)

    path = _records_path(base_id, table)
    all_results: list[dict[str, Any]] = []

    for batch in _chunks(records, _RECORDS_PER_REQUEST):
        body: dict[str, Any] = {"records": batch}
        if extra_body:
            body.update(extra_body)

        if _maybe_dry_run(method, path, body, dry_run=dry_run):
            continue

        data = _client.request(method, path, body=body)
        all_results.extend(data.get("records", []))

    if not dry_run:
        print(f"{len(all_results)} record(s) written\n", file=sys.stderr)
        _print_json({"records": all_results})


def cmd_create_records(args: argparse.Namespace) -> None:
    records = _load_json_arg(args.records, args.file)
    _write_records_batched("POST", args.base_id, args.table, records, dry_run=args.dry_run)


def cmd_update_records(args: argparse.Namespace) -> None:
    records = _load_json_arg(args.records, args.file)
    _write_records_batched("PATCH", args.base_id, args.table, records, dry_run=args.dry_run)


def cmd_replace_records(args: argparse.Namespace) -> None:
    records = _load_json_arg(args.records, args.file)
    _write_records_batched("PUT", args.base_id, args.table, records, dry_run=args.dry_run)


def cmd_upsert_records(args: argparse.Namespace) -> None:
    records = _load_json_arg(args.records, args.file)
    extra = {
        "performUpsert": {"fieldsToMergeOn": args.merge_on},
        "typecast": bool(args.typecast),
    }
    _write_records_batched(
        "PATCH", args.base_id, args.table, records,
        dry_run=args.dry_run, extra_body=extra,
    )


def cmd_delete_records(args: argparse.Namespace) -> None:
    if not args.dry_run and not args.yes:
        print("Error: delete-records requires --yes (or --dry-run to preview)", file=sys.stderr)
        sys.exit(1)

    path = _records_path(args.base_id, args.table)
    deleted: list[str] = []

    for batch in _chunks(args.record_ids, _RECORDS_PER_REQUEST):
        params = [("records[]", rid) for rid in batch]

        if args.dry_run:
            url = _API_ROOT + path
            qs = "&".join(f"records%5B%5D={rid}" for rid in batch)
            print(f"[dry-run] DELETE {url}?{qs}", file=sys.stderr)
            continue

        data = _client.request("DELETE", path, params=params)
        deleted.extend(r.get("id") for r in data.get("records", []) if r.get("deleted"))

    if not args.dry_run:
        print(f"{len(deleted)} record(s) deleted", file=sys.stderr)
        _print_json({"deleted": deleted})


# ---------- write commands (schema) ----------


def cmd_create_base(args: argparse.Namespace) -> None:
    tables = _load_json_arg(args.tables, args.tables_file, kind="tables JSON")
    body = {
        "name": args.name,
        "workspaceId": args.workspace_id,
        "tables": tables,
    }
    if _maybe_dry_run("POST", "/meta/bases", body, dry_run=args.dry_run):
        return
    _print_json(_client.request("POST", "/meta/bases", body=body))


def cmd_create_table(args: argparse.Namespace) -> None:
    fields = _load_json_arg(args.fields, args.fields_file, kind="fields JSON")
    body: dict[str, Any] = {"name": args.name, "fields": fields}
    if args.description:
        body["description"] = args.description

    path = f"/meta/bases/{args.base_id}/tables"
    if _maybe_dry_run("POST", path, body, dry_run=args.dry_run):
        return
    _print_json(_client.request("POST", path, body=body))


def cmd_update_table(args: argparse.Namespace) -> None:
    body: dict[str, Any] = {}
    if args.name:
        body["name"] = args.name
    if args.description is not None:
        body["description"] = args.description
    if not body:
        print("Error: provide at least one of --name / --description", file=sys.stderr)
        sys.exit(1)

    path = f"/meta/bases/{args.base_id}/tables/{args.table_id}"
    if _maybe_dry_run("PATCH", path, body, dry_run=args.dry_run):
        return
    _print_json(_client.request("PATCH", path, body=body))


def cmd_create_field(args: argparse.Namespace) -> None:
    body: dict[str, Any] = {"name": args.name, "type": args.type}
    if args.description:
        body["description"] = args.description
    if args.options:
        body["options"] = _load_json_arg(args.options, None, kind="options JSON")

    path = f"/meta/bases/{args.base_id}/tables/{args.table_id}/fields"
    if _maybe_dry_run("POST", path, body, dry_run=args.dry_run):
        return
    _print_json(_client.request("POST", path, body=body))


def cmd_update_field(args: argparse.Namespace) -> None:
    body: dict[str, Any] = {}
    if args.name:
        body["name"] = args.name
    if args.description is not None:
        body["description"] = args.description
    if not body:
        print("Error: provide at least one of --name / --description", file=sys.stderr)
        sys.exit(1)

    path = f"/meta/bases/{args.base_id}/tables/{args.table_id}/fields/{args.field_id}"
    if _maybe_dry_run("PATCH", path, body, dry_run=args.dry_run):
        return
    _print_json(_client.request("PATCH", path, body=body))


# ---------- argument parsing ----------


def _add_records_arg(p: argparse.ArgumentParser) -> None:
    p.add_argument("--records", help="Inline JSON array of records.")
    p.add_argument("--file", help="Path to JSON file (or '-' for stdin).")
    p.add_argument("--dry-run", action="store_true", help="Print request without sending.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="airtable_cli.py",
        description="Airtable CLI for Claude Code (read + write).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="command", metavar="COMMAND")

    sub.add_parser("bases", help="List all accessible bases")

    p = sub.add_parser("tables", help="List tables in a base")
    p.add_argument("base_id", type=_validated_base_id)

    p = sub.add_parser("records", help="List records from a table")
    p.add_argument("base_id", type=_validated_base_id)
    p.add_argument("table", help="Table name or ID (case-sensitive)")
    p.add_argument("--limit", type=int, default=100, help="Max records (default 100)")
    p.add_argument("--view", metavar="NAME", help="Use this Airtable view")
    p.add_argument("--formula", metavar="FORMULA", help="filterByFormula expression")
    p.add_argument("--sort", metavar="FIELD", help="Field to sort by")
    p.add_argument("--direction", choices=["asc", "desc"], default="asc")
    p.add_argument("--fields", nargs="+", metavar="FIELD", help="Only return these fields")

    p = sub.add_parser("record", help="Get a single record")
    p.add_argument("base_id", type=_validated_base_id)
    p.add_argument("table", help="Table name or ID")
    p.add_argument("record_id", type=_validated_record_id)

    for name, help_text in [
        ("create-records", "Create records (POST, auto-batched in 10s)"),
        ("update-records", "Patch records (preserves unspecified fields)"),
        ("replace-records", "Replace records (PUT; clears unspecified fields)"),
    ]:
        p = sub.add_parser(name, help=help_text)
        p.add_argument("base_id", type=_validated_base_id)
        p.add_argument("table", help="Table name or ID")
        _add_records_arg(p)

    p = sub.add_parser("upsert-records", help="Upsert records by merge field(s)")
    p.add_argument("base_id", type=_validated_base_id)
    p.add_argument("table", help="Table name or ID")
    p.add_argument("--merge-on", nargs="+", required=True, metavar="FIELD",
                   help="Field name(s) to match for upsert")
    p.add_argument("--typecast", action="store_true",
                   help="Allow Airtable to coerce types automatically")
    _add_records_arg(p)

    p = sub.add_parser("delete-records", help="Delete records by ID (auto-batched)")
    p.add_argument("base_id", type=_validated_base_id)
    p.add_argument("table", help="Table name or ID")
    p.add_argument("--record-ids", nargs="+", required=True, type=_validated_record_id,
                   metavar="ID", help="One or more record IDs (recXXX)")
    p.add_argument("--yes", action="store_true", help="Confirm destructive deletion")
    p.add_argument("--dry-run", action="store_true", help="Print request without sending")

    p = sub.add_parser("create-base", help="Create a new base in a workspace")
    p.add_argument("--workspace-id", required=True, type=_validated_workspace_id)
    p.add_argument("--name", required=True)
    p.add_argument("--tables", help="Inline JSON array of table specs")
    p.add_argument("--tables-file", help="Path to JSON file (or '-' for stdin)")
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("create-table", help="Create a table in a base")
    p.add_argument("base_id", type=_validated_base_id)
    p.add_argument("--name", required=True)
    p.add_argument("--description")
    p.add_argument("--fields", help="Inline JSON array of field specs")
    p.add_argument("--fields-file", help="Path to JSON file (or '-' for stdin)")
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("update-table", help="Rename or re-describe a table")
    p.add_argument("base_id", type=_validated_base_id)
    p.add_argument("table_id", type=_validated_table_id)
    p.add_argument("--name")
    p.add_argument("--description")
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("create-field", help="Add a field to a table")
    p.add_argument("base_id", type=_validated_base_id)
    p.add_argument("table_id", type=_validated_table_id)
    p.add_argument("--name", required=True)
    p.add_argument("--type", required=True,
                   help="Airtable field type (e.g. singleLineText, number, singleSelect)")
    p.add_argument("--description")
    p.add_argument("--options", help="Inline JSON for type-specific options")
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("update-field", help="Rename or re-describe a field")
    p.add_argument("base_id", type=_validated_base_id)
    p.add_argument("table_id", type=_validated_table_id)
    p.add_argument("field_id", type=_validated_field_id)
    p.add_argument("--name")
    p.add_argument("--description")
    p.add_argument("--dry-run", action="store_true")

    return parser


_COMMAND_HANDLERS = {
    "bases": cmd_bases,
    "tables": cmd_tables,
    "records": cmd_records,
    "record": cmd_record,
    "create-records": cmd_create_records,
    "update-records": cmd_update_records,
    "replace-records": cmd_replace_records,
    "upsert-records": cmd_upsert_records,
    "delete-records": cmd_delete_records,
    "create-base": cmd_create_base,
    "create-table": cmd_create_table,
    "update-table": cmd_update_table,
    "create-field": cmd_create_field,
    "update-field": cmd_update_field,
}


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    handler = _COMMAND_HANDLERS.get(args.command)
    if handler is None:
        parser.print_help()
        sys.exit(1)

    handler(args)


if __name__ == "__main__":
    main()
