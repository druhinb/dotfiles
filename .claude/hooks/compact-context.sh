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

# The SessionStart/compact matcher already restricts when this hook fires;
# this is just a defensive check in case that matcher ever widens. Exit
# quietly rather than surfacing noise for something that shouldn't happen.
[[ "$event" == $'SessionStart\tcompact' ]] || exit 0

printf '%s\n' \
	'Dotfiles workflow context: the repository files are symlink sources; setup.sh owns linking and dependency installation. Claude Code remains terminal-first inside tmux, Ctrl+g hands text to Neovim, and Neovim autoreads external edits. Existing user changes are preserved, relevant path-scoped rules are re-read before edits, and commits, pushes, or destructive commands remain manual.'
