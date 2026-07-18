#!/usr/bin/env bash
# Gate check for the ship loop. Runs lint/syntax/secret checks on changed files
# when ship-builder completes. Blocks (exit 2, message on stderr) if any check
# fails, since Stop/SubagentStop hooks only block on exit 2 and Claude only
# sees stderr for it. Exit 1 is reserved for infrastructure failures (missing
# jq, unparseable input) so a broken hook doesn't silently wedge the loop.

set -u

fail() {
	printf 'ship-gate: %s\n' "$*" >&2
	exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required"

input=$(command cat)
agent_type=""
if ! agent_type=$(printf '%s' "$input" | jq -er '.agent_type // ""'); then
	fail "could not parse hook input"
fi

case "$agent_type" in
ship-builder) ;;
*) exit 0 ;;
esac

cwd="."
if parsed_cwd=$(printf '%s' "$input" | jq -er '.cwd // "."'); then
	cwd="$parsed_cwd"
fi

# Union of unstaged, staged, and untracked files. `git diff --name-only`
# alone misses files ship-builder just created (untracked) and anything
# already staged.
changed_files() {
	{
		git -C "$cwd" diff --name-only --diff-filter=ACM 2>/dev/null
		git -C "$cwd" diff --cached --name-only --diff-filter=ACM 2>/dev/null
		git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null
	} | sort -u
}

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
done < <(changed_files | grep -E '\.(sh|bash)$')

while IFS= read -r file; do
	[[ -f "$cwd/$file" ]] || continue
	if ! jq empty "$cwd/$file" 2>/dev/null; then
		errors+=("invalid JSON: $file")
	fi
done < <(changed_files | grep -E '\.json$')

if command -v stylua >/dev/null 2>&1; then
	while IFS= read -r file; do
		[[ -f "$cwd/$file" ]] || continue
		if ! stylua --check "$cwd/$file" >/dev/null 2>&1; then
			errors+=("stylua --check failed: $file")
		fi
	done < <(changed_files | grep -E '\.lua$')
fi

# Secrets: scan unstaged diff, staged diff, and untracked file contents.
# Scanning only the unstaged diff misses staged and newly created files.
secret_pattern='(password|secret|api_key|token)\s*[:=]\s*["'"'"'][^"'"'"']{8,}'
if {
	git -C "$cwd" diff 2>/dev/null
	git -C "$cwd" diff --cached 2>/dev/null
	while IFS= read -r file; do
		[[ -f "$cwd/$file" ]] && command cat "$cwd/$file"
	done < <(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null)
} | grep -qEi "$secret_pattern"; then
	errors+=("potential secret detected in changes")
fi

if ! git -C "$cwd" diff --check >/dev/null 2>&1; then
	errors+=("git diff --check failed (trailing whitespace or conflict markers, unstaged)")
fi
if ! git -C "$cwd" diff --cached --check >/dev/null 2>&1; then
	errors+=("git diff --check failed (trailing whitespace or conflict markers, staged)")
fi

if [[ ${#errors[@]} -gt 0 ]]; then
	{
		printf 'ship-gate BLOCKED:\n'
		for err in "${errors[@]}"; do
			printf '  - %s\n' "$err"
		done
		printf '\nFix these before the slice can pass critique.\n'
	} >&2
	exit 2
fi
