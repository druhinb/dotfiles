---
name: systematic-debugging
description: Use when investigating a non-trivial bug, failing test, or regression — any time the cause is not already known. Provides a root-cause loop: reproduce, isolate, instrument, fix at the cause, prove with a regression test.
---

# Systematic debugging

Guessing is the expensive path. Every step below either shrinks the search space or produces evidence; if a step does neither, skip it.

## The loop

1. **Reproduce first.** Find the smallest deterministic command that shows the failure. No reproduction means no way to know a fix worked; if it only fails sometimes, make the loop that demonstrates the failure rate the reproduction.
2. **Read the whole error.** The first error in the output, not the last; the cause, not the cascade. Stack traces are read bottom-up for origin, top-down for entry point.
3. **Isolate by bisection.** Binary-search whatever dimension is largest: `git bisect` for regressions across commits, delete half the input, disable half the config, stub half the pipeline. Each cut should eliminate half the remaining suspects.
4. **Instrument the boundary.** Add targeted logging or assertions at the frontier between "known good" and "unknown", then move the frontier. Don't scatter prints everywhere and stare.
5. **One hypothesis at a time.** Write the hypothesis down, pick the cheapest test that would discriminate it from the alternatives, run that test. Never change two variables in one experiment.
6. **Fix the cause, not the symptom.** If the fix lands exactly where the error appeared, be suspicious — errors usually surface downstream of their cause. Ask what allowed the bad state to exist.
7. **Prove it.** Add a regression test that fails before the fix and passes after. Re-run the wider relevant suite to check for collateral damage.
8. **Clean up.** Remove every experiment: instrumentation, stubs, disabled config. The worktree ends with the fix and its test, nothing else.

## Stop conditions

- Two dead hypotheses in a row: stop guessing. Re-read the failing code path end-to-end before forming a third.
- Thirty minutes without shrinking the search space: write down what is known, what is eliminated, and what evidence would discriminate the remaining suspects — then reassess or ask.
