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
"""Portal Flags API for Claude Code"""
import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent))
from portal_client import make_auth, get_token, api_request as _api_request

_cb_auth = make_auth()

PORTAL_URL = "https://apis.simulprod.com/portal-ui-service/v1/fastflags"
FLAG_TYPES = {
    0: "FFlag",
    1: "DFFlag",
    2: "SFFlag",
    3: "FInt",
    4: "DFInt",
    5: "SFInt",
    6: "FString",
    7: "DFString",
    8: "SFString",
    9: "FLog",
    10: "DFLog",
    11: "SFLog",
    12: "Unknown"
}
FLAG_TYPE_CHOICES = [v for v in FLAG_TYPES.values() if v != "Unknown"]

def _token(force: bool = False) -> str:
    return get_token(_cb_auth, force)

def api_request(method: str, endpoint: str, **kwargs: Any) -> Any:
    return _api_request(method, PORTAL_URL, endpoint, _cb_auth, **kwargs)

# Use to get the production status accross all platforms
def get_production_status():
    data = api_request("GET", "production-status").get("data")
    platforms = data.get("platforms")
    for platform in platforms:
        print(f"  {platform.get('platform')}:")
        for version in platform.get("versions", []):
            print(f"    {version.get('version')} — adoption: {version.get('adoption')}, availability: {version.get('availability')}")

# Use to check if a flag exists in the given version
def get_flag_production_status(flag_type: str, name: str, major: str, minor: str):
    params = { "major": major, "minor": minor }
    flag = flag_type + name
    data = api_request("GET", f"{flag}/production-status", params=params)
    exists = data.get("data").get("exists")

    if exists:
        print(f"  {flag} exists in the given version")
    else:
        print(f"  {flag} does not exist in the given version")

# Used to get detailed information about a specific flag
def get_flag_details(flag_type: str, name: str):
    flag = flag_type + name
    data = api_request("GET", f"{flag}/details").get("data")

    configuration = data.get("configuration")
    name = configuration.get("name")
    owner = configuration.get("owner")
    if owner == "UNKNOWN":
        print(f"  Error: Flag {flag} does not exist.", file=sys.stderr)
        sys.exit(1)
    sha = configuration.get("sha")
    repo = configuration.get("repository")
    regular_flags = configuration.get("regularFlags")
    data_center_filter_flags = configuration.get("dataCenterFilterFlags")
    ixp_flags = configuration.get("ixpFlags")
    place_filter_flags = configuration.get("placeFilterFlags")
    rollout_flags = configuration.get("rolloutFlags")
    staged_flags = configuration.get("stagedFlags")
    universe_filter_flags = configuration.get("universeFilterFlags")

    engine_source_code_definitions = data.get("engineSourceCodeDefinitions")
    flag_type_index = data.get("flagType")
    version = data.get("version")

    print(f"  Flag Configuration:")
    print(f"    Name: {name}")
    print(f"    Owner: {owner}")
    print(f"    Sha: {sha}")
    print(f"    Repository: {repo}")
    if regular_flags:
        print(f"    Regular Flags:")
        for flag in regular_flags:
            print(f"      {flag}")
    if data_center_filter_flags:
        print(f"    Data Center Filter Flags:")
        for flag in data_center_filter_flags:
            print(f"      {flag}")
    if ixp_flags:
        print(f"    IXP Flags:")
        for flag in ixp_flags:
            print(f"      {flag}")
    if place_filter_flags:
        print(f"    Place Filter Flags:")
        for flag in place_filter_flags:
            print(f"      {flag}")
    if rollout_flags:
        print(f"    Rollout Flags:")
        for flag in rollout_flags:
            print(f"      {flag}")
    if staged_flags:
        print(f"    Staged Flags:")
        for flag in staged_flags:
            print(f"      {flag}")
    if universe_filter_flags:
        print(f"    Universe Filter Flags:")
        for flag in universe_filter_flags:
            print(f"      {flag}")
    print(f"  Engine Source Code Definitions:")
    for definition in engine_source_code_definitions:
        print(f"    {definition}")
    print(f"  Flag Type: {FLAG_TYPES[flag_type_index]}")
    print(f"  Version: {version}")

