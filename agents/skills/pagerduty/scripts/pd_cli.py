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
"""PagerDuty CLI for Claude Code — read-only access to Roblox's PagerDuty.

Authentication is handled automatically via the shared credential-broker
library.  Tokens are cached in ``~/.cache/rbx-skills/pagerduty/token_cache.json``
and refreshed only when expired.  Credentials are never printed to stdout.

Usage:
    SKILL_DIR=".claude/skills/pagerduty/scripts"

    # Who is on call right now?
    uv run $SKILL_DIR/pd_cli.py oncalls

    # All open (triggered + acknowledged) incidents
    uv run $SKILL_DIR/pd_cli.py incidents

    # High-urgency triggered incidents for a specific service
    uv run $SKILL_DIR/pd_cli.py incidents --status triggered --urgency high \\
        --service PSVC001

    # Single incident with full detail
    uv run $SKILL_DIR/pd_cli.py incident P1ABC23

    # Alerts and timeline for an incident
    uv run $SKILL_DIR/pd_cli.py incident-alerts P1ABC23
    uv run $SKILL_DIR/pd_cli.py incident-log P1ABC23

    # On-call for a specific schedule or escalation policy
    uv run $SKILL_DIR/pd_cli.py oncalls --schedule PSCHED01
    uv run $SKILL_DIR/pd_cli.py oncalls --policy PESC001

    # Services with their owning teams
    uv run $SKILL_DIR/pd_cli.py services

    # Escalation policies for a team
    uv run $SKILL_DIR/pd_cli.py escalation-policies --team PTEAM01

    # User lookup by name or email
    uv run $SKILL_DIR/pd_cli.py users --query "jane.doe@roblox.com"
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

import requests
from rbx_skills_auth import CredentialBrokerAuth

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_BASE_URL = "https://api.pagerduty.com"

_auth = CredentialBrokerAuth(
    service_name="pagerduty",
    display_name="PagerDuty",
    cache_dir=Path.home() / ".cache" / "rbx-skills" / "pagerduty",
    connect_url="https://apis.simulprod.com/credential-broker/v1/connect/pagerduty",
)
_ACCEPT_HEADER = "application/vnd.pagerduty+json;version=2"

# PagerDuty resource IDs are alphanumeric (e.g. P1ABC23, PSVC001).
_VALID_ID_RE = re.compile(r"^[A-Za-z0-9_-]+$")


def _validated_id(value: str) -> str:
    """Argparse type that rejects IDs containing path-traversal characters.

    Args:
        value: The raw CLI argument.

    Returns:
        The validated ID string.

    Raises:
        argparse.ArgumentTypeError: If the value contains unexpected characters.
    """
    if not _VALID_ID_RE.match(value):
        raise argparse.ArgumentTypeError(
            f"invalid PagerDuty ID {value!r} — expected alphanumeric characters"
        )
    return value


# ---------------------------------------------------------------------------
# PagerDuty API client
# ---------------------------------------------------------------------------


class PagerDutyClient:
    """Thin wrapper around the PagerDuty REST API v2.

    Handles authentication automatically, and retries once on 401 (token
    expired mid-session) before giving up.
    """

    def __init__(self) -> None:
        self._token: str | None = None

    def _ensure_auth(self, force: bool = False) -> None:
        """Fetch or re-fetch a valid Bearer token.

        Args:
            force: If True, bypass the cache and always fetch a fresh token.
        """
        self._token = _auth.get_token(force_refresh=force)["access_token"]

    def _auth_headers(self) -> dict[str, str]:
        """Return the headers required on every PagerDuty request.

        Returns:
            A dict containing Authorization and Accept headers.
        """
        return {
            "Authorization": f"Bearer {self._token}",
            "Accept": _ACCEPT_HEADER,
        }

    def request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
    ) -> requests.Response:
        """Make an authenticated API request, retrying once on 401.

        Args:
            method: HTTP method (e.g. "GET").
            path: Path relative to the base URL (e.g. "/incidents").
            params: Optional query parameters.

        Returns:
            The HTTP response object.
        """
        if self._token is None:
            self._ensure_auth()

        response = requests.request(
            method,
            f"{_BASE_URL}{path}",
            headers=self._auth_headers(),
            params=params,
            timeout=30,
        )

        if response.status_code == 401:
            # Token may have expired mid-session — refresh once and retry.
            self._ensure_auth(force=True)
            response = requests.request(
                method,
                f"{_BASE_URL}{path}",
                headers=self._auth_headers(),
                params=params,
                timeout=30,
            )

        return response

    def get(
        self,
        path: str,
        params: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Perform a GET request and return the parsed JSON body.

        Args:
            path: API path relative to the base URL.
            params: Optional query parameters.

        Returns:
            Parsed JSON response as a dict.

        Raises:
            SystemExit: If the response status code indicates an error.
        """
        response = self.request("GET", path, params=params)
        if not response.ok:
            _print_api_error(response)
            sys.exit(1)
        return response.json()

    def get_paginated(
        self,
        path: str,
        result_key: str,
        params: dict[str, Any] | None = None,
        max_results: int | None = None,
    ) -> list[dict[str, Any]]:
        """Fetch all pages from a paginated endpoint and return every item.

        PagerDuty uses offset-based pagination. This method follows ``more``
        until the full result set is collected, then returns it as a flat list.

        Args:
            path: API path relative to the base URL.
            result_key: The response key that holds the list of items
                (e.g. "incidents", "services", "oncalls").
            params: Optional base query parameters. ``limit`` and ``offset``
                are managed automatically.
            max_results: Stop collecting after this many items. Useful when
                callers know they only need the first N results from a very
                large dataset.

        Returns:
            All collected items across every page.
        """
        base_params = dict(params or {})
        base_params.setdefault("limit", 100)

        results: list[dict[str, Any]] = []
        offset = 0

        while True:
            page = self.get(path, params={**base_params, "offset": offset})
            items = page.get(result_key, [])
            results.extend(items)

            if max_results is not None and len(results) >= max_results:
                return results[:max_results]

            if not page.get("more", False):
                break

            offset += len(items)

        return results


