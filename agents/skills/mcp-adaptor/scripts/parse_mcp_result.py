#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
#
# [[tool.uv.index]]
# url = "https://artifactory.rbx.com/api/pypi/pypi-all/simple"
# default = true
# ///
"""
Unwrap oversized MCP tool result files.

When an MCP tool call returns too much data to display inline, Claude Code
saves it to a file with this envelope:

    [{\"type\": \"text\", \"text\": \"<JSON string of actual result>\"}]

Usage:
    python3 parse_mcp_result.py <result_file> [--raw]
    python3 parse_mcp_result.py <result_file> | jq '.hits[].source | {ts: .["@timestamp"], level: .["log.level"], msg: .message}'

Options:
    --raw   Print the inner JSON string without further parsing (useful for piping to jq)

Exit codes:
    0  success
    1  file not found or unrecognised format
"""

import json
import sys


def unwrap(path: str) -> object:
    with open(path) as f:
        envelope = json.load(f)

    if not isinstance(envelope, list) or not envelope:
        raise ValueError("expected a non-empty JSON array at top level")

    # Collect all text items (there is usually just one)
    parts = []
    for item in envelope:
        if isinstance(item, dict) and item.get("type") == "text":
            parts.append(json.loads(item["text"]))

    if not parts:
        raise ValueError("no 'text' items found in envelope")

    return parts[0] if len(parts) == 1 else parts


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    flags = [a for a in sys.argv[1:] if a.startswith("-")]

    if not args:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    try:
        result = unwrap(args[0])
    except FileNotFoundError:
        print(f"error: file not found: {args[0]}", file=sys.stderr)
        sys.exit(1)
    except (ValueError, json.JSONDecodeError) as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)

    if "--raw" in flags:
        print(json.dumps(result))
    else:
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
