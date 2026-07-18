---
description: Generate a Conventional Commit message from staged or working-tree changes
allowed-tools: Bash(git diff:*), Bash(git log:*)
---
Write a commit message for the current changes. Do not stage or commit.

Staged diff:
!`git diff --cached`
Working-tree diff (used only if nothing is staged):
!`git diff`
Recent commit style:
!`git log --oneline -10`

If nothing is staged, say so clearly and base the message on the working-tree diff. If the diff mixes unrelated concerns, propose a split into separate commits, each scoped to one concern with its own message. Output one Conventional Commits message per proposed commit in a fenced block, matching the tone and scope conventions of recent history, then state whether changes are currently staged.
