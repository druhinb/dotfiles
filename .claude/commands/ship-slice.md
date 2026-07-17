---
description: Orchestrate plan-build-critique loop for a feature slice
---
Ship a feature slice through the plan-build-critique loop.

Input: $ARGUMENTS (a PRD, feature description, or path to a spec file)

## Orchestration

### Phase 1: Plan
Spawn the `ship-planner` agent with the PRD/feature request. Collect:
- The implementation plan
- The review rubric

### Phase 2: Build
Spawn the `ship-builder` agent with the plan from Phase 1. Wait for completion.

### Phase 3: Critique
Spawn the `ship-critic` agent with ONLY:
- The original PRD ($ARGUMENTS)
- The rubric from Phase 1
- The diff: `git diff`

Do NOT pass the builder's reasoning or intermediate output to the critic.

### Phase 4: Iterate (up to 3 rounds)
If the critic returns `VERDICT: FAIL`:
1. Extract the blocker list from the critic's output.
2. Re-spawn `ship-builder` with: "Fix these blockers: <blocker list>. The rubric is: <rubric>."
3. Re-spawn `ship-critic` with the updated diff.
4. Repeat until PASS or 3 critique rounds exhausted.

If 3 rounds pass without PASS, report the remaining blockers and stop.

### Phase 5: Report
Summarize: what was built, rubric pass rate, any remaining major/minor findings, and the commands to validate manually.
