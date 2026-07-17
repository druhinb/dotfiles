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
"""Portal Insights API for Claude Code"""
import argparse
import json
import sys
from pathlib import Path
from typing import Any, Optional

sys.path.insert(0, str(Path(__file__).parent))
from portal_client import make_auth, get_token, api_request as _api_request, resolve_ros_id

_cb_auth = make_auth()

INSIGHTS_BASE_URL = "https://apis.simulprod.com/portal-ui-service/v1/insights"

NAMED_QUERIES = {
    "unassigned-bugs": "Open, unassigned bugs",
    "untriaged-bugs": "Bugs with status Submitted",
    "p0-bugs": "Open bugs with priority P0",
    "p1-bugs": "Open bugs with priority P1",
    "p2-bugs": "Open bugs with priority P2",
    "p3-bugs": "Open bugs with priority P3",
    "p4-bugs": "Open bugs with priority P4",
    "dfb-p0": "Open DFB issues at P0 (label: DFB-DoNotRemove, excludes DFBTEST)",
    "dfb-p1": "Open DFB issues at P1",
    "dfb-p2": "Open DFB issues at P2",
    "dfb-p3": "Open DFB issues at P3",
    "dfb-p4": "Open DFB issues at P4",
    "flaky-tests": "Issues labeled excludedTest, not TestsQuarantined, not closed/verified",
    "tests-excluded": "Same filter as flaky-tests",
    "vulnerability": "Open issues labeled vulnerability",
    "campaign-test": "Open issues labeled Campaign-RBXASSERT",
    "campaign-rbxassert": "Open issues labeled RbxAssert",
    "campaign-metriccleanup": "Open issues labeled metriccleanup",
    "campaign-dmct": "Open issues labeled dmct-conversion",
    "stale-flags-60": "Boolean fast flags not flipped in 60+ days",
    "stale-flags-180": "Boolean fast flags not flipped in 180+ days",
    "stale-flags-1year": "Boolean fast flags not flipped in 1+ year",
    "dfb-bugs": "[composite] dfb-p0, dfb-p1, dfb-p2, dfb-p3, dfb-p4",
    "priority-bugs": "[composite] p0-bugs, p1-bugs, p2-bugs, p3-bugs, p4-bugs",
    "flaky-test-unassigned-bugs": "[composite] flaky-tests, unassigned-bugs",
}


def _token(force: bool = False) -> str:
    return get_token(_cb_auth, force)


def api_request(method: str, endpoint: str, **kwargs: Any) -> Any:
    return _api_request(method, INSIGHTS_BASE_URL, endpoint, _cb_auth, **kwargs)


def query(
    query_id: Optional[str],
    filter_json: Optional[str],
    table_filter_json: Optional[str],
    include_json: Optional[str],
    start_date: Optional[str],
    end_date: Optional[str],
    page_size: Optional[int],
    page_number: Optional[int],
    sort_column: Optional[str],
    sort_direction: Optional[str],
    dri: Optional[list],
    assignee: Optional[list],
    person: Optional[str],
    manager: Optional[str],
):
    if (person or manager) and include_json:
        print("Error: --person/--manager and --include are mutually exclusive", file=sys.stderr)
        sys.exit(1)
    if query_id and (dri or assignee):
        print("Error: --dri/--assignee cannot be combined with --query-id (the API does not allow query + filter together). Use --person or --manager to scope a named query to a user.", file=sys.stderr)
        sys.exit(1)

    body: dict[str, Any] = {}

    if query_id:
        body["query"] = query_id

    filter_obj: dict[str, Any] = json.loads(filter_json) if filter_json else {}
    if dri:
        ids = [resolve_ros_id(v, _cb_auth) for v in dri]
        filter_obj.setdefault("driIds", [])
        filter_obj["driIds"].extend(ids)
    if assignee:
        ids = [resolve_ros_id(v, _cb_auth) for v in assignee]
        filter_obj.setdefault("assigneeIds", [])
        filter_obj["assigneeIds"].extend(ids)
    if filter_obj:
        body["filter"] = filter_obj

    if table_filter_json:
        body["table_filter"] = json.loads(table_filter_json)

    if person:
        body["include"] = [{"name": "person", "value": resolve_ros_id(person, _cb_auth)}]
    elif manager:
        body["include"] = [{"name": "manager", "value": resolve_ros_id(manager, _cb_auth)}]
    elif include_json:
        body["include"] = json.loads(include_json)

    if start_date:
        body["start_date_time"] = start_date
    if end_date:
        body["end_date_time"] = end_date
    if page_size is not None:
        body["page_size"] = page_size
    if page_number is not None:
        body["page_number"] = page_number
    if sort_column:
        body["sort_column"] = sort_column
    if sort_direction:
        body["sort_direction"] = (
            "SORT_DIRECTION_ASC" if sort_direction.lower() == "asc" else "SORT_DIRECTION_DESC"
        )

    if not body:
        print("Error: provide at least --query-id, --filter, --dri, --assignee, --person, or --manager", file=sys.stderr)
        sys.exit(1)

    result = api_request("POST", "query", json=body)
    print(json.dumps(result, indent=2))


