---
description: Generate a Conventional Commit message from staged or working-tree changes
agent: commit
subtask: true
---
Write a commit message for the current changes. Do not stage or commit.

Staged diff:
!`git diff --cached`
Working-tree diff (used only if nothing is staged):
!`git diff`
Recent commit style:
!`git log --oneline -10`

If nothing is staged, say so clearly and base the message on the working-tree diff. Output one Conventional Commits message in a fenced block, then state whether changes are currently staged.
