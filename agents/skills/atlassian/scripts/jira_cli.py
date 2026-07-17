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
"""
Jira CLI for Claude Code — Atlassian skill.

Authentication is handled automatically via the credential broker.
Tokens are cached in ~/.cache/atlassian/token_cache.json and refreshed
only when expired. Credentials are never printed to stdout.

Usage examples:
    # Search issues with JQL
    uv run jira_cli.py search "project = PROJ AND status = 'In Progress'"

    # Get a single issue
    uv run jira_cli.py get PROJ-123

    # Create an issue
    uv run jira_cli.py create --project PROJ --type Task --summary "Fix thing" \\
        --description "Longer description here"

    # Update fields
    uv run jira_cli.py update PROJ-123 --summary "New title" --priority High

    # Add a comment
    uv run jira_cli.py comment PROJ-123 "Work is done, see PR #456"

    # Transition state
    uv run jira_cli.py transition PROJ-123 "In Progress"

    # List available transitions
    uv run jira_cli.py transitions PROJ-123

    # Assign to self (or to someone else)
    uv run jira_cli.py assign PROJ-123
    uv run jira_cli.py assign PROJ-123 --to jsmith

    # List projects
    uv run jira_cli.py projects
    uv run jira_cli.py projects --query "Platform"

    # Current user info
    uv run jira_cli.py myself

    # Boards and sprints
    uv run jira_cli.py boards --project PROJ
    uv run jira_cli.py sprints 42
    uv run jira_cli.py sprints 42 --state active
    uv run jira_cli.py sprint-issues 101
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import requests

# ---------------------------------------------------------------------------
# Bootstrap: make auth module importable from the same directory
# ---------------------------------------------------------------------------
sys.path.insert(0, str(Path(__file__).parent))
from auth import get_credentials  # noqa: E402

# ---------------------------------------------------------------------------
# Jira API client
# ---------------------------------------------------------------------------

JIRA_BASE = "https://api.atlassian.com/ex/jira/{cloud_id}"


class JiraClient:
    """Thin wrapper around the Jira REST API with automatic token refresh."""

    def __init__(self) -> None:
        self._token: str | None = None
        self._cloud_id: str | None = None

    def _ensure_auth(self, force: bool = False) -> None:
        self._token, self._cloud_id = get_credentials(force_refresh=force)

    def _base(self) -> str:
        return JIRA_BASE.format(cloud_id=self._cloud_id)

    def request(
        self,
        method: str,
        path: str,
        *,
        params: dict | None = None,
        body: dict | None = None,
    ) -> requests.Response:
        """
        Make an authenticated request. Retries once on 401.

        path: relative to /ex/jira/{cloud_id}, e.g. '/rest/api/3/issue/PROJ-1'
        """
        if self._token is None:
            self._ensure_auth()

        headers: dict[str, str] = {
            "Authorization": f"Bearer {self._token}",
            "Accept": "application/json",
        }
        if body is not None:
            headers["Content-Type"] = "application/json"

        url = self._base() + path
        resp = requests.request(
            method,
            url,
            headers=headers,
            params=params,
            json=body,
            timeout=30,
        )

        if resp.status_code == 401:
            # Token may have expired mid-session — refresh once and retry
            self._ensure_auth(force=True)
            headers["Authorization"] = f"Bearer {self._token}"
            url = self._base() + path
            resp = requests.request(
                method,
                url,
                headers=headers,
                params=params,
                json=body,
                timeout=30,
            )

        return resp

    def call(
        self,
        method: str,
        path: str,
        *,
        params: dict | None = None,
        body: dict | None = None,
        allow_empty: bool = False,
    ) -> dict | list:
        """request() + error handling + JSON decode."""
        resp = self.request(method, path, params=params, body=body)

        if resp.status_code == 204 or (allow_empty and resp.status_code in (200, 201) and not resp.content):
            return {}

        if not resp.ok:
            _print_jira_error(resp)
            sys.exit(1)

        return resp.json()


_client = JiraClient()


def _emit_json(payload: Any) -> None:
    """Print a structured payload as JSON.

    A command switches to this (instead of human-readable text) when its
    json_output argument is True. Read commands emit the raw Jira REST
    response; mutation commands emit a compact result object. The default stays
    human-readable, so existing text-consuming callers are unaffected.
    """
    print(json.dumps(payload, indent=2, default=str, ensure_ascii=False))


def _print_jira_error(resp: requests.Response) -> None:
    """Print a human-readable Jira error to stderr."""
    try:
        data = resp.json()
        msgs = data.get("errorMessages") or []
        errs = data.get("errors") or {}
        parts = list(msgs) + [f"{k}: {v}" for k, v in errs.items()]
        msg = "; ".join(parts) if parts else resp.text[:400]
    except Exception:
        msg = resp.text[:400]
    print(f"Error ({resp.status_code}): {msg}", file=sys.stderr)


# ---------------------------------------------------------------------------
# ADF helpers
# ---------------------------------------------------------------------------

import re as _re

# Inline markdown: processed left-to-right; longer tokens ordered first.
_INLINE_RE = _re.compile(
    r"(`+)(.+?)\1"                       # code span          (groups 1,2)
    r"|\*\*\*(.+?)\*\*\*"               # ***bold+italic***  (group 3)
    r"|\*\*(.+?)\*\*"                    # **bold**           (group 4)
    r"|\*(.+?)\*"                        # *italic*           (group 5)
    r"|(?<!\w)_(?![\s_])(.+?)(?<![\s_])_(?!\w)" # _italic_          (group 6)
    r"|\[([^\]]+)\]\(([^)]+)\)",         # [text](url)        (groups 7,8)
    _re.DOTALL,
)


def _inline_nodes(text: str) -> list[dict]:
    """Parse inline markdown into a list of ADF text/link nodes."""
    nodes: list[dict] = []
    last = 0
    for m in _INLINE_RE.finditer(text):
        if m.start() > last:
            nodes.append({"type": "text", "text": text[last:m.start()]})
        g = m.groups()
        if g[0]:  # `code`
            nodes.append({"type": "text", "text": g[1], "marks": [{"type": "code"}]})
        elif g[2]:  # ***bold italic***
            nodes.append({"type": "text", "text": g[2],
                          "marks": [{"type": "strong"}, {"type": "em"}]})
        elif g[3]:  # **bold**
            nodes.append({"type": "text", "text": g[3], "marks": [{"type": "strong"}]})
        elif g[4]:  # *italic*
            nodes.append({"type": "text", "text": g[4], "marks": [{"type": "em"}]})
        elif g[5]:  # _italic_
            nodes.append({"type": "text", "text": g[5], "marks": [{"type": "em"}]})
        elif g[6]:  # [link](url)
            nodes.append({"type": "text", "text": g[6],
                          "marks": [{"type": "link", "attrs": {"href": g[7]}}]})
        last = m.end()
    if last < len(text):
        nodes.append({"type": "text", "text": text[last:]})
    return nodes or [{"type": "text", "text": ""}]


def _parse_table(lines: list[str], start: int, end: int) -> tuple[dict, int]:
    """Parse a GFM table; return (ADF table node, next line index)."""
    def split_row(line: str) -> list[str]:
        return [c.strip() for c in line.strip().strip("|").split("|")]

    headers = split_row(lines[start])
    col_count = len(headers)
    i = start + 2  # skip header + separator

    def th(text: str) -> dict:
        return {"type": "tableHeader", "attrs": {},
                "content": [{"type": "paragraph", "content": _inline_nodes(text)}]}

    def td(text: str) -> dict:
        return {"type": "tableCell", "attrs": {},
                "content": [{"type": "paragraph", "content": _inline_nodes(text)}]}

    rows = [{"type": "tableRow", "content": [th(h) for h in headers]}]
    while (i < end
           and "|" in lines[i]
           and not _re.match(r'^[ \t]*(?:[-*+]|\d+[.)]) ', lines[i])
           and not lines[i].lstrip().startswith("> ")):
        cells = (split_row(lines[i]) + [""] * col_count)[:col_count]
        rows.append({"type": "tableRow", "content": [td(c) for c in cells]})
        i += 1

    return {
        "type": "table",
        "attrs": {"isNumberColumnEnabled": False, "layout": "default"},
        "content": rows,
    }, i


def _parse_list(lines: list[str], start: int, end: int, ordered: bool) -> tuple[dict, int]:
    """Parse a bullet or ordered list, supporting one level of nesting."""
    item_re = _re.compile(r"^([ \t]*)([-*+]|\d+[.)])\s+(.*)")
    list_type = "orderedList" if ordered else "bulletList"

    base_m = item_re.match(lines[start])
    base_indent = len(base_m.group(1)) if base_m else 0

    items: list[dict] = []
    i = start
    while i < end:
        line = lines[i]
        m = item_re.match(line)

        if not m:
            if not line.strip():
                i += 1
                # A blank line ends the list unless the next non-blank line is
                # another item of the *same type* at the same indent level.
                j = i
                while j < end and not lines[j].strip():
                    j += 1
                next_m = item_re.match(lines[j]) if j < end else None
                if next_m and len(next_m.group(1)) == base_indent:
                    next_is_ordered = bool(_re.match(r"\d+[.)]", next_m.group(2)))
                    if next_is_ordered == ordered:
                        continue
            break

        indent = len(m.group(1))
        if indent < base_indent:
            break  # dedented past our level

        if indent > base_indent:
            # Nested list — attach to the last item
            if items:
                nested_ordered = bool(_re.match(r"\d+[.)]", m.group(2)))
                nested_node, i = _parse_list(lines, i, end, ordered=nested_ordered)
                items[-1]["content"].append(nested_node)
            else:
                i += 1
            continue

        # Stop if marker type switches (e.g. bullet followed by ordered at same indent)
        item_is_ordered = bool(_re.match(r"\d+[.)]", m.group(2)))
        if item_is_ordered != ordered:
            break

        items.append({"type": "listItem", "content": [
            {"type": "paragraph", "content": _inline_nodes(m.group(3))}
        ]})
        i += 1

    return {"type": list_type, "content": items}, i


def _parse_blocks(lines: list[str], start: int, end: int) -> list[dict]:
    """Convert a slice of lines into a list of ADF block nodes."""
    nodes: list[dict] = []
    i = start

    while i < end:
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            i += 1
            continue

        # Fenced code block
        fence_m = _re.match(r"^(`{3,}|~{3,})(.*)", line)
        if fence_m:
            fence, lang = fence_m.group(1), fence_m.group(2).strip()
            code_lines: list[str] = []
            i += 1
            closing_re = _re.compile(rf"^{_re.escape(fence[0])}{{{len(fence)},}}\s*$")
            while i < end and not closing_re.match(lines[i]):
                code_lines.append(lines[i])
                i += 1
            if i < end:
                i += 1  # skip closing fence
            nodes.append({
                "type": "codeBlock",
                "attrs": {"language": lang} if lang else {},
                "content": [{"type": "text", "text": "\n".join(code_lines)}],
            })
            continue

        # ATX heading  (# H1  ## H2 …)
        heading_m = _re.match(r"^(#{1,6})\s+(.*?)(?:\s+#+)?\s*$", line)
        if heading_m:
            nodes.append({
                "type": "heading",
                "attrs": {"level": len(heading_m.group(1))},
                "content": _inline_nodes(heading_m.group(2)),
            })
            i += 1
            continue

        # Horizontal rule
        if _re.match(r"^(\*{3,}|-{3,}|_{3,})\s*$", stripped):
            nodes.append({"type": "rule"})
            i += 1
            continue

        # GFM table (next line is a separator row)
        if ("|" in line and i + 1 < end
                and "|" in lines[i + 1]
                and _re.match(r"^\s*\|?[\s\-:|]+\|?\s*$", lines[i + 1])):
            table_node, i = _parse_table(lines, i, end)
            nodes.append(table_node)
            continue

        # Blockquote
        if line.startswith("> ") or stripped == ">":
            bq_lines: list[str] = []
            while i < end and (lines[i].startswith("> ") or lines[i].strip() == ">"):
                bq_lines.append(lines[i][2:] if lines[i].startswith("> ") else "")
                i += 1
            inner = _parse_blocks(bq_lines, 0, len(bq_lines))
            nodes.append({"type": "blockquote",
                          "content": inner or [{"type": "paragraph",
                                                "content": [{"type": "text", "text": ""}]}]})
            continue

        # Bullet list
        if _re.match(r"^[ \t]*[-*+]\s", line):
            node, i = _parse_list(lines, i, end, ordered=False)
            nodes.append(node)
            continue

        # Ordered list
        if _re.match(r"^[ \t]*\d+[.)]\s", line):
            node, i = _parse_list(lines, i, end, ordered=True)
            nodes.append(node)
            continue

        # Paragraph — accumulate soft-wrapped lines until a block boundary
        para_lines: list[str] = []
        while i < end:
            l = lines[i]
            s = l.strip()
            if (not s
                    or _re.match(r"^#{1,6}\s", l)
                    or _re.match(r"^(`{3,}|~{3,})", l)
                    or _re.match(r"^(\*{3,}|-{3,}|_{3,})\s*$", s)
                    or l.startswith("> ")
                    or _re.match(r"^[ \t]*[-*+]\s", l)
                    or _re.match(r"^[ \t]*\d+[.)]\s", l)
                    or ("|" in l and i + 1 < end
                        and "|" in lines[i + 1]
                        and _re.match(r"^\s*\|?[\s\-:|]+\|?\s*$", lines[i + 1]))):
                break
            para_lines.append(l)
            i += 1

        if para_lines:
            nodes.append({"type": "paragraph",
                          "content": _inline_nodes(" ".join(para_lines))})

    return nodes


def text_to_adf(text: str) -> dict:
    """Convert Markdown text to Atlassian Document Format (ADF).

    Supported block elements:
      # / ## / ###   ATX headings (h1–h6)
      - / * / +      Bullet lists (one level of nesting)
      1. / 1)        Ordered lists (one level of nesting)
      | col |        GFM tables (with | --- | separator row)
      ```lang        Fenced code blocks (``` or ~~~)
      > text         Blockquotes
      ---            Horizontal rules (--- / *** / ___)

    Supported inline elements:
      **text**       Bold
      *text*         Italic
      ***text***     Bold + italic
      `text`         Inline code
      [text](url)    Links
    """
    lines = text.splitlines()
    content = _parse_blocks(lines, 0, len(lines))
    if not content:
        content = [{"type": "paragraph", "content": [{"type": "text", "text": ""}]}]
    return {"version": 1, "type": "doc", "content": content}


def adf_to_text(node: Any, depth: int = 0) -> str:
    """Recursively render an ADF node back to Markdown-flavoured plain text."""
    if node is None:
        return ""
    if isinstance(node, str):
        return node

    node_type = node.get("type", "")
    content = node.get("content", [])
    text_val = node.get("text", "")

    if node_type == "text":
        marks = {m["type"] for m in node.get("marks", [])}
        t = text_val
        if "code" in marks:
            t = f"`{t}`"
        if "strong" in marks:
            t = f"**{t}**"
        if "em" in marks:
            t = f"*{t}*"
        if "link" in marks:
            href = next((m["attrs"]["href"] for m in node.get("marks", [])
                         if m["type"] == "link"), "")
            t = f"[{t}]({href})"
        return t
    if node_type == "paragraph":
        return "".join(adf_to_text(c) for c in content) + "\n"
    if node_type == "heading":
        level = node.get("attrs", {}).get("level", 1)
        return "#" * level + " " + "".join(adf_to_text(c) for c in content) + "\n"
    if node_type == "codeBlock":
        lang = node.get("attrs", {}).get("language", "")
        inner = "".join(adf_to_text(c) for c in content)
        return f"```{lang}\n{inner}\n```\n"
    if node_type in ("bulletList", "orderedList"):
        lines = []
        for idx, item in enumerate(content, 1):
            marker = "-" if node_type == "bulletList" else f"{idx}."
            item_lines: list[str] = []
            for child in item.get("content", []):
                if child.get("type") in ("bulletList", "orderedList"):
                    # Indent nested list by two spaces
                    for nested_line in adf_to_text(child).splitlines():
                        item_lines.append(f"  {nested_line}")
                else:
                    item_lines.append(adf_to_text(child).strip())
            lines.append(f"{marker} {item_lines[0]}" if item_lines else f"{marker} ")
            lines.extend(item_lines[1:])
        return "\n".join(lines) + "\n"
    if node_type == "listItem":
        return "".join(adf_to_text(c) for c in content)
    if node_type == "blockquote":
        inner = "".join(adf_to_text(c) for c in content)
        return "\n".join(f"> {l}" for l in inner.splitlines()) + "\n"
    if node_type == "table":
        if not content:
            return ""
        out_lines = []
        for r_idx, row in enumerate(content):
            cells = [adf_to_text(cell).strip() for cell in row.get("content", [])]
            out_lines.append("| " + " | ".join(cells) + " |")
            if r_idx == 0:
                out_lines.append("| " + " | ".join("---" for _ in cells) + " |")
        return "\n".join(out_lines) + "\n"
    if node_type in ("tableHeader", "tableCell"):
        return "".join(adf_to_text(c) for c in content)
    if node_type == "tableRow":
        return "".join(adf_to_text(c) for c in content)
    if node_type == "rule":
        return "\n---\n"
    if node_type == "doc":
        return "".join(adf_to_text(c) for c in content)
    return "".join(adf_to_text(c) for c in content)


# ---------------------------------------------------------------------------
# Command implementations
# ---------------------------------------------------------------------------


def cmd_search(jql: str, limit: int, fields: str, *, json_output: bool = False) -> None:
    data = _client.call(
        "GET",
        "/rest/api/3/search/jql",
        params={"jql": jql, "maxResults": limit, "fields": fields},
    )
    assert isinstance(data, dict)
    if json_output:
        _emit_json(data)
        return
    issues = data.get("issues", [])
    total = data.get("total", len(issues))
    print(f"Showing {len(issues)} of {total} issue(s) matching: {jql}\n")
    for issue in issues:
        f = issue.get("fields", {})
        status = (f.get("status") or {}).get("name", "?")
        assignee = (f.get("assignee") or {}).get("displayName", "Unassigned")
        priority = (f.get("priority") or {}).get("name", "")
        summary = f.get("summary", "")
        print(f"  [{issue['key']}] {summary}")
        info = f"    Status: {status} | Assignee: {assignee}"
        if priority:
            info += f" | Priority: {priority}"
        print(info)
        print()


def cmd_get(issue_key: str, *, json_output: bool = False) -> None:
    data = _client.call(
        "GET",
        f"/rest/api/3/issue/{issue_key}",
        params={"fields": "summary,status,issuetype,priority,assignee,description,comment,labels"},
    )
    assert isinstance(data, dict)

    # Available transitions are part of `get`'s output in both modes. Fold them
    # into the issue payload so one fully-built `data` drives both paths
    # (mirrors Jira's own expand=transitions shape).
    td = _client.call("GET", f"/rest/api/3/issue/{issue_key}/transitions")
    assert isinstance(td, dict)
    data["transitions"] = td.get("transitions", [])

    if json_output:
        _emit_json(data)
        return

    f = data.get("fields", {})

    print(f"Key:      {data['key']}")
    print(f"Summary:  {f.get('summary', '')}")
    print(f"Type:     {(f.get('issuetype') or {}).get('name', '?')}")
    print(f"Status:   {(f.get('status') or {}).get('name', '?')}")
    print(f"Priority: {(f.get('priority') or {}).get('name', 'None')}")
    print(f"Assignee: {(f.get('assignee') or {}).get('displayName', 'Unassigned')}")
    if f.get("labels"):
        print(f"Labels:   {', '.join(f['labels'])}")

    if f.get("description"):
        print("\nDescription:")
        print(adf_to_text(f["description"]).rstrip())

    comments = (f.get("comment") or {}).get("comments", [])
    if comments:
        print(f"\nComments ({len(comments)}):")
        for c in comments:
            author = (c.get("author") or {}).get("displayName", "?")
            created = c.get("created", "")[:10]
            print(f"\n  --- {author} ({created}) ---")
            print(f"  {adf_to_text(c.get('body', '')).strip()}")

    tnames = [t["name"] for t in data.get("transitions", [])]
    if tnames:
        print(f"\nAvailable transitions: {', '.join(tnames)}")


def cmd_create(
    project: str,
    issue_type: str,
    summary: str,
    description: str,
    priority: str | None,
    labels: list[str] | None,
    parent: str | None,
    custom_fields: list[str] | None,
    *,
    json_output: bool = False,
) -> None:
    fields: dict[str, Any] = {
        "project": {"key": project},
        "summary": summary,
        "issuetype": {"name": issue_type},
        "description": text_to_adf(description),
    }
    if priority:
        fields["priority"] = {"name": priority}
    if labels:
        fields["labels"] = labels
    if parent:
        fields["parent"] = {"key": parent}
    for cf in custom_fields or []:
        if "=" not in cf:
            print(f"Error: --custom-field must be FIELD_ID=OPTION_ID, got: {cf}", file=sys.stderr)
            sys.exit(1)
        field_id, option_id = cf.split("=", 1)
        fields[field_id] = {"id": option_id}

    data = _client.call("POST", "/rest/api/3/issue", body={"fields": fields})
    assert isinstance(data, dict)
    if json_output:
        _emit_json(data)
        return
    key = data.get("key", "?")
    _, cloud_id = get_credentials()
    # Build a best-effort browse URL; may differ per tenant
    print(f"Created: {key}")
    print(f"ID:      {data.get('id', '')}")


def cmd_update(
    issue_key: str,
    summary: str | None,
    description: str | None,
    priority: str | None,
    labels: list[str] | None,
    *,
    json_output: bool = False,
) -> None:
    fields: dict[str, Any] = {}
    if summary is not None:
        fields["summary"] = summary
    if description is not None:
        fields["description"] = text_to_adf(description)
    if priority is not None:
        fields["priority"] = {"name": priority}
    if labels is not None:
        fields["labels"] = labels

    if not fields:
        print("Error: No fields specified to update.", file=sys.stderr)
        sys.exit(1)

    _client.call("PUT", f"/rest/api/3/issue/{issue_key}", body={"fields": fields}, allow_empty=True)
    if json_output:
        # Mirror the same per-field summary the human view prints.
        updated = {
            k: "(updated)" if k == "description"
            else v["name"] if isinstance(v, dict) and "name" in v
            else v
            for k, v in fields.items()
        }
        _emit_json({"key": issue_key, "updated": updated})
        return
    print(f"Updated {issue_key}")
    for k, v in fields.items():
        if k == "description":
            print("  description: (updated)")
        elif isinstance(v, dict) and "name" in v:
            print(f"  {k}: {v['name']}")
        else:
            print(f"  {k}: {v}")


def cmd_comment(issue_key: str, text: str, *, json_output: bool = False) -> None:
    resp = _client.call(
        "POST",
        f"/rest/api/3/issue/{issue_key}/comment",
        body={"body": text_to_adf(text)},
    )
    if json_output:
        _emit_json(resp)
        return
    print(f"Comment added to {issue_key}")


def cmd_transitions(issue_key: str, *, json_output: bool = False) -> None:
    data = _client.call("GET", f"/rest/api/3/issue/{issue_key}/transitions")
    assert isinstance(data, dict)

    # Current status is shown in both modes. Fold it into the transitions
    # payload so one fully-built `data` drives both paths.
    issue = _client.call("GET", f"/rest/api/3/issue/{issue_key}", params={"fields": "status"})
    assert isinstance(issue, dict)
    data["currentStatus"] = (issue.get("fields", {}).get("status") or {}).get("name", "?")

    if json_output:
        _emit_json(data)
        return

    print(f"Current status: {data['currentStatus']}")
    print(f"Available transitions for {issue_key}:")
    for t in data.get("transitions", []):
        to_status = (t.get("to") or {}).get("name", "")
        print(f"  [{t['id']}] {t['name']}" + (f" → {to_status}" if to_status else ""))


def cmd_transition(issue_key: str, transition_name: str, *, json_output: bool = False) -> None:
    data = _client.call("GET", f"/rest/api/3/issue/{issue_key}/transitions")
    assert isinstance(data, dict)
    transitions = data.get("transitions", [])

    match = next(
        (t for t in transitions if t["name"].lower() == transition_name.lower()),
        None,
    )
    if match is None:
        available = ", ".join(t["name"] for t in transitions)
        print(
            f"Error: Transition '{transition_name}' not available for {issue_key}.",
            file=sys.stderr,
        )
        print(f"Available: {available}", file=sys.stderr)
        sys.exit(1)

    _client.call(
        "POST",
        f"/rest/api/3/issue/{issue_key}/transitions",
        body={"transition": {"id": match["id"]}},
        allow_empty=True,
    )
    if json_output:
        _emit_json({"key": issue_key, "transition": match["name"]})
        return
    print(f"Transitioned {issue_key} → '{match['name']}'")


def cmd_assign(issue_key: str, account_id: str | None, *, json_output: bool = False) -> None:
    if account_id is None:
        # Assign to current user
        me = _client.call("GET", "/rest/api/3/myself")
        assert isinstance(me, dict)
        account_id = me.get("accountId")
        name = me.get("displayName", account_id)
        if not json_output:
            print(f"Assigning {issue_key} to {name}…")

    _client.call(
        "PUT",
        f"/rest/api/3/issue/{issue_key}/assignee",
        body={"accountId": account_id},
        allow_empty=True,
    )
    if json_output:
        _emit_json({"key": issue_key, "assignee": account_id})
        return
    print(f"Assigned {issue_key} to accountId={account_id}")


def cmd_projects(query: str | None, limit: int, *, json_output: bool = False) -> None:
    params: dict = {"maxResults": limit, "orderBy": "name"}
    if query:
        params["query"] = query

    data = _client.call("GET", "/rest/api/3/project/search", params=params)
    assert isinstance(data, dict)
    if json_output:
        _emit_json(data)
        return
    projects = data.get("values", [])
    total = data.get("total", len(projects))
    print(f"Projects ({len(projects)} of {total}):\n")
    for p in projects:
        print(f"  [{p['key']}] {p['name']}  ({p.get('projectTypeKey', '')})")


def cmd_myself(*, json_output: bool = False) -> None:
    data = _client.call("GET", "/rest/api/3/myself")
    assert isinstance(data, dict)
    if json_output:
        _emit_json(data)
        return
    print(f"Display name: {data.get('displayName')}")
    print(f"Email:        {data.get('emailAddress')}")
    print(f"Account ID:   {data.get('accountId')}")
    print(f"Time zone:    {data.get('timeZone')}")


def cmd_boards(project: str | None, board_type: str | None, limit: int, *, json_output: bool = False) -> None:
    params: dict = {"maxResults": limit}
    if project:
        params["projectKeyOrId"] = project
    if board_type:
        params["type"] = board_type

    data = _client.call("GET", "/rest/agile/1.0/board", params=params)
    assert isinstance(data, dict)
    if json_output:
        _emit_json(data)
        return
    boards = data.get("values", [])
    total = data.get("total", len(boards))
    print(f"Boards ({len(boards)} of {total}):\n")
    for b in boards:
        print(f"  [{b['id']}] {b['name']}  type={b.get('type', '?')}")


def cmd_sprints(board_id: int, state: str | None, limit: int, *, json_output: bool = False) -> None:
    params: dict = {"maxResults": limit}
    if state:
        params["state"] = state

    data = _client.call(
        "GET", f"/rest/agile/1.0/board/{board_id}/sprint", params=params
    )
    assert isinstance(data, dict)
    if json_output:
        _emit_json(data)
        return
    sprints = data.get("values", [])
    total = data.get("total", len(sprints))
    print(f"Sprints for board {board_id} ({len(sprints)} of {total}):\n")
    for s in sprints:
        start = s.get("startDate", "")[:10]
        end = s.get("endDate", "")[:10]
        print(f"  [{s['id']}] {s['name']}  state={s['state']}  {start} – {end}")


def cmd_sprint_issues(sprint_id: int, fields: str, limit: int, *, json_output: bool = False) -> None:
    data = _client.call(
        "GET",
        f"/rest/agile/1.0/sprint/{sprint_id}/issue",
        params={"maxResults": limit, "fields": fields},
    )
    assert isinstance(data, dict)
    if json_output:
        _emit_json(data)
        return
    issues = data.get("issues", [])
    total = data.get("total", len(issues))
    print(f"Sprint {sprint_id} — {len(issues)} of {total} issue(s):\n")
    for issue in issues:
        f = issue.get("fields", {})
        status = (f.get("status") or {}).get("name", "?")
        assignee = (f.get("assignee") or {}).get("displayName", "Unassigned")
        print(f"  [{issue['key']}] {f.get('summary', '')}")
        print(f"    Status: {status} | Assignee: {assignee}")
        print()


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Jira CLI — Atlassian skill",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="command", metavar="COMMAND")

    # Shared options available on every subcommand.
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--json",
        dest="json_output",
        action="store_true",
        help="Output the structured payload as JSON instead of human-readable text",
    )

    # --- search ---
    p = sub.add_parser("search", help="Search issues with JQL", parents=[common])
    p.add_argument("jql", help="JQL query string")
    p.add_argument("--limit", "-l", type=int, default=25, help="Max results (default: 25)")
    p.add_argument(
        "--fields",
        default="summary,status,assignee,priority",
        help="Comma-separated fields to return",
    )

    # --- get ---
    p = sub.add_parser("get", help="Get a single issue", parents=[common])
    p.add_argument("issue", help="Issue key, e.g. PROJ-123")

    # --- create ---
    p = sub.add_parser("create", help="Create a new issue", parents=[common])
    p.add_argument("--project", "-p", required=True, help="Project key")
    p.add_argument(
        "--type", "-t", dest="issue_type", required=True,
        help="Issue type, e.g. Bug, Task, Story, Epic",
    )
    p.add_argument("--summary", "-s", required=True, help="Issue title/summary")
    p.add_argument("--description", "-d", default="", help="Issue description (plain text)")
    p.add_argument("--priority", help="Priority: Highest, High, Medium, Low, Lowest")
    p.add_argument("--labels", nargs="+", help="Labels to add")
    p.add_argument("--parent", help="Parent issue key (for sub-tasks / child issues)")
    p.add_argument(
        "--custom-field", dest="custom_fields", action="append", metavar="FIELD_ID=OPTION_ID",
        help="Set a custom option field, e.g. --custom-field customfield_10208=10555 (repeatable)",
    )

    # --- update ---
    p = sub.add_parser("update", help="Update issue fields", parents=[common])
    p.add_argument("issue", help="Issue key")
    p.add_argument("--summary", "-s", help="New summary")
    p.add_argument("--description", "-d", help="New description (plain text)")
    p.add_argument("--priority", "-p", help="New priority")
    p.add_argument("--labels", nargs="+", help="New label list (replaces existing)")

    # --- comment ---
    p = sub.add_parser("comment", help="Add a comment to an issue", parents=[common])
    p.add_argument("issue", help="Issue key")
    p.add_argument("text", help="Comment text (plain text)")

    # --- transitions ---
    p = sub.add_parser("transitions", help="List available transitions for an issue", parents=[common])
    p.add_argument("issue", help="Issue key")

    # --- transition ---
    p = sub.add_parser("transition", help="Transition an issue to a new state", parents=[common])
    p.add_argument("issue", help="Issue key")
    p.add_argument("state", help="Target state name, e.g. 'In Progress'")

    # --- assign ---
    p = sub.add_parser("assign", help="Assign an issue (default: to yourself)", parents=[common])
    p.add_argument("issue", help="Issue key")
    p.add_argument("--to", dest="account_id", help="Target accountId (omit to assign to self)")

    # --- projects ---
    p = sub.add_parser("projects", help="List projects", parents=[common])
    p.add_argument("--query", "-q", help="Filter by name substring")
    p.add_argument("--limit", "-l", type=int, default=50, help="Max results (default: 50)")

    # --- myself ---
    sub.add_parser("myself", help="Show current user info", parents=[common])

    # --- boards ---
    p = sub.add_parser("boards", help="List Jira Software boards", parents=[common])
    p.add_argument("--project", "-p", help="Filter by project key or ID")
    p.add_argument("--type", dest="board_type", choices=["scrum", "kanban", "simple"])
    p.add_argument("--limit", "-l", type=int, default=50)

    # --- sprints ---
    p = sub.add_parser("sprints", help="List sprints for a board", parents=[common])
    p.add_argument("board_id", type=int, help="Board ID")
    p.add_argument(
        "--state", choices=["active", "closed", "future"],
        help="Filter by sprint state",
    )
    p.add_argument("--limit", "-l", type=int, default=25)

    # --- sprint-issues ---
    p = sub.add_parser("sprint-issues", help="List issues in a sprint", parents=[common])
    p.add_argument("sprint_id", type=int, help="Sprint ID")
    p.add_argument("--fields", default="summary,status,assignee")
    p.add_argument("--limit", "-l", type=int, default=50)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    json_output = getattr(args, "json_output", False)

    if args.command == "search":
        cmd_search(args.jql, args.limit, args.fields, json_output=json_output)
    elif args.command == "get":
        cmd_get(args.issue, json_output=json_output)
    elif args.command == "create":
        cmd_create(
            project=args.project,
            issue_type=args.issue_type,
            summary=args.summary,
            description=args.description,
            priority=args.priority,
            labels=args.labels,
            parent=args.parent,
            custom_fields=args.custom_fields,
            json_output=json_output,
        )
    elif args.command == "update":
        cmd_update(
            issue_key=args.issue,
            summary=args.summary,
            description=args.description,
            priority=args.priority,
            labels=args.labels,
            json_output=json_output,
        )
    elif args.command == "comment":
        cmd_comment(args.issue, args.text, json_output=json_output)
    elif args.command == "transitions":
        cmd_transitions(args.issue, json_output=json_output)
    elif args.command == "transition":
        cmd_transition(args.issue, args.state, json_output=json_output)
    elif args.command == "assign":
        cmd_assign(args.issue, args.account_id, json_output=json_output)
    elif args.command == "projects":
        cmd_projects(args.query, args.limit, json_output=json_output)
    elif args.command == "myself":
        cmd_myself(json_output=json_output)
    elif args.command == "boards":
        cmd_boards(args.project, args.board_type, args.limit, json_output=json_output)
    elif args.command == "sprints":
        cmd_sprints(args.board_id, args.state, args.limit, json_output=json_output)
    elif args.command == "sprint-issues":
        cmd_sprint_issues(args.sprint_id, args.fields, args.limit, json_output=json_output)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
