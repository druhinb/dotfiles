---
description: Set, show, or clear a persistent north-star goal that survives compaction
---
Manage the north-star goal for this project. The goal lives in `GOAL.md` at the project root so it persists across compaction and restarts.

Branch on `$ARGUMENTS`:
- If `$ARGUMENTS` is empty: read `GOAL.md` (if it exists) and restate the current goal, progress so far, and the next concrete step. If no `GOAL.md`, say "No goal set — use `/goal <objective>`."
- If `$ARGUMENTS` is `clear`: delete `GOAL.md` and confirm.
- Otherwise: write `$ARGUMENTS` to `GOAL.md` (overwriting any prior goal), then re-read it and confirm the goal back in one line, followed by the first concrete step and a short plan.

Treat `GOAL.md` as the highest-priority context for all subsequent work: re-read it before major decisions and align all work with it. If a later request conflicts with the goal, surface the conflict and ask before proceeding.
