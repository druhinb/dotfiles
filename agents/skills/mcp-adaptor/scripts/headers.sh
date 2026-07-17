#!/usr/bin/env bash
# Claude Code headersHelper: emit {"RBX-LCA-v1":"<token>"} on each request.
# Delegates to the sibling Python token resolver so legacy headers.sh
# registrations get the same stale-token fallback behavior as headers.py.
#
# Env overrides:
#   MCP_GW_ENV=st1|st2|st3|prod                   (default: prod)
#   MCP_ADAPTOR_GET_TOKEN=/abs/path/get_token.py  (override lookup, e.g. for tests)
set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GET_TOKEN="${MCP_ADAPTOR_GET_TOKEN:-$script_dir/get_token.py}"

if [ ! -r "$GET_TOKEN" ]; then
  echo "headers.sh: token resolver not found at '$GET_TOKEN'; reinstall the mcp-adaptor skill or set MCP_ADAPTOR_GET_TOKEN." >&2
  printf '{}'
  exit 0
fi

env="${MCP_GW_ENV:-prod}"

# Run once, capturing stdout and stderr separately. If no token, forward the
# ACTION REQUIRED message to our own stderr so Claude's MCP debug output
# ("claude --debug") shows users exactly what to fix.
tmp_err="$(mktemp)"
trap 'rm -f "$tmp_err"' EXIT
case "$GET_TOKEN" in
  *.sh) token="$(bash "$GET_TOKEN" "$env" 2>"$tmp_err" || true)" ;;
  *) token="$(uv run "$GET_TOKEN" "$env" 2>"$tmp_err" || true)" ;;
esac

if [ -n "$token" ]; then
  printf '{"RBX-LCA-v1":"%s"}' "$token"
else
  [ -s "$tmp_err" ] && cat "$tmp_err" >&2
  printf '{}'
fi
