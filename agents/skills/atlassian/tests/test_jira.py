# /// script
# requires-python = ">=3.10"
# dependencies = ["pytest"]
# ///
"""Tests for jira_cli.py: every command in both `--json` and human mode, the
JiraClient HTTP wrapper, and the error formatter.

`--json` is meant to convey the same information as the human view, just
structured, so a command must perform the same fetches in both modes and only
the formatting differs. Command tests use a fake Jira client (no network);
JiraClient tests fake `requests.request` (no network, no auth).

Run with:  uv run pytest skills/atlassian/tests/
"""
from __future__ import annotations

import importlib.util
import json
import sys
import types
from pathlib import Path

import pytest


# ---------------------------------------------------------------------------
# Load jira_cli with a stubbed auth module so import triggers no network/auth
# ---------------------------------------------------------------------------

def _load_module():
    stub = types.ModuleType("auth")
    stub.get_credentials = lambda **_: ("token", "cloud-id")
    sys.modules.setdefault("auth", stub)

    spec = importlib.util.spec_from_file_location(
        "jira_cli",
        Path(__file__).parent.parent / "scripts" / "jira_cli.py",
    )
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_mod = _load_module()


# ---------------------------------------------------------------------------
# Fake Jira client: exact (method, path) match. Exact (not substring) matters
# because /issue/PROJ-1 is a prefix of /issue/PROJ-1/transitions.
# ---------------------------------------------------------------------------

class FakeClient:
    def __init__(self, responses: dict[tuple[str, str], object]) -> None:
        self._responses = responses
        self.calls: list[tuple[str, str]] = []
        self.records: list[dict] = []

    def call(self, method, path, *, params=None, body=None, allow_empty=False):
        self.calls.append((method, path))
        self.records.append(
            {"method": method, "path": path, "params": params, "body": body})
        try:
            return self._responses[(method, path)]
        except KeyError:
            raise AssertionError(f"unexpected call: {method} {path}")

    def paths(self) -> list[str]:
        return [p for _, p in self.calls]


@pytest.fixture
def fake_client(monkeypatch):
    def _install(responses):
        client = FakeClient(responses)
        monkeypatch.setattr(_mod, "_client", client)
        return client
    return _install


def out_json(capsys):
    return json.loads(capsys.readouterr().out)


# ===========================================================================
# search
# ===========================================================================

def test_search_json_is_raw_payload_with_labels(fake_client, capsys):
    payload = {"total": 1, "issues": [
        {"key": "PROJ-1", "fields": {
            "summary": "S", "priority": {"name": "P2"}, "labels": ["a", "b"]}}]}
    fake_client({("GET", "/rest/api/3/search/jql"): payload})
    _mod.cmd_search("project = PROJ", 25, "summary,priority,labels", json_output=True)
    assert out_json(capsys) == payload


def test_search_human_renders_rows_and_priority(fake_client, capsys):
    payload = {"total": 1, "issues": [
        {"key": "PROJ-1", "fields": {
            "summary": "S", "status": {"name": "Open"},
            "assignee": {"displayName": "Jo"}, "priority": {"name": "P2"}}}]}
    fake_client({("GET", "/rest/api/3/search/jql"): payload})
    _mod.cmd_search("project = PROJ", 25, "summary,status,assignee,priority")
    out = capsys.readouterr().out
    assert "[PROJ-1] S" in out
    assert "Status: Open | Assignee: Jo | Priority: P2" in out


def test_search_human_omits_priority_when_absent_and_defaults(fake_client, capsys):
    payload = {"total": 1, "issues": [
        {"key": "PROJ-1", "fields": {"summary": "S"}}]}  # no status/assignee/priority
    fake_client({("GET", "/rest/api/3/search/jql"): payload})
    _mod.cmd_search("project = PROJ", 25, "summary", json_output=False)
    out = capsys.readouterr().out
    assert "Status: ? | Assignee: Unassigned" in out
    assert "Priority:" not in out


