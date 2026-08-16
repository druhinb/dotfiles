#!/usr/bin/env bash
# samples own-line comments from a pre-cutoff revision to profile the repo's human voice
set -euo pipefail

CUTOFF="${1:-2022-11-30}"
SAMPLE_SIZE="${2:-25}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
	echo "comment-profile: not a git repository" >&2
	exit 1
fi

rev="$(git rev-list -1 --before="$CUTOFF" HEAD 2>/dev/null || true)"
if [ -z "$rev" ]; then
	echo "comment-profile: no commit before $CUTOFF, use the fallback profile" >&2
	exit 2
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git ls-tree -r --name-only "$rev" |
	grep -Ei '\.(c|h|cc|cpp|hpp|cs|go|rs|java|kt|swift|js|jsx|ts|tsx|py|rb|sh|bash|zsh|lua|sql|php|scala|mm?)$' |
	grep -Eiv '(^|/)(vendor|node_modules|third_party|external|generated|dist|build|\.min\.)' >"$tmp/files" || true

if [ ! -s "$tmp/files" ]; then
	echo "comment-profile: no source files at $rev, use the fallback profile" >&2
	exit 2
fi

while IFS= read -r f; do
	git show "$rev:$f" 2>/dev/null || true
done <"$tmp/files" >"$tmp/source"

# own-line comments only. trailing comments are excluded to avoid string literals
# matching as comment markers across the concatenated languages.
grep -E '^[[:space:]]*(//|#|--)' "$tmp/source" |
	grep -Ev '^[[:space:]]*#!' |
	grep -Ev '^[[:space:]]*#[[:space:]]*(include|define|pragma|ifn?def|endif|else|elif|if|undef|error|warning|import|region|endregion)\b' |
	grep -Ev '^[[:space:]]*#\[' |
	sed -E 's@^[[:space:]]*(//+|#+|--+)[[:space:]]*@@' |
	grep -Ev '^[[:space:]]*$' >"$tmp/comments" || true

comments="$(wc -l <"$tmp/comments" | tr -d ' ')"
if [ "$comments" -eq 0 ]; then
	echo "comment-profile: no comments found at $rev, use the fallback profile" >&2
	exit 2
fi

lines="$(wc -l <"$tmp/source" | tr -d ' ')"
files="$(wc -l <"$tmp/files" | tr -d ' ')"
awk '{print NF}' "$tmp/comments" | sort -n >"$tmp/lens"

quantile() {
	awk -v n="$comments" -v q="$1" 'BEGIN { i = int(n * q); if (i < 1) i = 1 } NR == i { print; exit }' "$tmp/lens"
}

# awk expands escape sequences in -v assignments, so a literal dot needs a doubled backslash
share() {
	awk -v n="$comments" -v re="$1" '$0 ~ re { c++ } END { printf "%.0f", (c / n) * 100 }' "$tmp/comments"
}

printf 'revision   %s (%s)\n' "$(git log -1 --format=%h "$rev")" "$(git log -1 --format=%ad --date=short "$rev")"
printf 'sampled    %s comments across %s files, %s source lines\n\n' "$comments" "$files" "$lines"

printf 'density    %s comments per 100 lines\n' "$(awk -v c="$comments" -v l="$lines" 'BEGIN { printf "%.1f", (c / l) * 100 }')"
printf 'length     %s words median, %s words p90\n' "$(quantile 0.5)" "$(quantile 0.9)"
printf 'lowercase  %s%% start lowercase\n' "$(share '^[a-z]')"
printf 'period     %s%% end in a period\n' "$(share '\\.$')"
printf 'citations  %s%% cite a ticket, rfc, cve, url, or bug\n\n' "$(share '([A-Z][A-Z]+-[0-9]+|[Rr][Ff][Cc] ?[0-9]+|CVE-[0-9]|https?://|[Bb]ug ?#?[0-9]+)')"

if [ "$comments" -lt 20 ]; then
	printf 'WARNING: under 20 comments, percentages are noise. prefer the fallback profile.\n\n'
fi

printf 'sample (read these and imitate them)\n'
# head against a file, not a pipe. closing the pipe early trips pipefail with 141.
awk 'BEGIN { srand(42) } { printf "%.9f\t%s\n", rand(), $0 }' "$tmp/comments" |
	sort -n | cut -f2- >"$tmp/shuffled"
head -n "$SAMPLE_SIZE" "$tmp/shuffled" | sed 's/^/  /'