def list_queries():
    rows = [(qid, desc) for qid, desc in NAMED_QUERIES.items()]
    max_id = max(len(r[0]) for r in rows)
    for qid, desc in rows:
        print(f"  {qid:<{max_id}}  {desc}")


def main():
    try:
        _token()
    except Exception as e:
        print(f"Error: could not acquire credential broker token: {e}", file=sys.stderr)
        print("If this is your first time, the script will print an AUTH URL — open it in a browser.", file=sys.stderr)
        sys.exit(2)

    parser = argparse.ArgumentParser(description="Portal Insights CLI for Claude Code")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    query_parser = subparsers.add_parser("query", help="Query Portal Insights for issues")
    query_parser.add_argument("--query-id", help="Named query ID (see list-queries)")
    query_parser.add_argument("--filter", dest="filter_json", help="Custom filter as JSON object")
    query_parser.add_argument("--table-filter", dest="table_filter_json", help="Table-level filter as JSON object")
    query_parser.add_argument("--include", dest="include_json", help='Org scope as JSON array, e.g. \'[{"name": "team", "value": 123}]\'')
    query_parser.add_argument("--start-date", help="Lower bound on date range (ISO 8601)")
    query_parser.add_argument("--end-date", help="Upper bound on date range (ISO 8601)")
    query_parser.add_argument("--page-size", type=int, help="Results per page")
    query_parser.add_argument("--page-number", type=int, help="Page to retrieve (0-indexed)")
    query_parser.add_argument("--sort-column", help="Column name to sort by")
    query_parser.add_argument("--sort-direction", choices=["asc", "desc"], help="Sort direction")
    query_parser.add_argument("--dri", action="append", metavar="IDENTIFIER", help="Filter by DRI (ROS ID, email, or username — repeatable)")
    query_parser.add_argument("--assignee", action="append", metavar="IDENTIFIER", help="Filter by assignee (ROS ID, email, or username — repeatable)")
    query_parser.add_argument("--person", metavar="IDENTIFIER", help="Scope to issues where this person is the DRI (ROS ID, email, or username)")
    query_parser.add_argument("--manager", metavar="IDENTIFIER", help="Scope to issues where DRI is this person or any of their sub-reports (ROS ID, email, or username)")

    subparsers.add_parser("list-queries", help="List all available named query IDs")

    args = parser.parse_args()

    if args.command == "query":
        query(
            query_id=args.query_id,
            filter_json=args.filter_json,
            table_filter_json=args.table_filter_json,
            include_json=args.include_json,
            start_date=args.start_date,
            end_date=args.end_date,
            page_size=args.page_size,
            page_number=args.page_number,
            sort_column=args.sort_column,
            sort_direction=args.sort_direction,
            dri=args.dri,
            assignee=args.assignee,
            person=args.person,
            manager=args.manager,
        )
    elif args.command == "list-queries":
        list_queries()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