_client = PagerDutyClient()


# ---------------------------------------------------------------------------
# Error formatting
# ---------------------------------------------------------------------------


def _print_api_error(response: requests.Response) -> None:
    """Write a human-readable API error to stderr.

    Args:
        response: The failed HTTP response from the PagerDuty API.
    """
    try:
        body = response.json()
        error = body.get("error", {})
        message = error.get("message") or response.text[:400]
        details = error.get("errors", [])
        if details:
            message += ": " + "; ".join(details)
    except Exception:  # pylint: disable=broad-except
        message = response.text[:400]
    print(f"Error ({response.status_code}): {message}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------


def _print_json(data: Any) -> None:
    """Serialize and print data as indented JSON to stdout.

    Args:
        data: Any JSON-serializable value.
    """
    print(json.dumps(data, indent=2, default=str))


def _print_incident(inc: dict[str, Any]) -> None:
    """Print a compact one-block summary of a single incident.

    Args:
        inc: A PagerDuty incident object.
    """
    teams = [t.get("summary", "") for t in (inc.get("teams") or [])]
    team_str = f"  teams={','.join(teams)}" if teams else ""
    print(
        f"[{inc.get('id')}] {inc.get('title', '')}\n"
        f"  status={inc.get('status', '?')}"
        f"  urgency={inc.get('urgency', '?')}"
        f"  service={(inc.get('service') or {}).get('summary', '?')}"
        f"  created={inc.get('created_at', '')[:10]}"
        f"{team_str}\n"
        f"  {inc.get('html_url', '')}\n"
    )


# ---------------------------------------------------------------------------
# Command implementations
# ---------------------------------------------------------------------------


def cmd_incidents(args: argparse.Namespace) -> None:
    """List incidents, with optional status/urgency/service/team filters.

    Args:
        args: Parsed CLI arguments.
    """
    params: dict[str, Any] = {"limit": args.limit}

    if args.status:
        params["statuses[]"] = args.status
    if args.urgency:
        params["urgencies[]"] = args.urgency
    if args.service:
        params["service_ids[]"] = args.service
    if args.team:
        params["team_ids[]"] = args.team
    if args.since:
        params["since"] = args.since
    if args.until:
        params["until"] = args.until
    if args.include:
        params["include[]"] = args.include

    data = _client.get("/incidents", params=params)
    incidents = data.get("incidents", [])
    total = data.get("total")
    count_str = (
        str(len(incidents)) if total is None else f"{len(incidents)} of {total}"
    )
    print(f"{count_str} incident(s)\n", file=sys.stderr)

    for inc in incidents:
        _print_incident(inc)


def cmd_incident(args: argparse.Namespace) -> None:
    """Get a single incident with full detail.

    Args:
        args: Parsed CLI arguments (requires ``args.id``).
    """
    data = _client.get(
        f"/incidents/{args.id}",
        params={
            "include[]": [
                "services",
                "teams",
                "acknowledgers",
                "first_trigger_log_entries",
            ]
        },
    )
    _print_json(data.get("incident", data))


def cmd_incident_alerts(args: argparse.Namespace) -> None:
    """List all alerts grouped under a specific incident.

    Args:
        args: Parsed CLI arguments (requires ``args.id``).
    """
    data = _client.get(f"/incidents/{args.id}/alerts")
    _print_json(data.get("alerts", []))


def cmd_incident_log(args: argparse.Namespace) -> None:
    """Show the chronological event log for a specific incident.

    Args:
        args: Parsed CLI arguments (requires ``args.id``).
    """
    data = _client.get(
        f"/incidents/{args.id}/log_entries",
        params={"include[]": ["channels"]},
    )
    _print_json(data.get("log_entries", []))


def cmd_oncalls(args: argparse.Namespace) -> None:
    """List current on-call entries, optionally filtered by schedule or policy.

    Args:
        args: Parsed CLI arguments.
    """
    params: dict[str, Any] = {"include[]": ["users"]}

    if args.service_name:
        services = _client.get_paginated(
            "/services",
            "services",
            params={"query": args.service_name, "include[]": ["teams"]},
            max_results=5,
        )
        if not services:
            print(
                f"Error: No service found matching {args.service_name!r}",
                file=sys.stderr,
            )
            sys.exit(1)
        svc = services[0]
        ep = svc.get("escalation_policy") or {}
        ep_id = ep.get("id")
        if not ep_id:
            print(
                f"Error: Service {svc.get('name')!r} has no escalation policy",
                file=sys.stderr,
            )
            sys.exit(1)
        print(
            f"Resolved service {svc.get('name')!r} → "
            f"escalation policy {ep.get('summary')!r} ({ep_id})",
            file=sys.stderr,
        )
        params["escalation_policy_ids[]"] = [ep_id]

    if args.schedule:
        params["schedule_ids[]"] = args.schedule
    if args.policy:
        params["escalation_policy_ids[]"] = args.policy
    if args.since:
        params["since"] = args.since
    if args.until:
        params["until"] = args.until

    entries = _client.get_paginated("/oncalls", "oncalls", params=params)
    print(f"{len(entries)} on-call entry(ies)\n", file=sys.stderr)

    for entry in entries:
        user = (entry.get("user") or {}).get("summary", "No user")
        policy = (entry.get("escalation_policy") or {}).get("summary", "?")
        schedule = (entry.get("schedule") or {}).get("summary", "")
        level = entry.get("escalation_level", "?")
        schedule_str = f"  schedule={schedule}" if schedule else ""
        print(f"{user}  level={level}  policy={policy}{schedule_str}")


def cmd_schedules(args: argparse.Namespace) -> None:
    """List all on-call schedules, optionally filtered by name.

    Args:
        args: Parsed CLI arguments.
    """
    params: dict[str, Any] = {}
    if args.query:
        params["query"] = args.query

    schedules = _client.get_paginated("/schedules", "schedules", params=params)
    print(f"{len(schedules)} schedule(s)\n", file=sys.stderr)

    for sched in schedules:
        print(f"[{sched.get('id')}] {sched.get('name', '')}")


def cmd_schedule(args: argparse.Namespace) -> None:
    """Get a schedule with its rendered on-call rotation for a time window.

    Args:
        args: Parsed CLI arguments (requires ``args.id``).
    """
    params: dict[str, Any] = {}
    if args.since:
        params["since"] = args.since
    if args.until:
        params["until"] = args.until

    data = _client.get(f"/schedules/{args.id}", params=params)
    _print_json(data.get("schedule", data))


def cmd_services(args: argparse.Namespace) -> None:
    """List services with their owning teams, optionally filtered.

    Args:
        args: Parsed CLI arguments.
    """
    params: dict[str, Any] = {
        "include[]": args.include if args.include else ["teams"]
    }
    if args.query:
        params["query"] = args.query
    if args.team:
        params["team_ids[]"] = args.team

    services = _client.get_paginated("/services", "services", params=params)
    print(f"{len(services)} service(s)\n", file=sys.stderr)

    for svc in services:
        teams = [t.get("summary", "") for t in (svc.get("teams") or [])]
        team_str = f"  [{', '.join(teams)}]" if teams else ""
        print(f"[{svc.get('id')}] {svc.get('name', '')}{team_str}")


def cmd_service(args: argparse.Namespace) -> None:
    """Get a single service with integrations and team detail.

    Args:
        args: Parsed CLI arguments (requires ``args.id``).
    """
    data = _client.get(
        f"/services/{args.id}",
        params={"include[]": ["integrations", "teams"]},
    )
    _print_json(data.get("service", data))


def cmd_teams(args: argparse.Namespace) -> None:
    """List all teams, optionally filtered by name.

    Args:
        args: Parsed CLI arguments.
    """
    params: dict[str, Any] = {}
    if args.query:
        params["query"] = args.query

    teams = _client.get_paginated("/teams", "teams", params=params)
    print(f"{len(teams)} team(s)\n", file=sys.stderr)

    for team in teams:
        print(f"[{team.get('id')}] {team.get('name', '')}")


def cmd_team_members(args: argparse.Namespace) -> None:
    """List members of a specific team.

    Args:
        args: Parsed CLI arguments (requires ``args.id``).
    """
    data = _client.get(f"/teams/{args.id}/members")
    members = data.get("members", [])
    print(f"{len(members)} member(s)\n", file=sys.stderr)

    for member in members:
        user = member.get("user", {})
        role = member.get("role", "")
        print(f"[{user.get('id')}] {user.get('summary', '')}  role={role}")


def cmd_escalation_policies(args: argparse.Namespace) -> None:
    """List escalation policies, optionally filtered by name or team.

    Args:
        args: Parsed CLI arguments.
    """
    params: dict[str, Any] = {"include[]": ["targets", "teams"]}
    if args.query:
        params["query"] = args.query
    if args.team:
        params["team_ids[]"] = args.team

    policies = _client.get_paginated(
        "/escalation_policies", "escalation_policies", params=params
    )
    print(f"{len(policies)} escalation policy(ies)\n", file=sys.stderr)

    for pol in policies:
        teams = [t.get("summary", "") for t in (pol.get("teams") or [])]
        team_str = f"  [{', '.join(teams)}]" if teams else ""
        print(f"[{pol.get('id')}] {pol.get('name', '')}{team_str}")


def cmd_escalation_policy(args: argparse.Namespace) -> None:
    """Get a single escalation policy with targets, teams, and services.

    Args:
        args: Parsed CLI arguments (requires ``args.id``).
    """
    data = _client.get(
        f"/escalation_policies/{args.id}",
        params={"include[]": ["targets", "teams", "services"]},
    )
    _print_json(data.get("escalation_policy", data))


def cmd_users(args: argparse.Namespace) -> None:
    """List users, optionally filtered by name, email, or team.

    Args:
        args: Parsed CLI arguments.
    """
    params: dict[str, Any] = {}
    if args.query:
        params["query"] = args.query
    if args.team:
        params["team_ids[]"] = args.team
    if args.include:
        params["include[]"] = args.include

    users = _client.get_paginated("/users", "users", params=params)
    print(f"{len(users)} user(s)\n", file=sys.stderr)

    for user in users:
        teams = [t.get("summary", "") for t in (user.get("teams") or [])]
        team_str = f"  [{', '.join(teams)}]" if teams else ""
        print(
            f"[{user.get('id')}] {user.get('name', '')}"
            f"  {user.get('email', '')}{team_str}"
        )


def cmd_user(args: argparse.Namespace) -> None:
    """Get a single user with contact methods, notification rules, and teams.

    Args:
        args: Parsed CLI arguments (requires ``args.id``).
    """
    data = _client.get(
        f"/users/{args.id}",
        params={"include[]": ["contact_methods", "notification_rules", "teams"]},
    )
    _print_json(data.get("user", data))


# ---------------------------------------------------------------------------
# Argument parser
# ---------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    """Build and return the top-level argument parser.

    Returns:
        A fully configured ArgumentParser with all subcommands registered.
    """
    parser = argparse.ArgumentParser(
        prog="pd_cli.py",
        description=(
            "Read-only PagerDuty CLI for Roblox's PagerDuty instance."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="command", metavar="COMMAND")

    # --- incidents ---
    p = sub.add_parser("incidents", help="List incidents")
    p.add_argument(
        "--status",
        action="append",
        metavar="STATUS",
        choices=["triggered", "acknowledged", "resolved"],
        help=(
            "Filter by status (repeatable). "
            "Defaults to triggered + acknowledged when omitted."
        ),
    )
    p.add_argument(
        "--urgency",
        action="append",
        metavar="URGENCY",
        choices=["high", "low"],
        help="Filter by urgency (repeatable).",
    )
    p.add_argument(
        "--service",
        action="append",
        metavar="SERVICE_ID",
        help="Filter by service ID (repeatable).",
    )
    p.add_argument(
        "--team",
        action="append",
        metavar="TEAM_ID",
        help="Filter by team ID (repeatable).",
    )
    p.add_argument(
        "--since", metavar="ISO8601", help="Start of date range."
    )
    p.add_argument(
        "--until", metavar="ISO8601", help="End of date range."
    )
    p.add_argument(
        "--include",
        action="append",
        metavar="RESOURCE",
        help="Sideload extra data, e.g. services, teams, users.",
    )
    p.add_argument(
        "--limit",
        type=int,
        default=25,
        help="Maximum results to return (default: 25).",
    )

    # --- incident ---
    p = sub.add_parser("incident", help="Get a single incident by ID")
    p.add_argument("id", type=_validated_id, help="Incident ID (e.g. P1ABC23)")

    # --- incident-alerts ---
    p = sub.add_parser("incident-alerts", help="List alerts for an incident")
    p.add_argument("id", type=_validated_id, help="Incident ID")

    # --- incident-log ---
    p = sub.add_parser(
        "incident-log", help="Show the timeline event log for an incident"
    )
    p.add_argument("id", type=_validated_id, help="Incident ID")

    # --- oncalls ---
    p = sub.add_parser("oncalls", help="List current on-call entries")
    p.add_argument(
        "--service-name",
        metavar="NAME",
        help=(
            "Resolve on-call by service name (e.g. 'sapi-authorization'). "
            "Looks up the service, finds its escalation policy, and queries "
            "on-calls automatically — no need to find IDs manually."
        ),
    )
    p.add_argument(
        "--schedule",
        action="append",
        metavar="SCHEDULE_ID",
        help="Filter by schedule ID (repeatable).",
    )
    p.add_argument(
        "--policy",
        action="append",
        metavar="POLICY_ID",
        help="Filter by escalation policy ID (repeatable).",
    )
    p.add_argument(
        "--since", metavar="ISO8601", help="Start of the on-call window."
    )
    p.add_argument(
        "--until", metavar="ISO8601", help="End of the on-call window."
    )

    # --- schedules ---
    p = sub.add_parser("schedules", help="List on-call schedules")
    p.add_argument(
        "--query", "-q", metavar="NAME", help="Filter by name substring."
    )

    # --- schedule ---
    p = sub.add_parser(
        "schedule", help="Get a schedule with its rendered rotation"
    )
    p.add_argument("id", type=_validated_id, help="Schedule ID")
    p.add_argument(
        "--since", metavar="ISO8601", help="Start of the render window."
    )
    p.add_argument(
        "--until", metavar="ISO8601", help="End of the render window."
    )

    # --- services ---
    p = sub.add_parser("services", help="List services")
    p.add_argument(
        "--query", "-q", metavar="NAME", help="Filter by name substring."
    )
    p.add_argument(
        "--team",
        action="append",
        metavar="TEAM_ID",
        help="Filter by team ID (repeatable).",
    )
    p.add_argument(
        "--include",
        action="append",
        metavar="RESOURCE",
        help="Sideload extra data, e.g. escalation_policies, teams.",
    )

    # --- service ---
    p = sub.add_parser("service", help="Get a single service by ID")
    p.add_argument("id", type=_validated_id, help="Service ID")

    # --- teams ---
    p = sub.add_parser("teams", help="List teams")
    p.add_argument(
        "--query", "-q", metavar="NAME", help="Filter by name substring."
    )

    # --- team-members ---
    p = sub.add_parser("team-members", help="List members of a team")
    p.add_argument("id", type=_validated_id, help="Team ID")

    # --- escalation-policies ---
    p = sub.add_parser("escalation-policies", help="List escalation policies")
    p.add_argument(
        "--query", "-q", metavar="NAME", help="Filter by name substring."
    )
    p.add_argument(
        "--team",
        action="append",
        metavar="TEAM_ID",
        help="Filter by team ID (repeatable).",
    )

    # --- escalation-policy ---
    p = sub.add_parser(
        "escalation-policy", help="Get a single escalation policy by ID"
    )
    p.add_argument("id", type=_validated_id, help="Escalation policy ID")

    # --- users ---
    p = sub.add_parser("users", help="List users")
    p.add_argument(
        "--query",
        "-q",
        metavar="NAME_OR_EMAIL",
        help="Filter by name or email substring.",
    )
    p.add_argument(
        "--team",
        action="append",
        metavar="TEAM_ID",
        help="Filter by team ID (repeatable).",
    )
    p.add_argument(
        "--include",
        action="append",
        metavar="RESOURCE",
        help=(
            "Sideload extra data, e.g. contact_methods, "
            "notification_rules, teams."
        ),
    )

    # --- user ---
    p = sub.add_parser("user", help="Get a single user by ID")
    p.add_argument("id", type=_validated_id, help="User ID")

    return parser


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

_COMMAND_HANDLERS = {
    "incidents": cmd_incidents,
    "incident": cmd_incident,
    "incident-alerts": cmd_incident_alerts,
    "incident-log": cmd_incident_log,
    "oncalls": cmd_oncalls,
    "schedules": cmd_schedules,
    "schedule": cmd_schedule,
    "services": cmd_services,
    "service": cmd_service,
    "teams": cmd_teams,
    "team-members": cmd_team_members,
    "escalation-policies": cmd_escalation_policies,
    "escalation-policy": cmd_escalation_policy,
    "users": cmd_users,
    "user": cmd_user,
}


def main() -> None:
    """Parse arguments and dispatch to the appropriate command handler."""
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
