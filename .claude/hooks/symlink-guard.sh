#!/usr/bin/env bash
# Block edits whose final path component is a symlink and point Claude at the
# real source instead. Dotfiles are linked from this repository into $HOME, so
# editing the link would dodge version control. Edits that merely pass through
# a symlinked parent directory land in the real file and are allowed.
# PreToolUse blocks on exit 2 with stderr fed back to Claude; exit 1 is
# reserved for infrastructure failures.

set -u

fail() {
	printf 'symlink-guard: %s\n' "$*" >&2
	exit 1
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

[[ -n "$file_path" ]] || exit 0
[[ "$file_path" == /* ]] || file_path="${cwd%/}/$file_path"
[[ -L "$file_path" ]] || exit 0

target=$(readlink -- "$file_path") || fail "could not read symlink $file_path"
[[ "$target" == /* ]] || target="$(dirname "$file_path")/$target"

printf '%s is a symlink to %s. Edit that source file instead so the change stays versioned; the link will pick it up.\n' \
	"$file_path" "$target" >&2
exit 2