def test_search_human_empty(fake_client, capsys):
    fake_client({("GET", "/rest/api/3/search/jql"): {"total": 0, "issues": []}})
    _mod.cmd_search("project = NONE", 25, "summary")
    assert "Showing 0 of 0" in capsys.readouterr().out


# ===========================================================================
# get
# ===========================================================================

_GET_RESPONSES = {
    ("GET", "/rest/api/3/issue/PROJ-1"): {
        "key": "PROJ-1",
        "fields": {
            "summary": "S", "issuetype": {"name": "Bug"},
            "status": {"name": "Open"}, "priority": {"name": "P2"},
            "assignee": {"displayName": "Jo"}, "labels": ["x", "y"],
            "description": {"type": "doc", "version": 1, "content": [
                {"type": "paragraph", "content": [{"type": "text", "text": "Hello"}]}]},
            "comment": {"comments": [
                {"author": {"displayName": "Al"}, "created": "2026-06-18T00:00:00.000+0000",
                 "body": {"type": "doc", "version": 1, "content": [
                     {"type": "paragraph", "content": [{"type": "text", "text": "Note"}]}]}}]},
        },
    },
    ("GET", "/rest/api/3/issue/PROJ-1/transitions"): {
        "transitions": [{"id": "31", "name": "In Review"}]},
}


def test_get_json_includes_issue_and_transitions(fake_client, capsys):
    client = fake_client(_GET_RESPONSES)
    _mod.cmd_get("PROJ-1", json_output=True)
    out = out_json(capsys)
    assert out["fields"]["labels"] == ["x", "y"]
    assert [t["name"] for t in out["transitions"]] == ["In Review"]
    assert "/rest/api/3/issue/PROJ-1" in client.paths()
    assert "/rest/api/3/issue/PROJ-1/transitions" in client.paths()


def test_get_human_renders_all_sections(fake_client, capsys):
    fake_client(_GET_RESPONSES)
    _mod.cmd_get("PROJ-1")
    out = capsys.readouterr().out
    assert "Key:      PROJ-1" in out
    assert "Type:     Bug" in out
    assert "Labels:   x, y" in out
    assert "Description:" in out and "Hello" in out
    assert "Comments (1):" in out and "Note" in out
    assert "Available transitions: In Review" in out


def test_get_human_omits_optional_sections_when_absent(fake_client, capsys):
    responses = {
        ("GET", "/rest/api/3/issue/PROJ-2"): {"key": "PROJ-2", "fields": {"summary": "S"}},
        ("GET", "/rest/api/3/issue/PROJ-2/transitions"): {"transitions": []},
    }
    fake_client(responses)
    _mod.cmd_get("PROJ-2")
    out = capsys.readouterr().out
    assert "Priority: None" in out          # default when missing
    assert "Assignee: Unassigned" in out
    assert "Labels:" not in out
    assert "Description:" not in out
    assert "Comments" not in out
    assert "Available transitions:" not in out


def test_get_same_fetches_in_both_modes(fake_client):
    human = fake_client(_GET_RESPONSES)
    _mod.cmd_get("PROJ-1")
    js = fake_client(_GET_RESPONSES)
    _mod.cmd_get("PROJ-1", json_output=True)
    assert sorted(human.calls) == sorted(js.calls)


# ===========================================================================
# create
# ===========================================================================

def test_create_json_returns_response(fake_client, capsys):
    fake_client({("POST", "/rest/api/3/issue"): {"id": "100", "key": "PROJ-9"}})
    _mod.cmd_create("PROJ", "Task", "Sum", "", None, None, None, None, json_output=True)
    assert out_json(capsys) == {"id": "100", "key": "PROJ-9"}


