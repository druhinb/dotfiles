# /// script
# requires-python = ">=3.10"
# dependencies = ["pytest"]
# ///
"""Tests for the Markdown-to-ADF converter in jira_cli.py.

Run with:  uv run pytest skills/atlassian/tests/
"""
from __future__ import annotations

import importlib.util
import sys
import types
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Load jira_cli without triggering network auth
# ---------------------------------------------------------------------------

def _load_module():
    stub = types.ModuleType("auth")
    stub.get_credentials = lambda **_: ("token", "cloud-id")
    sys.modules.setdefault("auth", stub)

    spec = importlib.util.spec_from_file_location(
        "jira_cli",
        Path(__file__).parent.parent / "scripts" / "jira_cli.py",
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_mod = _load_module()
to_adf = _mod.text_to_adf
to_text = _mod.adf_to_text


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def node_types(md: str) -> list[str]:
    return [n["type"] for n in to_adf(md)["content"]]


def roundtrip(md: str) -> str:
    return to_text(to_adf(md))


# ---------------------------------------------------------------------------
# Block elements
# ---------------------------------------------------------------------------

class TestHeadings:
    def test_h1_through_h3(self):
        adf = to_adf("# One\n## Two\n### Three\n")
        nodes = adf["content"]
        assert nodes[0] == {"type": "heading", "attrs": {"level": 1},
                             "content": [{"type": "text", "text": "One"}]}
        assert nodes[1]["attrs"]["level"] == 2
        assert nodes[2]["attrs"]["level"] == 3

    def test_heading_roundtrip(self):
        assert "## Section" in roundtrip("## Section\n")

    def test_inline_formatting_inside_heading(self):
        adf = to_adf("## **Bold** heading\n")
        content = adf["content"][0]["content"]
        assert any(n.get("marks") == [{"type": "strong"}] for n in content)


class TestParagraphs:
    def test_plain_paragraph(self):
        assert node_types("Hello world") == ["paragraph"]

    def test_blank_line_separates_paragraphs(self):
        assert node_types("First\n\nSecond") == ["paragraph", "paragraph"]

    def test_soft_wrap_joins_lines(self):
        out = roundtrip("Line one\nLine two\n")
        assert "Line one" in out and "Line two" in out


class TestBulletLists:
    def test_basic_bullet(self):
        assert node_types("- A\n- B\n") == ["bulletList"]

    def test_star_and_plus_markers(self):
        assert node_types("* A\n* B\n") == ["bulletList"]
        assert node_types("+ A\n+ B\n") == ["bulletList"]

    def test_item_count(self):
        adf = to_adf("- A\n- B\n- C\n")
        assert len(adf["content"][0]["content"]) == 3

    def test_inline_formatting_in_items(self):
        out = roundtrip("- **bold** item\n")
        assert "**bold**" in out

    def test_loose_list_blank_line_between_items(self):
        adf = to_adf("- A\n\n- B\n")
        assert adf["content"][0]["type"] == "bulletList"
        assert len(adf["content"][0]["content"]) == 2


class TestOrderedLists:
    def test_period_style(self):
        assert node_types("1. A\n2. B\n") == ["orderedList"]

    def test_paren_style(self):
        # Bug 1 regression: 1) markers must be recognised as ordered
        assert node_types("1) A\n2) B\n") == ["orderedList"]

    def test_paren_style_after_blank_line(self):
        # Bug 1 regression: blank-line continuation with 1) markers
        adf = to_adf("1) First\n2) Second\n\n3) Third\n")
        assert adf["content"][0]["type"] == "orderedList"
        assert len(adf["content"][0]["content"]) == 3

    def test_roundtrip_numbering(self):
        out = roundtrip("1. First\n2. Second\n")
        assert "1." in out and "2." in out


class TestMixedMarkerTypes:
    def test_bullet_then_ordered_no_blank_line(self):
        # Bug 3 regression: contiguous bullet+ordered must not merge
        types_ = node_types("- bullet\n1. numbered\n")
        assert types_ == ["bulletList", "orderedList"]

    def test_ordered_then_bullet_no_blank_line(self):
        types_ = node_types("1. numbered\n- bullet\n")
        assert types_ == ["orderedList", "bulletList"]


class TestNestedLists:
    def test_nested_bullet(self):
        md = "- parent\n  - child\n"
        adf = to_adf(md)
        outer = adf["content"][0]
        assert outer["type"] == "bulletList"
        parent_item = outer["content"][0]
        child_types = [c["type"] for c in parent_item["content"]]
        assert "bulletList" in child_types

    def test_nested_list_indented_in_roundtrip(self):
        # Bug 2 regression: child items must be indented, not at top level
        out = roundtrip("- parent\n  - child\n")
        assert "  - child" in out

    def test_nested_paren_ordered(self):
        # Bug 1+2 combo: nested 1) items classified and indented correctly
        md = "- parent\n  1) child\n"
        adf = to_adf(md)
        parent_item = adf["content"][0]["content"][0]
        nested = next(c for c in parent_item["content"]
                      if c["type"] == "orderedList")
        assert nested["type"] == "orderedList"


class TestCodeBlocks:
    def test_fenced_no_lang(self):
        adf = to_adf("```\ncode here\n```\n")
        assert adf["content"][0]["type"] == "codeBlock"

    def test_fenced_with_lang(self):
        adf = to_adf("```python\nx = 1\n```\n")
        node = adf["content"][0]
        assert node["attrs"].get("language") == "python"

    def test_tilde_fence(self):
        adf = to_adf("~~~lua\nlocal x\n~~~\n")
        assert adf["content"][0]["type"] == "codeBlock"

    def test_code_content_preserved(self):
        adf = to_adf("```\nline1\nline2\n```\n")
        text = adf["content"][0]["content"][0]["text"]
        assert "line1" in text and "line2" in text

    def test_fence_not_closed_by_info_string(self):
        # Regression: a line like ```python inside a block must not close it
        md = "```\n```python\nstill inside\n```\n"
        adf = to_adf(md)
        assert adf["content"][0]["type"] == "codeBlock"
        text = adf["content"][0]["content"][0]["text"]
        assert "```python" in text

    def test_four_backtick_fence_not_closed_by_three(self):
        # A 4-backtick fence requires a 4-backtick closer
        md = "````\n```\nstill inside\n````\n"
        adf = to_adf(md)
        assert adf["content"][0]["type"] == "codeBlock"
        text = adf["content"][0]["content"][0]["text"]
        assert "```" in text


class TestTables:
    def test_basic_table(self):
        md = "| A | B |\n|---|---|\n| 1 | 2 |\n"
        assert node_types(md) == ["table"]

    def test_header_and_data_rows(self):
        md = "| A | B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |\n"
        adf = to_adf(md)
        table = adf["content"][0]
        assert len(table["content"]) == 3  # header + 2 data rows
        assert table["content"][0]["content"][0]["type"] == "tableHeader"
        assert table["content"][1]["content"][0]["type"] == "tableCell"

    def test_inline_formatting_in_cells(self):
        md = "| **bold** | normal |\n|---|---|\n| a | b |\n"
        out = roundtrip(md)
        assert "**bold**" in out

    def test_roundtrip_has_separator(self):
        out = roundtrip("| X |\n|---|\n| Y |\n")
        assert "---" in out

    def test_bare_rule_after_pipe_line_not_table(self):
        # Regression: "|" line followed by bare "---" must not become a table
        types_ = node_types("Status: pass | fail\n---\n")
        assert types_ == ["paragraph", "rule"]

    def test_table_followed_by_list(self):
        # Regression: greedy table consumer must not swallow following list item
        md = "| A | B |\n|---|---|\n| 1 | 2 |\n- item | note\n"
        types_ = node_types(md)
        assert types_ == ["table", "bulletList"]

    def test_table_followed_by_blockquote(self):
        # Greedy consumer must stop at a blockquote even if it contains "|"
        md = "| A | B |\n|---|---|\n| 1 | 2 |\n> note | ref\n"
        types_ = node_types(md)
        assert types_ == ["table", "blockquote"]


class TestBlockquotes:
    def test_basic_blockquote(self):
        assert node_types("> quote\n") == ["blockquote"]

    def test_content_preserved(self):
        out = roundtrip("> some text\n")
        assert "some text" in out

    def test_roundtrip_prefix(self):
        out = roundtrip("> quote\n")
        assert out.strip().startswith(">")


class TestHorizontalRule:
    def test_dashes(self):
        assert node_types("---\n") == ["rule"]

    def test_stars(self):
        assert node_types("***\n") == ["rule"]

    def test_underscores(self):
        assert node_types("___\n") == ["rule"]


# ---------------------------------------------------------------------------
# Inline elements
# ---------------------------------------------------------------------------

class TestInlineFormatting:
    def test_bold_double_star(self):
        out = roundtrip("**bold**")
        assert "**bold**" in out

    def test_bold_double_underscore_not_supported(self):
        # __bold__ is intentionally not parsed as bold to prevent false
        # positives with Python dunder names like __init__.  Use **bold**.
        adf = to_adf("__bold__")
        para_content = adf["content"][0]["content"]
        marks = [m["type"] for n in para_content for m in n.get("marks", [])]
        assert "strong" not in marks

    def test_italic_star(self):
        out = roundtrip("*italic*")
        assert "*italic*" in out

    def test_italic_underscore(self):
        out = roundtrip("_italic_")
        assert "*italic*" in out  # normalised to * in output

    def test_snake_case_not_italic(self):
        # Regression: intraword underscores must not produce em marks
        adf = to_adf("feature_flag_enabled")
        para_content = adf["content"][0]["content"]
        marks = [m["type"] for n in para_content for m in n.get("marks", [])]
        assert "em" not in marks

    def test_dunder_not_bold(self):
        # Regression: __dunder__ must not produce strong or em marks
        adf = to_adf("__init__")
        para_content = adf["content"][0]["content"]
        marks = [m["type"] for n in para_content for m in n.get("marks", [])]
        assert "strong" not in marks
        assert "em" not in marks

    def test_multiple_intraword_underscores_plain(self):
        # a_b_c_d — all intraword — must roundtrip unchanged
        out = roundtrip("a_b_c_d")
        assert "a_b_c_d" in out

    def test_inline_code_suppresses_formatting(self):
        # snake_case inside a code span must not produce em marks
        adf = to_adf("`snake_case`")
        para_content = adf["content"][0]["content"]
        marks = [m["type"] for n in para_content for m in n.get("marks", [])]
        assert "em" not in marks
        assert "code" in marks

    def test_bold_in_sentence(self):
        # Surrounding plain text must be preserved alongside bold
        adf = to_adf("The **word** is important")
        para_content = adf["content"][0]["content"]
        texts = [n.get("text", "") for n in para_content]
        assert any("The " in t for t in texts)
        assert any(n.get("marks") == [{"type": "strong"}] for n in para_content)

    def test_bold_italic(self):
        adf = to_adf("***bi***")
        marks = {m["type"] for m in adf["content"][0]["content"][0]["marks"]}
        assert marks == {"strong", "em"}

    def test_inline_code(self):
        out = roundtrip("`code`")
        assert "`code`" in out

    def test_link(self):
        out = roundtrip("[text](https://example.com)")
        assert "[text](https://example.com)" in out

    def test_mixed_inline(self):
        out = roundtrip("See **bold** and `code` and [link](http://x.com)")
        assert "**bold**" in out
        assert "`code`" in out
        assert "[link](http://x.com)" in out


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

class TestHeadingLevels:
    def test_h4_through_h6(self):
        adf = to_adf("#### Four\n##### Five\n###### Six\n")
        nodes = adf["content"]
        assert nodes[0]["attrs"]["level"] == 4
        assert nodes[1]["attrs"]["level"] == 5
        assert nodes[2]["attrs"]["level"] == 6


class TestEdgeCases:
    def test_empty_string(self):
        adf = to_adf("")
        assert adf["version"] == 1
        assert adf["type"] == "doc"
        assert len(adf["content"]) == 1  # empty paragraph sentinel

    def test_only_blank_lines(self):
        adf = to_adf("\n\n\n")
        assert adf["type"] == "doc"

    def test_adf_to_text_none(self):
        assert to_text(None) == ""

    def test_unknown_node_type_falls_back(self):
        node = {"type": "unknownFutureType", "content": [
            {"type": "text", "text": "hello"}
        ]}
        assert to_text(node) == "hello"
