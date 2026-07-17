#!/usr/bin/env bash
# Gate check for the ship loop. Runs lint/syntax/secret checks on changed files
# when ship-builder completes. Exits nonzero with a blocking message if any
# check fails.

set -u

fail() {
	printf 'ship-gate: %s\n' "$*" >&2
	exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required"

input=$(command cat)
agent_name=""
if ! agent_name=$(printf '%s' "$input" | jq -er '.agent_name // .agent.name // ""'); then
	fail "could not parse hook input"
fi

case "$agent_name" in
ship-builder) ;;
*) exit 0 ;;
esac

cwd="."
if parsed_cwd=$(printf '%s' "$input" | jq -er '.cwd // "."'); then
	cwd="$parsed_cwd"
fi

errors=()

while IFS= read -r file; do
	[[ -f "$cwd/$file" ]] || continue
	if ! bash -n "$cwd/$file" 2>/dev/null; then
		errors+=("bash -n failed: $file")
	fi
	if command -v shfmt >/dev/null 2>&1 && ! shfmt -d "$cwd/$file" >/dev/null 2>&1; then
		errors+=("shfmt failed: $file")
	fi
	if command -v shellcheck >/dev/null 2>&1 && ! shellcheck "$cwd/$file" >/dev/null 2>&1; then
		errors+=("shellcheck failed: $file")
	fi
done < <(git -C "$cwd" diff --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(sh|bash)$')

while IFS= read -r file; do
	[[ -f "$cwd/$file" ]] || continue
	if ! jq empty "$cwd/$file" 2>/dev/null; then
		errors+=("invalid JSON: $file")
	fi
done < <(git -C "$cwd" diff --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.json$')

if command -v stylua >/dev/null 2>&1; then
	while IFS= read -r file; do
		[[ -f "$cwd/$file" ]] || continue
		if ! stylua --check "$cwd/$file" >/dev/null 2>&1; then
			errors+=("stylua --check failed: $file")
		fi
	done < <(git -C "$cwd" diff --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.lua$')
fi

if git -C "$cwd" diff 2>/dev/null | grep -qEi '(password|secret|api_key|token)\s*[:=]\s*["'"'"'][^"'"'"']{8,}'; then
	errors+=("potential secret detected in diff")
fi

if ! git -C "$cwd" diff --check >/dev/null 2>&1; then
	errors+=("git diff --check failed (trailing whitespace or conflict markers)")
fi

if [[ ${#errors[@]} -gt 0 ]]; then
	printf 'ship-gate BLOCKED:\n'
	for err in "${errors[@]}"; do
		printf '  - %s\n' "$err"
	done
	printf '\nFix these before the slice can pass critique.\n'
	exit 1
fi
