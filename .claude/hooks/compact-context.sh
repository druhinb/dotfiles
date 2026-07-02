#!/usr/bin/env bash
# Reinforce the small amount of workflow context that compaction can discard.

set -u

if ! command -v jq >/dev/null 2>&1; then
	printf 'Claude compact hook requires jq\n' >&2
	exit 1
fi

input=$(command cat)
if ! event=$(printf '%s' "$input" | jq -er '[.hook_event_name // "", .source // ""] | @tsv'); then
	printf 'Claude compact hook received invalid JSON\n' >&2
	exit 1
fi

if [[ "$event" != $'SessionStart\tcompact' ]]; then
	printf 'Claude compact hook expected a SessionStart compact event\n' >&2
	exit 1
fi

printf '%s\n' \
	'Dotfiles workflow context: the repository files are symlink sources; setup.sh owns linking and dependency installation. Claude Code remains terminal-first inside tmux, Ctrl+g hands text to Neovim, and Neovim autoreads external edits. Existing user changes are preserved, relevant path-scoped rules are re-read before edits, and commits, pushes, or destructive commands remain manual.'
