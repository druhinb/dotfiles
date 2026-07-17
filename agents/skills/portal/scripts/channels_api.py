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
"""Portal Channels API for Claude Code"""
import argparse
import json
import sys
from pathlib import Path
from typing import Any, Optional

sys.path.insert(0, str(Path(__file__).parent))
from portal_client import make_auth, get_token, api_request as _api_request

_cb_auth = make_auth()

CHANNELS_URL = "https://apis.simulprod.com/portal-ui-service/v1/channels"
ENROLLMENT_REQUESTS_URL = "https://apis.simulprod.com/portal-ui-service/v1/enrollment-requests"

_PLATFORM = {
    0: "Invalid", 1: "Rcc", 2: "WindowsPlayer", 3: "WindowsStudio",
    4: "MacPlayer", 5: "MacStudio", 6: "IosApp", 7: "GoogleAndroidApp",
    8: "QuestAndroidApp", 9: "AmazonAndroidApp", 10: "TencentAndroidApp",
    11: "Ps4App", 12: "Ps5App", 13: "XboxApp", 14: "UwpApp",
    15: "PcgdkApp", 16: "SamsungAndroidApp",
}

_ENROLLMENT_TYPE = {
    0: "Invalid", 1: "PublicEnrollment", 2: "BetaProgram", 3: "Binding",
}


def _token(force: bool = False) -> str:
    return get_token(_cb_auth, force)

def api_request(method: str, endpoint: str, **kwargs: Any) -> Any:
    return _api_request(method, CHANNELS_URL, endpoint, _cb_auth, **kwargs)


def list_channels(public_only: bool = False):
    params = {"publicOnly": "true"} if public_only else {}
    data = api_request("GET", "", params=params).get("data")
    print(json.dumps(data, indent=2))


def get_channel(channel_name: str):
    data = api_request("GET", channel_name).get("data")
    print(json.dumps(data, indent=2))


def list_channel_versions(
    channel_name: str,
    platform: str,
    page_size: Optional[int] = None,
    page_token: Optional[str] = None
):
    params = {}
    if page_size is not None:
        params["pageSize"] = page_size
    if page_token is not None:
        params["pageToken"] = page_token
    data = api_request("GET", f"version/list/{channel_name}/{platform}", params=params).get("data")
    for version in (data or {}).get("versions", []):
        if "platform" in version:
            version["platform"] = _PLATFORM.get(version["platform"], version["platform"])
    print(json.dumps(data, indent=2))


def get_user_status(username: str):
    data = api_request("GET", f"user-status/{username}").get("data")
    for entry in (data or {}).get("entries", []):
        if "platform" in entry:
            entry["platform"] = _PLATFORM.get(entry["platform"], entry["platform"])
        if "enrollmentType" in entry:
            entry["enrollmentType"] = _ENROLLMENT_TYPE.get(entry["enrollmentType"], entry["enrollmentType"])
    print(json.dumps(data, indent=2))


def list_build_jobs(channel_name: str):
    data = api_request("GET", f"{channel_name}/build-jobs").get("data")
    print(json.dumps(data, indent=2))


def list_android_binary_deployments(channel_name: str):
    data = api_request("GET", f"{channel_name}/android-binary-deployments").get("data")
    print(json.dumps(data, indent=2))


def get_channel_flags(channel_name: str):
    data = api_request("GET", f"{channel_name}/flags").get("data")
    print(json.dumps(data, indent=2))


def get_bindings_for_channel(channel_name: str):
    data = api_request("GET", f"{channel_name}/user-bindings").get("data")
    print(json.dumps(data, indent=2))


def get_user_enrollments(username: str):
    data = api_request("GET", f"user-enrollments/{username}").get("data")
    print(json.dumps(data, indent=2))


def get_bindings_for_user(username: str):
    data = api_request("GET", f"user-bindings/{username}").get("data")
    print(json.dumps(data, indent=2))


def get_public_enrollments(channel_name: str):
    data = api_request("GET", f"{channel_name}/public-enrollments").get("data")
    print(json.dumps(data, indent=2))


def get_all_enrollment_requests():
    data = api_request("GET", "enrollment-requests").get("data")
    print(json.dumps(data, indent=2))


def get_enrollment_requests(channel_name: str):
    data = api_request("GET", f"{channel_name}/enrollment-requests").get("data")
    print(json.dumps(data, indent=2))


def get_release_versions():
    data = api_request("GET", "release-versions").get("data")
    print(json.dumps(data, indent=2))


def get_enrollment_checks(channel_name: str):
    data = api_request("GET", f"{channel_name}/enrollment-checks").get("data")
    print(json.dumps(data, indent=2))


def get_enrollment_thresholds():
    data = _api_request("GET", ENROLLMENT_REQUESTS_URL, "thresholds", _cb_auth).get("data")
    print(json.dumps(data, indent=2))