# Use to get the value of a flag for specific buckets
def get_flag_value(flag_type: str, name: str, buckets: list[str]):
    flag = flag_type + name
    params = { "bucket": buckets }
    data = api_request("GET", f"{flag}/values", params=params).get("data")
    values = data.get("values")
    if values:
        print(f"  Values:")
        for entry in values:
            bucket = entry.get("bucket")
            value = entry.get("value")
            print(f"    {bucket}: {value}")
    else:
        print(f"  No values found for {flag} in the requested buckets — flag may not exist or has no values set.", file=sys.stderr)

# Used to format the output of a list of flags
def print_flags(flags, name: str, show_names: bool):
    print(f"  {name}: {len(flags)}")
    if show_names:
        for i, flag in enumerate(flags):
            print(flag.get("flagName"), end=", " if i < len(flags) - 1 else "\n")

# Use to get the flags for a given owner, categorized by their lifecycle state
def get_user_flags(user: str, show_names = False):
    params = { "user": user }
    data = api_request("GET", "mine", params=params).get("data")
    unflippable = data.get("unflippable")
    flippable = data.get("flippable")
    fully_enabled = data.get("fullyEnabled")
    stale = data.get("stale")
    removed_from_source = data.get("removedFromSource")

    print_flags(unflippable, "Unflippable", show_names)
    print_flags(flippable, "Flippable", show_names)
    print_flags(fully_enabled, "Fully Enabled", show_names)
    print_flags(stale, "Stale Flags", show_names)
    print_flags(removed_from_source, "Removed From Source", show_names)

# Use to get available buckets and their configuration
def get_buckets():
    data = api_request("GET", "buckets").get("data")
    buckets = data.get("buckets")
    for bucket in buckets:
        print(f"  {bucket.get('name')}: allowed={bucket.get('allowed')}, clientSettingsIdentifier={bucket.get('clientSettingsIdentifier')}")

# Use to get the bucket status for a specific flag
def get_flag_buckets(flag_type: str, name: str):
    flag = flag_type + name
    data = api_request("GET", f"{flag}/buckets").get("data")
    buckets = data.get("buckets")
    for bucket in buckets:
        print(f"  {bucket.get('name')}: allowed={bucket.get('allowed')}, clientSettingsIdentifier={bucket.get('clientSettingsIdentifier')}")

# Use to list flag change requests or get a specific request by ID
def get_requests(request_id=None, author=None, bucket=None, flag_name=None, flag_type=None,
                 from_date=None, to_date=None, owner=None, per_page=None, cursor=None):
    if request_id:
        data = api_request("GET", f"requests/{request_id}").get("data")
    else:
        params = {}
        if author:
            params["author"] = author
        if bucket:
            params["bucket"] = bucket
        if flag_name:
            params["flagName"] = flag_name
        if flag_type:
            params["flagType"] = flag_type
        if from_date:
            params["from"] = from_date
        if to_date:
            params["to"] = to_date
        if owner:
            params["owner"] = owner
        if per_page is not None:
            params["perPage"] = per_page
        if cursor:
            params["cursor"] = cursor
        data = api_request("GET", "requests", params=params).get("data")
    print(json.dumps(data, indent=2))

# Use to tell if flags are currently locked
def get_flag_lock_status():
    data = api_request("GET", "lock").get("data")

    print("  Locked:", data.get("lockStatus").get("locked"))
    print("  Updated Time:", data.get("lockStatus").get("updatedTime"))
    print("  MessageUri:", data.get("lockStatus").get("messageUri"))
    print("  Overridable:", data.get("lockStatus").get("overridable"))

