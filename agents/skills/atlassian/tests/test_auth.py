# /// script
# requires-python = ">=3.10"
# dependencies = ["pytest"]
# ///
"""Tests for the cache-preference helper in auth.py.

Run with:  uv run pytest skills/atlassian/tests/
"""
from __future__ import annotations

import importlib.util
import sys
import types
from pathlib import Path

import pytest


def _load_module():
    # Stub rbx_skills_auth so importing auth.py doesn't try to set up a real
    # CredentialBrokerAuth (which would touch the filesystem / network).
    stub = types.ModuleType("rbx_skills_auth")

    class _StubBroker:
        def __init__(self, **_: object) -> None:
            pass

    stub.CredentialBrokerAuth = _StubBroker
    sys.modules["rbx_skills_auth"] = stub

    spec = importlib.util.spec_from_file_location(
        "auth_under_test",
        Path(__file__).parent.parent / "scripts" / "auth.py",
    )
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def auth_mod(monkeypatch):
    # Ensure ATLASSIAN_CLOUD_NAME isn't leaking in from the host environment.
    monkeypatch.delenv("ATLASSIAN_CLOUD_NAME", raising=False)
    return _load_module()


def test_prefers_roblox_when_no_override(auth_mod, monkeypatch):
    monkeypatch.delenv("ATLASSIAN_CLOUD_NAME", raising=False)
    assert auth_mod._cached_cloud_matches_preference("roblox") is True


def test_rejects_sandbox_when_no_override(auth_mod, monkeypatch):
    monkeypatch.delenv("ATLASSIAN_CLOUD_NAME", raising=False)
    assert auth_mod._cached_cloud_matches_preference("roblox-sandbox-748") is False


def test_rejects_partner_when_no_override(auth_mod, monkeypatch):
    monkeypatch.delenv("ATLASSIAN_CLOUD_NAME", raising=False)
    assert auth_mod._cached_cloud_matches_preference("roblox-partner") is False


def test_rejects_empty_cached_name(auth_mod, monkeypatch):
    monkeypatch.delenv("ATLASSIAN_CLOUD_NAME", raising=False)
    assert auth_mod._cached_cloud_matches_preference("") is False


def test_override_match_is_case_insensitive(auth_mod, monkeypatch):
    monkeypatch.setenv("ATLASSIAN_CLOUD_NAME", "Roblox-Partner")
    assert auth_mod._cached_cloud_matches_preference("roblox-partner") is True


def test_override_overrides_roblox_preference(auth_mod, monkeypatch):
    # With an override set, the cached "roblox" cloud should NOT be considered
    # a match for an override of e.g. "roblox-sandbox-748".
    monkeypatch.setenv("ATLASSIAN_CLOUD_NAME", "roblox-sandbox-748")
    assert auth_mod._cached_cloud_matches_preference("roblox") is False
    assert (
        auth_mod._cached_cloud_matches_preference("roblox-sandbox-748") is True
    )


def test_blank_override_falls_back_to_roblox_preference(auth_mod, monkeypatch):
    monkeypatch.setenv("ATLASSIAN_CLOUD_NAME", "   ")
    assert auth_mod._cached_cloud_matches_preference("roblox") is True
    assert auth_mod._cached_cloud_matches_preference("roblox-partner") is False
