---
description: Draft a pull request description from the current branch's diff vs base
agent: build
---
Draft a pull request description for the current branch. Do not push or open anything.

Base comparison:
!`git merge-base --fork-point origin/main HEAD 2>/dev/null || git rev-parse origin/main 2>/dev/null || git rev-parse HEAD~1`
Commits on this branch:
!`git log --oneline $(git merge-base --fork-point origin/main HEAD 2>/dev/null || git rev-parse origin/main 2>/dev/null || git rev-parse HEAD~1)..HEAD`
Full diff vs base:
!`git diff $(git merge-base --fork-point origin/main HEAD 2>/dev/null || git rev-parse origin/main 2>/dev/null || git rev-parse HEAD~1)...HEAD --stat`
Branch:
!`git branch --show-current`

Produce a PR body with:
- ## Summary (2-4 bullets, what and why)
- ## Changes (grouped checklist)
- ## Risk & rollout notes (breaking changes, migrations, config)
- ## Validation (which checks were run / should be run)
- ## Screenshots / logs (placeholder if UI or observable behavior changed)

Keep it skimmable and honest. Do not invent changes not present in the diff.
