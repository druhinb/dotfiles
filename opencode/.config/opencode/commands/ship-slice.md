---
description: Plan-build-critique loop for shipping a feature slice
agent: build
---
Ship a feature slice through the adversarial plan-build-critique loop.

PRD / Feature request:
$ARGUMENTS

## Orchestration

### Phase 1: Plan
Delegate to the `ship-planner` agent with the PRD above. Collect the implementation plan and review rubric.

### Phase 2: Build
Delegate to the `ship-builder` agent with the plan from Phase 1.

### Phase 3: Critique
Delegate to the `ship-critic` agent with ONLY:
- The original PRD (from $ARGUMENTS above)
- The rubric from Phase 1
- The current diff: !`git diff`

Do NOT pass the builder's reasoning or intermediate output to the critic.

### Phase 4: Iterate (up to 3 rounds)
If the critic returns VERDICT: FAIL:
1. Extract the blocker list.
2. Re-delegate to `ship-builder`: "Fix these blockers: <list>. Rubric: <rubric>."
3. Re-delegate to `ship-critic` with the updated diff.
4. Repeat until PASS or 3 rounds exhausted.

### Phase 5: Report
Summarize: what was built, rubric pass rate, remaining findings, and manual validation commands.
