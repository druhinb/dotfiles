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
"""Portal TestHub API for Claude Code"""
import argparse
import json
import sys
from pathlib import Path
from typing import Any, Optional

sys.path.insert(0, str(Path(__file__).parent))
from portal_client import make_auth, get_token, api_request as _api_request

_cb_auth = make_auth()

TESTHUB_URL = "https://apis.simulprod.com/portal-ui-service/v1/testing-hub"

_STATUS = {
    0: "Pending", 1: "Running", 2: "Success", 3: "Failed",
    4: "Timeout", 5: "Indeterminate", 6: "Skipped",
}

_RUN_TYPE = {
    0: "Test", 1: "Suite", 2: "Group", 3: "Device", 4: "Mixed",
}

_INITIATOR = {
    0: "Local", 1: "CLI",
}


def _map_run(run: dict) -> dict:
    if not run:
        return run
    if isinstance(run.get("status"), int):
        run["status"] = _STATUS.get(run["status"], run["status"])
    if isinstance(run.get("runType"), int):
        run["runType"] = _RUN_TYPE.get(run["runType"], run["runType"])
    if isinstance(run.get("initiator"), int):
        run["initiator"] = _INITIATOR.get(run["initiator"], run["initiator"])
    return run


def _token(force: bool = False) -> str:
    return get_token(_cb_auth, force)

def api_request(method: str, endpoint: str, **kwargs: Any) -> Any:
    return _api_request(method, TESTHUB_URL, endpoint, _cb_auth, **kwargs)


def list_platforms():
    data = api_request("GET", "platforms").get("data")
    print(json.dumps(data, indent=2))


def list_test_types():
    data = api_request("GET", "test-types").get("data")
    print(json.dumps(data, indent=2))


def list_devices(platform: Optional[str] = None):
    params = {}
    if platform is not None:
        params["platform"] = platform
    data = api_request("GET", "devices", params=params).get("data")
    print(json.dumps(data, indent=2))


def list_tests(
    test_type: Optional[str] = None,
    owner: Optional[str] = None,
    platform: Optional[str] = None,
    page: Optional[int] = None,
    limit: Optional[int] = None,
):
    params = {}
    if test_type is not None:
        params["test-type"] = test_type
    if owner is not None:
        params["owner"] = owner
    if platform is not None:
        params["platform"] = platform
    if page is not None:
        params["page"] = page
    if limit is not None:
        params["limit"] = limit
    data = api_request("GET", "tests", params=params).get("data")
    print(json.dumps(data, indent=2))


def get_test(codename: str):
    data = api_request("GET", f"tests/{codename}").get("data")
    print(json.dumps(data, indent=2))


def list_runs(
    test_type: Optional[list] = None,
    suite: Optional[list] = None,
    test: Optional[list] = None,
    platform: Optional[list] = None,
    device: Optional[list] = None,
    status: Optional[list] = None,
    owners: Optional[list] = None,
    requester: Optional[list] = None,
    initiator: Optional[list] = None,
    source: Optional[list] = None,
    from_date: Optional[str] = None,
    to_date: Optional[str] = None,
    group_tests: bool = False,
    test_name: Optional[str] = None,
    page: Optional[int] = None,
    limit: Optional[int] = None,
    sort: Optional[str] = None,
):
    params = {}
    if test_type:
        params["test-type"] = test_type
    if suite:
        params["suite"] = suite
    if test:
        params["test"] = test
    if platform:
        params["platform"] = platform
    if device:
        params["device"] = device
    if status:
        params["status"] = status
    if owners:
        params["owners"] = owners
    if requester:
        params["requester"] = requester
    if initiator:
        params["initiator"] = initiator
    if source:
        params["source"] = source
    if from_date is not None:
        params["from"] = from_date
    if to_date is not None:
        params["to"] = to_date
    if group_tests:
        params["group-tests"] = "true"
    if test_name is not None:
        params["test-name"] = test_name
    if page is not None:
        params["page"] = page
    if limit is not None:
        params["limit"] = limit
    if sort is not None:
        params["sort"] = sort
    data = api_request("GET", "tests/runs", params=params).get("data")
    for run in (data or {}).get("runs") or []:
        _map_run(run)
    print(json.dumps(data, indent=2))


