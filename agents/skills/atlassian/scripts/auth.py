"""Atlassian credential manager for devspace skills.

Thin wrapper around the shared credential-broker auth engine.  Tokens are
cached locally in ``~/.cache/atlassian/token_cache.json``.

In addition to the standard broker flow, this module discovers the Atlassian
Cloud ID needed to construct API URLs.

Credentials are NEVER printed to stdout; only status/error messages go to
stderr.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import requests

from rbx_skills_auth import CredentialBrokerAuth

_BROKER_CONNECT_URL = (
    "https://apis.simulprod.com/credential-broker/v1/connect/atlassian"
)
_CLOUD_RESOURCES_URL = (
    "https://api.atlassian.com/oauth/token/accessible-resources"
)

_CACHE_DIR = Path.home() / ".cache" / "atlassian"

_auth = CredentialBrokerAuth(
    service_name="atlassian",
    display_name="Atlassian",
    cache_dir=_CACHE_DIR,
    connect_url=_BROKER_CONNECT_URL,
)


def _discover_cloud_id(access_token: str) -> tuple[str, str]:
    """Return ``(cloud_id, cloud_name)`` from the accessible-resources endpoint.

    Selection order:
    1. ``ATLASSIAN_CLOUD_NAME`` env var — exact name match (case-insensitive).
    2. Cloud named exactly ``"roblox"`` — the main Roblox production instance.
       The credential broker's OAuth app is registered in ``roblox-partner``,
       so Atlassian returns that cloud first in the accessible-resources list.
       Preferring ``"roblox"`` corrects for this ordering without any user
       configuration.
    3. First entry in the accessible-resources list (original behaviour).

    Args:
        access_token: A valid Atlassian OAuth access token.

    Returns:
        A tuple of ``(cloud_id, cloud_name)`` for the selected cloud.

    Raises:
        SystemExit: If the request fails or no resources are found.
    """
    resp = requests.get(
        _CLOUD_RESOURCES_URL,
        headers={"Authorization": f"Bearer {access_token}"},
        timeout=30,
    )
    if not resp.ok:
        print(
            "Error: Failed to discover Atlassian cloud ID: "
            f"HTTP {resp.status_code}",
            file=sys.stderr,
        )
        sys.exit(1)
    resources = resp.json()
    if not resources:
        print(
            "Error: No accessible Atlassian resources found. "
            "Check that your account has access to at least one "
            "cloud instance.",
            file=sys.stderr,
        )
        sys.exit(1)

    # 1. Explicit override via env var.
    cloud_name_override = os.environ.get("ATLASSIAN_CLOUD_NAME", "").strip()
    if cloud_name_override:
        for r in resources:
            if r["name"].lower() == cloud_name_override.lower():
                return r["id"], r["name"]
        print(
            f"Warning: ATLASSIAN_CLOUD_NAME={cloud_name_override!r} did not "
            "match any accessible cloud. Available: "
            + ", ".join(r["name"] for r in resources),
            file=sys.stderr,
        )

    # 2. Prefer the main "roblox" production cloud over "roblox-partner".
    for r in resources:
        if r["name"] == "roblox":
            return r["id"], r["name"]

    # 3. Fall back to whatever Atlassian returns first.
    return resources[0]["id"], resources[0]["name"]


def _cached_cloud_matches_preference(cloud_name: str) -> bool:
    """Return True if a cached ``cloud_name`` satisfies the current selection rules.

    Mirrors :func:`_discover_cloud_id` so cache entries written by older
    versions of this module — which always returned ``resources[0]`` and
    therefore could pin a sandbox/partner cloud — are invalidated on the
    next call and re-discovered exactly once.
    """
    override = os.environ.get("ATLASSIAN_CLOUD_NAME", "").strip()
    if override:
        return cloud_name.lower() == override.lower()
    return cloud_name == "roblox"


def get_credentials(force_refresh: bool = False) -> tuple[str, str]:
    """Return ``(access_token, cloud_id)`` for Atlassian API calls.

    Loads from cache when the token is still valid; otherwise runs the
    full GHE → LCA → broker flow and re-caches the result.

    Args:
        force_refresh: Bypass the cache and always fetch a new token.

    Returns:
        A tuple of ``(access_token, cloud_id)`` — never printed to
        stdout.

    Raises:
        SystemExit: If any step in the auth chain fails.  Exit code 2
            means Atlassian OAuth has not been connected yet.
    """
    # Grab cloud_id/cloud_name before get_token overwrites the cache with
    # only {access_token, expires_at}.
    prior_cache = _auth._load_cache()  # noqa: SLF001
    prior_cloud_id = prior_cache.get("cloud_id")
    prior_cloud_name = prior_cache.get("cloud_name", "")

    token_data = _auth.get_token(force_refresh=force_refresh)
    access_token: str = token_data["access_token"]

    # Reuse the cached cloud only if it still satisfies the current selection
    # rules. Older versions of this module cached whichever cloud the
    # accessible-resources endpoint returned first, which could pin a
    # sandbox/partner cloud; re-discover in that case.
    if (
        not force_refresh
        and prior_cloud_id
        and _cached_cloud_matches_preference(prior_cloud_name)
    ):
        return access_token, prior_cloud_id

    cloud_id, cloud_name = _discover_cloud_id(access_token)

    # Persist cloud_id alongside the token so future calls skip discovery.
    updated = _auth._load_cache()  # noqa: SLF001
    updated.update({"cloud_id": cloud_id, "cloud_name": cloud_name})
    _auth._save_cache(updated)  # noqa: SLF001

    print(f"Connected to Atlassian cloud: {cloud_name}", file=sys.stderr)
    return access_token, cloud_id