def test_create_human_prints_key_and_id(fake_client, capsys):
    fake_client({("POST", "/rest/api/3/issue"): {"id": "100", "key": "PROJ-9"}})
    _mod.cmd_create("PROJ", "Task", "Sum", "", None, None, None, None)
    out = capsys.readouterr().out
    assert "Created: PROJ-9" in out
    assert "ID:      100" in out


def test_create_builds_body_fields(fake_client):
    client = fake_client({("POST", "/rest/api/3/issue"): {"id": "1", "key": "PROJ-1"}})
    _mod.cmd_create("PROJ", "Bug", "Sum", "desc", "High", ["l1", "l2"],
                    "PROJ-100", ["customfield_1=55"])
    body = client.records[0]["body"]["fields"]
    assert body["project"] == {"key": "PROJ"}
    assert body["issuetype"] == {"name": "Bug"}
    assert body["priority"] == {"name": "High"}
    assert body["labels"] == ["l1", "l2"]
    assert body["parent"] == {"key": "PROJ-100"}
    assert body["customfield_1"] == {"id": "55"}


def test_create_bad_custom_field_exits(fake_client):
    fake_client({})  # must not be called
    with pytest.raises(SystemExit):
        _mod.cmd_create("PROJ", "Task", "S", "", None, None, None, ["nope"])


# ===========================================================================
# update
# ===========================================================================

def test_update_json_reports_changed_values(fake_client, capsys):
    fake_client({("PUT", "/rest/api/3/issue/PROJ-1"): {}})
    _mod.cmd_update("PROJ-1", summary=None, description=None,
                    priority=None, labels=["a", "b"], json_output=True)
    assert out_json(capsys) == {"key": "PROJ-1", "updated": {"labels": ["a", "b"]}}


def test_update_json_renders_priority_name_and_description_marker(fake_client, capsys):
    fake_client({("PUT", "/rest/api/3/issue/PROJ-1"): {}})
    _mod.cmd_update("PROJ-1", summary="New", description="body",
                    priority="High", labels=None, json_output=True)
    out = out_json(capsys)["updated"]
    assert out["summary"] == "New"
    assert out["priority"] == "High"          # {"name": "High"} -> "High"
    assert out["description"] == "(updated)"  # ADF elided, mirrors text mode


def test_update_human_prints_fields(fake_client, capsys):
    fake_client({("PUT", "/rest/api/3/issue/PROJ-1"): {}})
    _mod.cmd_update("PROJ-1", summary=None, description=None,
                    priority="Low", labels=None)
    out = capsys.readouterr().out
    assert "Updated PROJ-1" in out
    assert "priority: Low" in out


def test_update_builds_description_adf(fake_client):
    client = fake_client({("PUT", "/rest/api/3/issue/PROJ-1"): {}})
    _mod.cmd_update("PROJ-1", summary=None, description="hi",
                    priority=None, labels=None)
    body = client.records[0]["body"]["fields"]
    assert body["description"]["type"] == "doc"   # converted to ADF


def test_update_no_fields_exits(fake_client):
    fake_client({})  # must not be called
    with pytest.raises(SystemExit):
        _mod.cmd_update("PROJ-1", summary=None, description=None,
                        priority=None, labels=None)


# ===========================================================================
# comment
# ===========================================================================

def test_comment_json_returns_response(fake_client, capsys):
    fake_client({("POST", "/rest/api/3/issue/PROJ-1/comment"): {"id": "10001"}})
    _mod.cmd_comment("PROJ-1", "hello", json_output=True)
    assert out_json(capsys) == {"id": "10001"}


def test_comment_human(fake_client, capsys):
    fake_client({("POST", "/rest/api/3/issue/PROJ-1/comment"): {"id": "10001"}})
    _mod.cmd_comment("PROJ-1", "hello")
    assert "Comment added to PROJ-1" in capsys.readouterr().out


def test_comment_body_is_adf(fake_client):
    client = fake_client({("POST", "/rest/api/3/issue/PROJ-1/comment"): {"id": "1"}})
    _mod.cmd_comment("PROJ-1", "hello")
    assert client.records[0]["body"]["body"]["type"] == "doc"