def main():
    try:
        _token()
    except Exception as e:
        print(f"Error: could not acquire credential broker token: {e}", file=sys.stderr)
        print("If this is your first time, the script will print an AUTH URL — open it in a browser.", file=sys.stderr)
        sys.exit(2)

    parser = argparse.ArgumentParser(description="Portal Flags CLI for Claude Code")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Status command
    status_parser = subparsers.add_parser("status", help="Get production status (all platforms, or a specific flag)")
    status_parser.add_argument("--type", choices=FLAG_TYPE_CHOICES, help="Data type of the flag")
    status_parser.add_argument("--name", help="Flag name (omit for overall production status)")
    status_parser.add_argument("--major", help="Major version (required when name is provided)")
    status_parser.add_argument("--minor", help="Minor version (required when name is provided)")

    # Details command
    details_parser = subparsers.add_parser("details", help="Get the details of a flag")
    details_parser.add_argument("type", choices=FLAG_TYPE_CHOICES, help="Data type of the flag")
    details_parser.add_argument("name", help="Name of the flag")

    # Value command
    value_parser = subparsers.add_parser("value", help="Get the value of a flag for a specific bucket")
    value_parser.add_argument("type", choices=FLAG_TYPE_CHOICES, help="Data type of the flag")
    value_parser.add_argument("name", help="Name of the flag")
    value_parser.add_argument("buckets", nargs="+", help="Name of the bucket")

    # Mine command
    mine_parser = subparsers.add_parser("mine", help="Get the flags for the given user")
    mine_parser.add_argument("user", help="AD Username of the user")
    mine_parser.add_argument("-l", "--list", action="store_true", help="List the name of all flags")

    # Lock status command
    subparsers.add_parser("lock-status", help="Get the lock status for engine flags")

    # Buckets command
    buckets_parser = subparsers.add_parser("buckets", help="Get the available buckets and their configuration")
    buckets_parser.add_argument("--type", choices=FLAG_TYPE_CHOICES, help="Data type of the flag to get bucket status for")
    buckets_parser.add_argument("--name", help="Flag name to get bucket status for")

    # Requests command
    requests_parser = subparsers.add_parser("requests", help="List flag change requests, or get a specific request by ID")
    requests_parser.add_argument("requestId", nargs="?", help="Request ID (omit to list requests)")
    requests_parser.add_argument("--author", help="Filter by author")
    requests_parser.add_argument("--bucket", help="Filter by bucket")
    requests_parser.add_argument("--flag-name", dest="flagName", help="Filter by flag name")
    requests_parser.add_argument("--flag-type", dest="flagType",
                                 choices=["regularFlags", "rolloutFlags", "stagedFlags",
                                          "universeFilterFlags", "placeFilterFlags",
                                          "dataCenterFilterFlags", "ixpFlags"],
                                 help="Filter by flag type")
    requests_parser.add_argument("--from", dest="from_date", metavar="FROM", help="ISO 8601 lower bound")
    requests_parser.add_argument("--to", dest="to_date", metavar="TO", help="ISO 8601 upper bound")
    requests_parser.add_argument("--owner", help="Filter by owner")
    requests_parser.add_argument("--per-page", dest="perPage", type=int, help="Results per page")
    requests_parser.add_argument("--cursor", help="Pagination cursor")

    args = parser.parse_args()

    if args.command == "status":
        if bool(args.type) != bool(args.name):
            parser.error("--type and --name must both be provided together")
        if args.name:
            if not args.major or not args.minor:
                parser.error("--major and --minor are required when a flag name is provided")
            get_flag_production_status(args.type, args.name, args.major, args.minor)
        else:
            get_production_status()
    elif args.command == "details":
        get_flag_details(args.type, args.name)
    elif args.command == "value":
        get_flag_value(args.type, args.name, args.buckets)
    elif args.command == "mine":
        get_user_flags(args.user, args.list)
    elif args.command == "lock-status":
        get_flag_lock_status()
    elif args.command == "buckets":
        if bool(args.type) != bool(args.name):
            parser.error("--type and --name must both be provided together")
        if args.name:
            get_flag_buckets(args.type, args.name)
        else:
            get_buckets()
    elif args.command == "requests":
        get_requests(
            request_id=args.requestId,
            author=args.author,
            bucket=args.bucket,
            flag_name=args.flagName,
            flag_type=args.flagType,
            from_date=args.from_date,
            to_date=args.to_date,
            owner=args.owner,
            per_page=args.perPage,
            cursor=args.cursor,
        )

if __name__ == "__main__":
    main()
