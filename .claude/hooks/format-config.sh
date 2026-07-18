#!/usr/bin/env bash
# Format files edited by Claude Code when a deterministic formatter is known.

set -u

fail() {
	printf 'Claude format hook: %s\n' "$*" >&2
	exit 1
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "$1 is required to format $file_path"
}

command -v jq >/dev/null 2>&1 || fail "jq is required to parse hook input"

input=$(command cat)
cwd="."
file_path=""
if ! parsed=$(
	printf '%s' "$input" | jq -er '
    "cwd=" + ((.cwd // ".") | @sh),
    "file_path=" + ((.tool_input.file_path // "") | @sh)
  '
); then
	fail "received invalid hook input"
fi
eval "$parsed"

# The Edit|Write matcher should guarantee tool_input.file_path is set; exit
# quietly rather than failing loudly in case that matcher ever widens.
[[ -n "$file_path" ]] || exit 0
[[ "$file_path" == /* ]] || file_path="${cwd%/}/$file_path"
[[ -f "$file_path" ]] || exit 0

case "$file_path" in
*.json)
	temporary=$(mktemp "${TMPDIR:-/tmp}/claude-format.XXXXXX") || fail "could not create a temporary file"
	trap 'rm -f "$temporary"' EXIT HUP INT TERM
	if ! jq --indent 2 . -- "$file_path" >"$temporary"; then
		fail "jq could not format $file_path"
	fi
	if ! cmp -s "$temporary" "$file_path" && ! cp "$temporary" "$file_path"; then
		fail "could not update $file_path"
	fi
	;;
*.lua)
	require_command stylua
	command stylua -- "$file_path" || fail "stylua could not format $file_path"
	;;
*.sh | *.bash)
	require_command shfmt
	command shfmt -w -- "$file_path" || fail "shfmt could not format $file_path"
	;;
esac