# ===========================================================================
# transitions (list)
# ===========================================================================

_TRANSITIONS_RESPONSES = {
    ("GET", "/rest/api/3/issue/PROJ-1/transitions"): {
        "transitions": [{"id": "31", "name": "In Review", "to": {"name": "In Review"}}]},
    ("GET", "/rest/api/3/issue/PROJ-1"): {"fields": {"status": {"name": "Open"}}},
}


def test_transitions_json_includes_current_status(fake_client, capsys):
    fake_client(_TRANSITIONS_RESPONSES)
    _mod.cmd_transitions("PROJ-1", json_output=True)
    out = out_json(capsys)
    assert out["currentStatus"] == "Open"
    assert [t["name"] for t in out["transitions"]] == ["In Review"]


def test_transitions_human(fake_client, capsys):
    fake_client(_TRANSITIONS_RESPONSES)
    _mod.cmd_transitions("PROJ-1")
    out = capsys.readouterr().out
    assert "Current status: Open" in out
    assert "[31] In Review → In Review" in out


def test_transitions_same_fetches_in_both_modes(fake_client):
    human = fake_client(_TRANSITIONS_RESPONSES)
    _mod.cmd_transitions("PROJ-1")
    js = fake_client(_TRANSITIONS_RESPONSES)
    _mod.cmd_transitions("PROJ-1", json_output=True)
    assert sorted(human.calls) == sorted(js.calls)


# ===========================================================================
# transition (action)
# ===========================================================================

def test_transition_json(fake_client, capsys):
    fake_client({
        ("GET", "/rest/api/3/issue/PROJ-1/transitions"):
            {"transitions": [{"id": "31", "name": "In Review"}]},
        ("POST", "/rest/api/3/issue/PROJ-1/transitions"): {},
    })
    _mod.cmd_transition("PROJ-1", "in review", json_output=True)  # case-insensitive
    assert out_json(capsys) == {"key": "PROJ-1", "transition": "In Review"}


def test_transition_human(fake_client, capsys):
    fake_client({
        ("GET", "/rest/api/3/issue/PROJ-1/transitions"):
            {"transitions": [{"id": "31", "name": "In Review"}]},
        ("POST", "/rest/api/3/issue/PROJ-1/transitions"): {},
    })
    _mod.cmd_transition("PROJ-1", "In Review")
    assert "Transitioned PROJ-1" in capsys.readouterr().out


def test_transition_unknown_name_exits(fake_client, capsys):
    fake_client({("GET", "/rest/api/3/issue/PROJ-1/transitions"):
                 {"transitions": [{"id": "31", "name": "In Review"}]}})
    with pytest.raises(SystemExit):
        _mod.cmd_transition("PROJ-1", "Nonexistent")
    assert "not available" in capsys.readouterr().err


# ===========================================================================
# assign  (BuilderAI regression: self-assign --json must not emit prose)
# ===========================================================================

def test_assign_self_json_is_pure_json(fake_client, capsys):
    fake_client({
        ("GET", "/rest/api/3/myself"): {"accountId": "abc", "displayName": "Me"},
        ("PUT", "/rest/api/3/issue/PROJ-1/assignee"): {},
    })
    _mod.cmd_assign("PROJ-1", None, json_output=True)
    # The whole of stdout must parse as JSON — no "Assigning…" prose leaks in.
    assert out_json(capsys) == {"key": "PROJ-1", "assignee": "abc"}


def test_assign_self_human_prints_progress(fake_client, capsys):
    fake_client({
        ("GET", "/rest/api/3/myself"): {"accountId": "abc", "displayName": "Me"},
        ("PUT", "/rest/api/3/issue/PROJ-1/assignee"): {},
    })
    _mod.cmd_assign("PROJ-1", None)
    out = capsys.readouterr().out
    assert "Assigning PROJ-1 to Me" in out
    assert "Assigned PROJ-1 to accountId=abc" in out