def get_run(run_id: str):
    data = api_request("GET", f"tests/runs/{run_id}").get("data")
    _map_run(data)
    for device in (data or {}).get("devices") or []:
        _map_run(device)
    print(json.dumps(data, indent=2))


def list_device_runs(
    test_type: Optional[str] = None,
    test: Optional[str] = None,
    platform: Optional[str] = None,
    device: Optional[str] = None,
    page: Optional[int] = None,
    limit: Optional[int] = None,
    status: Optional[str] = None,
    suite: Optional[str] = None,
):
    params = {}
    if test_type is not None:
        params["test-type"] = test_type
    if test is not None:
        params["test"] = test
    if platform is not None:
        params["platform"] = platform
    if device is not None:
        params["device"] = device
    if page is not None:
        params["page"] = page
    if limit is not None:
        params["limit"] = limit
    if status is not None:
        params["status"] = status
    if suite is not None:
        params["suite"] = suite
    data = api_request("GET", "tests/runs/devices", params=params).get("data")
    for run in (data or {}).get("runs") or []:
        _map_run(run)
    print(json.dumps(data, indent=2))


def get_device_run(device_run_id: str):
    data = api_request("GET", f"tests/runs/devices/{device_run_id}").get("data")
    _map_run(data)
    print(json.dumps(data, indent=2))


def get_group_run(group_run_id: str):
    data = api_request("GET", f"groups/runs/{group_run_id}").get("data")
    _map_run(data)
    for test in (data or {}).get("tests") or []:
        _map_run(test)
        for device in (test or {}).get("devices") or []:
            _map_run(device)
    print(json.dumps(data, indent=2))


def get_suite_run(suite_run_id: str):
    data = api_request("GET", f"suites/runs/{suite_run_id}").get("data")
    _map_run(data)
    for test in (data or {}).get("tests") or []:
        _map_run(test)
        for device in (test or {}).get("devices") or []:
            _map_run(device)
    print(json.dumps(data, indent=2))


