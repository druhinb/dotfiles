"""Shared auth and HTTP client for Portal API scripts."""
import json
import sys
import requests
from pathlib import Path
from typing import Any, Union

from rbx_skills_auth import CredentialBrokerAuth

ROS_URL = "https://apis.simulprod.com/portal-ui-service/v1/ros"


def make_auth() -> CredentialBrokerAuth:
    return CredentialBrokerAuth(
        service_name="github_enterprise",
        display_name="Github Enterprise",
        cache_dir=Path.home() / ".cache" / "portal",
        connect_url="https://apis.simulprod.com/credential-broker/v1/connect/github_enterprise",
    )


def get_token(auth: CredentialBrokerAuth, force: bool = False) -> str:
    return auth.get_token(force_refresh=force)["access_token"]


def api_request(method: str, base_url: str, endpoint: str, auth: CredentialBrokerAuth, **kwargs: Any) -> Any:
    token = get_token(auth)
    url = f"{base_url}/{endpoint}"

    headers = kwargs.pop("headers", {})
    headers.setdefault("Content-Type", "application/json")
    headers.setdefault("Accept", "application/json")
    headers.setdefault("Authorization", f"Bearer {token}")

    params = kwargs.pop("params", {})

    response = requests.request(method, url, headers=headers, params=params, **kwargs)

    if not response.ok:
        try:
            error_msg = response.json().get("message", response.text)
        except (json.JSONDecodeError, KeyError):
            error_msg = response.text
        print(f"Error ({response.status_code}): {error_msg}", file=sys.stderr)
        sys.exit(1)

    if response.status_code == 204:
        return {}

    return response.json()


def get_ros_employee(identifier: Union[str, int], auth: CredentialBrokerAuth) -> dict:
    return api_request("GET", ROS_URL, f"employees/{identifier}", auth)["data"]["employee"]


def resolve_ros_id(identifier: Union[str, int], auth: CredentialBrokerAuth) -> int:
    try:
        return int(identifier)
    except (ValueError, TypeError):
        return get_ros_employee(identifier, auth)["id"]
