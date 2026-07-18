#!/usr/bin/env bash
# Feed syntax and lint diagnostics for a just-edited file back to Claude so
# the problem is fixed in the same turn. Complements format-config.sh, which
# only formats. PostToolUse feeds stderr to Claude on exit 2; exit 1 is
# reserved for infrastructure failures. Checks stay cheap and per-file; whole
# repository validation belongs to the documented check commands.

set -u

fail() {
	printf 'lint-feedback: %s\n' "$*" >&2
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
[[ -f "$file_path" ]] || exit 0

findings=""

# check LABEL COMMAND...: append trimmed diagnostics when COMMAND fails.
check() {
	local label="$1" output
	shift
	if ! output=$("$@" 2>&1); then
		findings+="[$label] $(printf '%s' "$output" | head -c 1500)"$'\n'
	fi
}

case "$file_path" in
*.sh | *.bash)
	check "bash -n" bash -n "$file_path"
	if command -v shellcheck >/dev/null 2>&1; then
		check "shellcheck" shellcheck -- "$file_path"
	fi
	;;
*.zsh | */.zshrc | */.zshenv | */.zprofile)
	check "zsh -n" zsh -n "$file_path"
	;;
*.json)
	check "jq" jq empty "$file_path"
	;;
*.py)
	if command -v python3 >/dev/null 2>&1; then
		check "python3 syntax" python3 -c \
			'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' \
			"$file_path"
	fi
	;;
*.lua)
	# luajit -bl compiles without executing, so this is a pure syntax check.
	if command -v luajit >/dev/null 2>&1; then
		check "luajit syntax" luajit -bl "$file_path" /dev/null
	fi
	;;
esac

[[ -n "$findings" ]] || exit 0
{
	printf 'lint-feedback found issues in %s:\n' "$file_path"
	printf '%s' "$findings"
	printf 'Fix these now, in this same task.\n'
} >&2
exit 2