def test_assign_explicit_account_json(fake_client, capsys):
    fake_client({("PUT", "/rest/api/3/issue/PROJ-1/assignee"): {}})
    _mod.cmd_assign("PROJ-1", "xyz", json_output=True)
    assert out_json(capsys) == {"key": "PROJ-1", "assignee": "xyz"}
    # explicit account id must not trigger a /myself lookup


# ===========================================================================
# projects / myself / boards / sprints / sprint-issues
# ===========================================================================

def test_projects_json_and_human(fake_client, capsys):
    payload = {"total": 1, "values": [
        {"key": "PROJ", "name": "Project", "projectTypeKey": "software"}]}
    fake_client({("GET", "/rest/api/3/project/search"): payload})
    _mod.cmd_projects(None, 50, json_output=True)
    assert out_json(capsys) == payload

    fake_client({("GET", "/rest/api/3/project/search"): payload})
    _mod.cmd_projects("Pro", 50)
    assert "[PROJ] Project" in capsys.readouterr().out


def test_projects_query_forwarded_to_params(fake_client):
    client = fake_client({("GET", "/rest/api/3/project/search"):
                          {"total": 0, "values": []}})
    _mod.cmd_projects("Platform", 20)
    assert client.records[0]["params"]["query"] == "Platform"


def test_myself_json_and_human(fake_client, capsys):
    payload = {"displayName": "X", "emailAddress": "x@roblox.com",
               "accountId": "1", "timeZone": "UTC"}
    fake_client({("GET", "/rest/api/3/myself"): payload})
    _mod.cmd_myself(json_output=True)
    assert out_json(capsys)["emailAddress"] == "x@roblox.com"

    fake_client({("GET", "/rest/api/3/myself"): payload})
    _mod.cmd_myself()
    assert "Display name: X" in capsys.readouterr().out


def test_boards_json_and_human(fake_client, capsys):
    payload = {"total": 1, "values": [{"id": 5, "name": "Board", "type": "scrum"}]}
    fake_client({("GET", "/rest/agile/1.0/board"): payload})
    _mod.cmd_boards(None, None, 50, json_output=True)
    assert out_json(capsys) == payload

    fake_client({("GET", "/rest/agile/1.0/board"): payload})
    _mod.cmd_boards("PROJ", "scrum", 50)
    assert "[5] Board  type=scrum" in capsys.readouterr().out


def test_sprints_json_and_human(fake_client, capsys):
    payload = {"total": 1, "values": [
        {"id": 9, "name": "Sprint 1", "state": "active",
         "startDate": "2026-06-01T00:00:00Z", "endDate": "2026-06-14T00:00:00Z"}]}
    fake_client({("GET", "/rest/agile/1.0/board/42/sprint"): payload})
    _mod.cmd_sprints(42, "active", 25, json_output=True)
    assert out_json(capsys) == payload

    fake_client({("GET", "/rest/agile/1.0/board/42/sprint"): payload})
    _mod.cmd_sprints(42, None, 25)
    assert "[9] Sprint 1  state=active" in capsys.readouterr().out


def test_sprint_issues_json_and_human(fake_client, capsys):
    payload = {"total": 1, "issues": [
        {"key": "PROJ-1", "fields": {"summary": "S", "status": {"name": "Open"},
                                     "assignee": {"displayName": "Jo"}}}]}
    fake_client({("GET", "/rest/agile/1.0/sprint/9/issue"): payload})
    _mod.cmd_sprint_issues(9, "summary,status,assignee", 50, json_output=True)
    assert out_json(capsys) == payload

    fake_client({("GET", "/rest/agile/1.0/sprint/9/issue"): payload})
    _mod.cmd_sprint_issues(9, "summary,status,assignee", 50)
    assert "[PROJ-1] S" in capsys.readouterr().out


