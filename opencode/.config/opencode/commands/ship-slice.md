---
description: "Orchestrate plan-build-critique loop for a feature slice"
agent: build
---
Ship a feature slice through the plan-build-critique loop.

Input: $ARGUMENTS (a PRD, feature description, or path to a spec file — if it is a path, read the file and use its contents as the PRD)

## Orchestration

### Phase 0: Baseline
Before any work, record `git status --porcelain` and the current branch. Files already dirty here are pre-existing user work: they must survive untouched, and findings in them are out of scope for the critic. If the PRD leaves open a decision only the user can make (scope boundaries, naming, anything destructive), ask the user now — downstream agents must not guess it.

### Phase 1: Plan
Spawn the `ship-planner` agent with the PRD and the baseline dirty-file list. Collect:
- The implementation plan
- The review rubric
- The out-of-scope list

### Phase 2: Build
Spawn the `ship-builder` agent with the plan, rubric, and baseline dirty-file list. Wait for completion.

### Phase 3: Critique
Spawn the `ship-critic` agent with ONLY:
- The original PRD ($ARGUMENTS)
- The rubric from Phase 1
- The baseline dirty-file list (changes confined to those files are not the builder's work)
- The full change set: `git diff`, `git diff --cached`, and the contents of new files from `git ls-files --others --exclude-standard`

Do NOT pass the builder's reasoning or intermediate output to the critic.

### Phase 4: Iterate (up to 3 rounds)
If the critic returns `VERDICT: FAIL`:
1. Extract the blocker list from the critic's output.
2. Re-spawn `ship-builder` with: "Fix these blockers: <blocker list>. The rubric is: <rubric>."
3. Re-spawn `ship-critic` with the updated change set.

If the same blocker survives two consecutive rounds, stop early and surface it to the user — a third identical attempt is guessing. Otherwise repeat until PASS or 3 critique rounds exhausted, then report the remaining blockers and stop.

### Phase 5: Verify
On PASS, spawn the `verifier` agent with the rubric's machine-checkable gates and the builder's key claims. If it returns `VERDICT: REFUTED`, treat each refuted item as a blocker and return to Phase 4 (it counts toward the 3-round budget).

### Phase 6: Report
Summarize: what was built, rubric pass rate, the verifier's verdict, any remaining major/minor findings, and the commands to validate manually. Nothing is committed or staged; that remains the user's call.
