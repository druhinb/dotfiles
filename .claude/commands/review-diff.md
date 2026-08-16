---
description: Review uncommitted changes for bugs, style, and security
allowed-tools: Bash(git diff:*), Bash(git ls-files:*), Bash(git status:*)
---
Review the current uncommitted changes. Do not modify files.

Unstaged diff:
!`git diff`
Staged diff:
!`git diff --cached`
Untracked files:
!`git ls-files --others --exclude-standard`

Review adversarially, as the engineer who must sign off before this ships. Read enough surrounding code to judge each change in context instead of taking the diff at face value. Check in this order:
1. Correctness: broken behavior, unhandled errors, missed edge cases, races, off-by-one.
2. Security: leaked secrets, injection, permissions widened without need.
3. Design: fixes at the wrong layer, speculative abstraction, code that fights the surrounding idiom.
4. Style and nits last.

Report findings grouped by severity (high / medium / low / nit). For each finding, give `file_path:line_number`, the issue, and a concrete suggestion. Also state what you checked and found clean, so silence is meaningful. If there is nothing to review, say so.