def main():
    try:
        _token()
    except Exception as e:
        print(f"Error: could not acquire credential broker token: {e}", file=sys.stderr)
        print("If this is your first time, the script will print an AUTH URL — open it in a browser.", file=sys.stderr)
        sys.exit(2)

    parser = argparse.ArgumentParser(description="Portal TestHub CLI for Claude Code")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # platforms
    subparsers.add_parser("platforms", help="List all supported platforms")

    # test-types
    subparsers.add_parser("test-types", help="List all available test types")

    # devices
    devices_parser = subparsers.add_parser("devices", help="List devices, optionally filtered by platform")
    devices_parser.add_argument("--platform", help="Platform code name to filter by")

    # list-tests
    list_tests_parser = subparsers.add_parser("list-tests", help="List test definitions")
    list_tests_parser.add_argument("--test-type", help="Filter by test type code name")
    list_tests_parser.add_argument("--owner", help="Filter by owner")
    list_tests_parser.add_argument("--platform", help="Filter by platform code name")
    list_tests_parser.add_argument("--page", type=int, help="Page number")
    list_tests_parser.add_argument("--limit", type=int, help="Results per page")

    # get-test
    get_test_parser = subparsers.add_parser("get-test", help="Get a single test definition by code name")
    get_test_parser.add_argument("codename", help="Test code name")

    # list-runs
    list_runs_parser = subparsers.add_parser("list-runs", help="List test runs")
    list_runs_parser.add_argument("--test-type", nargs="+", help="Filter by test type code name(s)")
    list_runs_parser.add_argument("--suite", nargs="+", help="Filter by suite code name(s)")
    list_runs_parser.add_argument("--test", nargs="+", help="Filter by test code name(s)")
    list_runs_parser.add_argument("--platform", nargs="+", help="Filter by platform code name(s)")
    list_runs_parser.add_argument("--device", nargs="+", help="Filter by device code name(s)")
    list_runs_parser.add_argument("--status", nargs="+",
                                  choices=["Pending", "Running", "Success", "Failed", "Timeout", "Indeterminate", "Skipped"],
                                  help="Filter by run status")
    list_runs_parser.add_argument("--owners", nargs="+", help="Filter by owner(s)")
    list_runs_parser.add_argument("--requester", nargs="+", help="Filter by requester(s)")
    list_runs_parser.add_argument("--initiator", nargs="+", choices=["Local", "CLI"], help="Filter by initiator")
    list_runs_parser.add_argument("--source", nargs="+", help="Filter by source(s)")
    list_runs_parser.add_argument("--from", dest="from_date", metavar="FROM", help="ISO 8601 lower bound (e.g. 2024-01-01T00:00:00Z)")
    list_runs_parser.add_argument("--to", dest="to_date", metavar="TO", help="ISO 8601 upper bound")
    list_runs_parser.add_argument("--group-tests", action="store_true", help="Group results by test")
    list_runs_parser.add_argument("--test-name", help="Filter by test name substring")
    list_runs_parser.add_argument("--page", type=int, help="Page number")
    list_runs_parser.add_argument("--limit", type=int, help="Results per page")
    list_runs_parser.add_argument("--sort", help="Sort order")

    # get-run
    get_run_parser = subparsers.add_parser("get-run", help="Get a single test run by ID")
    get_run_parser.add_argument("run_id", help="Test run ID")

    # list-device-runs
    list_device_runs_parser = subparsers.add_parser("list-device-runs", help="List device runs")
    list_device_runs_parser.add_argument("--test-type", help="Filter by test type code name")
    list_device_runs_parser.add_argument("--test", help="Filter by test code name")
    list_device_runs_parser.add_argument("--platform", help="Filter by platform code name")
    list_device_runs_parser.add_argument("--device", help="Filter by device code name")
    list_device_runs_parser.add_argument("--page", type=int, help="Page number")
    list_device_runs_parser.add_argument("--limit", type=int, help="Results per page")
    list_device_runs_parser.add_argument("--status",
                                         choices=["Pending", "Running", "Success", "Failed", "Timeout", "Indeterminate", "Skipped"],
                                         help="Filter by status")
    list_device_runs_parser.add_argument("--suite", help="Filter by suite code name")

    # get-device-run
    get_device_run_parser = subparsers.add_parser("get-device-run", help="Get a single device run by ID")
    get_device_run_parser.add_argument("device_run_id", help="Device run ID")

    # get-group-run
    get_group_run_parser = subparsers.add_parser("get-group-run", help="Get a single group run by ID")
    get_group_run_parser.add_argument("group_run_id", help="Group run ID")

    # get-suite-run
    get_suite_run_parser = subparsers.add_parser("get-suite-run", help="Get a single suite run by ID")
    get_suite_run_parser.add_argument("suite_run_id", help="Suite run ID")

    args = parser.parse_args()

    if args.command == "platforms":
        list_platforms()
    elif args.command == "test-types":
        list_test_types()
    elif args.command == "devices":
        list_devices(args.platform)
    elif args.command == "list-tests":
        list_tests(args.test_type, args.owner, args.platform, args.page, args.limit)
    elif args.command == "get-test":
        get_test(args.codename)
    elif args.command == "list-runs":
        list_runs(
            test_type=args.test_type,
            suite=args.suite,
            test=args.test,
            platform=args.platform,
            device=args.device,
            status=args.status,
            owners=args.owners,
            requester=args.requester,
            initiator=args.initiator,
            source=args.source,
            from_date=args.from_date,
            to_date=args.to_date,
            group_tests=args.group_tests,
            test_name=args.test_name,
            page=args.page,
            limit=args.limit,
            sort=args.sort,
        )
    elif args.command == "get-run":
        get_run(args.run_id)
    elif args.command == "list-device-runs":
        list_device_runs(
            test_type=args.test_type,
            test=args.test,
            platform=args.platform,
            device=args.device,
            page=args.page,
            limit=args.limit,
            status=args.status,
            suite=args.suite,
        )
    elif args.command == "get-device-run":
        get_device_run(args.device_run_id)
    elif args.command == "get-group-run":
        get_group_run(args.group_run_id)
    elif args.command == "get-suite-run":
        get_suite_run(args.suite_run_id)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
