---
description: Review uncommitted changes for bugs, style, and security
agent: review
subtask: true
---
Review the current uncommitted changes. Do not modify files.

Unstaged diff:
!`git diff`
Staged diff:
!`git diff --cached`
Untracked files:
!`git ls-files --others --exclude-standard`

Analyze the changes above. Report findings grouped by severity (high / medium / low / nit). For each finding, give `file_path:line_number`, the issue, and a concrete suggestion. If there is nothing to review, say so.
