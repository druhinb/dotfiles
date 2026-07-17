---
description: Systematically root-cause a bug or test failure (read-only)
agent: debug
subtask: true
---
Root-cause this issue. Do not fix it; find and explain the cause.

$ARGUMENTS

Start by reproducing or locating the failure. Useful context:
- Recent changes: !`git log --oneline -10`
- Working tree: !`git status --short`
- Unstaged diff: !`git diff`

Follow the debug agent's method: reproduce, localize (cite `file_path:line_number`), hypothesize, verify with a minimal check, then report the root cause with a certainty level, the fix direction (do not apply), and the smallest test that would have caught it.
