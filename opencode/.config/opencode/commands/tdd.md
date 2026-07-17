---
description: Test-driven development flow for a feature or change
---
Apply strict TDD for: $ARGUMENTS

Cycle RED -> GREEN -> REFACTOR, one slice at a time:

1. RED: Write the smallest failing test that captures the next slice of behavior. Run it and confirm it fails for the right reason (not a setup error).
2. GREEN: Write the minimal code to make that test pass. Run it and confirm green.
3. REFACTOR: Improve names, remove duplication, and keep tests green. Re-run after each change.

Rules:
- Never write production code without a failing test first.
- One behavior per test. Commit (mentally) at each green.
- If a test is hard to write, the design is wrong — stop and propose a refactor instead of forcing the test.
- After the final green, run the relevant focused validation (lint, typecheck, the new tests) and report results.

Ask before running anything that stages, commits, or mutates git state.