# ===========================================================================
# JiraClient HTTP wrapper  (fake requests.request, no network/auth)
# ===========================================================================

class FakeResponse:
    def __init__(self, status_code, json_data=None, content=b"{}", text="",
                 raise_json=False):
        self.status_code = status_code
        self.ok = 200 <= status_code < 300
        self._json = json_data
        self._raise_json = raise_json
        self.content = content
        self.text = text

    def json(self):
        if self._raise_json:
            raise ValueError("no json")
        return self._json


@pytest.fixture
def fake_requests(monkeypatch):
    def _install(responses):
        seq = iter(responses)
        calls: list[dict] = []

        def _request(method, url, **kwargs):
            calls.append({"method": method, "url": url, **kwargs})
            return next(seq)

        monkeypatch.setattr(_mod.requests, "request", _request)
        return calls
    return _install


def test_client_returns_json_on_ok(fake_requests):
    fake_requests([FakeResponse(200, {"ok": True})])
    client = _mod.JiraClient()
    assert client.call("GET", "/x") == {"ok": True}


def test_client_204_returns_empty(fake_requests):
    fake_requests([FakeResponse(204, content=b"")])
    client = _mod.JiraClient()
    assert client.call("DELETE", "/x") == {}


def test_client_allow_empty_with_no_content(fake_requests):
    fake_requests([FakeResponse(200, content=b"")])
    client = _mod.JiraClient()
    assert client.call("PUT", "/x", allow_empty=True) == {}


def test_client_error_exits_and_reports(fake_requests, capsys):
    fake_requests([FakeResponse(400, {"errorMessages": ["bad jql"]}, text="bad")])
    client = _mod.JiraClient()
    with pytest.raises(SystemExit):
        client.call("GET", "/x")
    assert "bad jql" in capsys.readouterr().err


def test_client_retries_once_on_401(fake_requests, monkeypatch):
    refreshes = []
    monkeypatch.setattr(_mod, "get_credentials",
                        lambda **kw: (refreshes.append(kw), ("t", "c"))[1])
    calls = fake_requests([FakeResponse(401), FakeResponse(200, {"ok": True})])
    client = _mod.JiraClient()
    assert client.call("GET", "/x") == {"ok": True}
    assert len(calls) == 2                       # retried exactly once
    assert any(kw.get("force_refresh") for kw in refreshes)  # forced re-auth


# ===========================================================================
# _print_jira_error branches
# ===========================================================================

def test_print_error_uses_error_messages(capsys):
    _mod._print_jira_error(FakeResponse(400, {"errorMessages": ["m1"], "errors": {"f": "v"}}))
    err = capsys.readouterr().err
    assert "m1" in err and "f: v" in err


def test_print_error_falls_back_to_text(capsys):
    _mod._print_jira_error(FakeResponse(500, raise_json=True, text="boom"))
    assert "boom" in capsys.readouterr().err


# ===========================================================================
# argument parsing — --json on every subcommand
# ===========================================================================

@pytest.mark.parametrize("argv", [
    ["search", "x", "--json"],
    ["get", "PROJ-1", "--json"],
    ["create", "-p", "PROJ", "-t", "Task", "-s", "S", "--json"],
    ["update", "PROJ-1", "--labels", "a", "--json"],
    ["comment", "PROJ-1", "text", "--json"],
    ["transitions", "PROJ-1", "--json"],
    ["transition", "PROJ-1", "In Review", "--json"],
    ["assign", "PROJ-1", "--json"],
    ["projects", "--json"],
    ["myself", "--json"],
    ["boards", "--json"],
    ["sprints", "42", "--json"],
    ["sprint-issues", "9", "--json"],
])
def test_json_flag_parses_on_every_subcommand(argv):
    assert _mod.build_parser().parse_args(argv).json_output is True


def test_json_flag_defaults_false():
    assert _mod.build_parser().parse_args(["search", "x"]).json_output is False
