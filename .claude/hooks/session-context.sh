#!/usr/bin/env bash
# Give a fresh or resumed session immediate repository bearings: branch,
# uncommitted changes, and recent commits. SessionStart stdout is added to
# Claude's context. Non-repository directories stay silent.

set -u

if ! command -v jq >/dev/null 2>&1; then
	printf 'Claude session-context hook requires jq\n' >&2
	exit 1
fi

input=$(command cat)
if ! parsed=$(printf '%s' "$input" | jq -er '[.hook_event_name // "", .source // "", .cwd // "."] | @tsv'); then
	printf 'Claude session-context hook received invalid JSON\n' >&2
	exit 1
fi
IFS=$'\t' read -r event start_source cwd <<<"$parsed"

# The SessionStart/startup|resume matcher already restricts when this hook
# fires; this is just a defensive check in case that matcher ever widens.
[[ "$event" == "SessionStart" ]] || exit 0
case "$start_source" in
startup | resume) ;;
*) exit 0 ;;
esac

git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
printf 'Repository context: branch %s.\n' "${branch:-detached HEAD}"

dirty=$(git -C "$cwd" status --porcelain 2>/dev/null)
if [[ -n "$dirty" ]]; then
	total=$(printf '%s\n' "$dirty" | wc -l | tr -d ' ')
	printf 'Uncommitted changes (%s files) predate this session; preserve them unless asked otherwise:\n' "$total"
	printf '%s\n' "$dirty" | head -15
	[[ "$total" -gt 15 ]] && printf '... and %s more.\n' "$((total - 15))"
else
	printf 'Worktree is clean.\n'
fi

printf 'Recent commits:\n'
git -C "$cwd" log --oneline -3 2>/dev/null || true