def main():
    try:
        _token()
    except Exception as e:
        print(f"Error: could not acquire credential broker token: {e}", file=sys.stderr)
        print("If this is your first time, the script will print an AUTH URL — open it in a browser.", file=sys.stderr)
        sys.exit(2)

    parser = argparse.ArgumentParser(description="Portal Channels CLI for Claude Code")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # List command
    list_parser = subparsers.add_parser("list", help="List all channels")
    list_parser.add_argument("--public-only", action="store_true", help="Only return public channels")

    # Get command
    get_parser = subparsers.add_parser("get", help="Get a specific channel by name")
    get_parser.add_argument("name", help="Channel name")

    # List versions command
    list_versions_parser = subparsers.add_parser("list-versions", help="List all versions for a channel on a platform")
    list_versions_parser.add_argument("channel_name", help="Channel name")
    list_versions_parser.add_argument("platform", help="Platform (e.g. WindowsPlayer, MacStudio, IOSApp)")
    list_versions_parser.add_argument("--page-size", type=int, help="Number of results per page")
    list_versions_parser.add_argument("--page-token", help="Pagination token")

    # User status command
    user_status_parser = subparsers.add_parser("user-status", help="Get channel enrollment status for a Roblox username")
    user_status_parser.add_argument("username", help="Roblox username")

    # Build jobs command
    build_jobs_parser = subparsers.add_parser("build-jobs", help="List Android engine binary build jobs for a channel")
    build_jobs_parser.add_argument("channel_name", help="Channel name")

    # Android binary deployments command
    android_deployments_parser = subparsers.add_parser("android-binary-deployments", help="List Android binary deployments for a channel")
    android_deployments_parser.add_argument("channel_name", help="Channel name")

    # Channel flags command
    channel_flags_parser = subparsers.add_parser("channel-flags", help="Get flag overrides for a channel")
    channel_flags_parser.add_argument("channel_name", help="Channel name")

    # Channel bindings command
    channel_bindings_parser = subparsers.add_parser("channel-bindings", help="Get user bindings for a channel")
    channel_bindings_parser.add_argument("channel_name", help="Channel name")

    # User enrollments command
    user_enrollments_parser = subparsers.add_parser("user-enrollments", help="Get channels a user is publicly enrolled in")
    user_enrollments_parser.add_argument("username", help="Roblox username")

    # User bindings command
    user_bindings_parser = subparsers.add_parser("user-bindings", help="Get channel bindings for a user")
    user_bindings_parser.add_argument("username", help="Roblox username")

    # Public enrollments command
    public_enrollments_parser = subparsers.add_parser("public-enrollments", help="Get public enrollments for a channel")
    public_enrollments_parser.add_argument("channel_name", help="Channel name")

    # All enrollment requests command
    subparsers.add_parser("all-enrollment-requests", help="Get all channel enrollment requests")

    # Enrollment requests command
    enrollment_requests_parser = subparsers.add_parser("enrollment-requests", help="Get enrollment requests for a channel")
    enrollment_requests_parser.add_argument("channel_name", help="Channel name")

    # Release versions command
    subparsers.add_parser("release-versions", help="Get release versions across channels")

    # Enrollment checks command
    enrollment_checks_parser = subparsers.add_parser("enrollment-checks", help="Get enrollment checks for a channel")
    enrollment_checks_parser.add_argument("channel_name", help="Channel name")

    # Enrollment thresholds command
    subparsers.add_parser("enrollment-thresholds", help="Get enrollment request thresholds")

    args = parser.parse_args()

    if args.command == "list":
        list_channels(args.public_only)
    elif args.command == "get":
        get_channel(args.name)
    elif args.command == "list-versions":
        list_channel_versions(args.channel_name, args.platform, args.page_size, args.page_token)
    elif args.command == "user-status":
        get_user_status(args.username)
    elif args.command == "build-jobs":
        list_build_jobs(args.channel_name)
    elif args.command == "android-binary-deployments":
        list_android_binary_deployments(args.channel_name)
    elif args.command == "channel-flags":
        get_channel_flags(args.channel_name)
    elif args.command == "channel-bindings":
        get_bindings_for_channel(args.channel_name)
    elif args.command == "user-enrollments":
        get_user_enrollments(args.username)
    elif args.command == "user-bindings":
        get_bindings_for_user(args.username)
    elif args.command == "public-enrollments":
        get_public_enrollments(args.channel_name)
    elif args.command == "all-enrollment-requests":
        get_all_enrollment_requests()
    elif args.command == "enrollment-requests":
        get_enrollment_requests(args.channel_name)
    elif args.command == "release-versions":
        get_release_versions()
    elif args.command == "enrollment-checks":
        get_enrollment_checks(args.channel_name)
    elif args.command == "enrollment-thresholds":
        get_enrollment_thresholds()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
