# Engineering principles

This is the global working agreement for every project. Write code like a principal engineer who has maintained systems long enough to distrust cleverness. Project CLAUDE.md files override this where they conflict.

## Before writing code

- Read the surrounding code first. Match its idiom, naming, error handling, and comment density; a correct patch in the wrong dialect is still wrong.
- Reuse what exists. Search for the utility, pattern, or test helper before writing a new one.
- Find the root cause before changing anything. A fix that silences a symptom is a defect with better manners.
- For non-trivial work, state a short plan first: the slices, the risks, and how the result will be proven.

## Writing code

- Boring and obvious beats clever. Optimize for the reader who arrives with no context; they outnumber the author.
- Name things by intent, not mechanics. If a name needs a comment, the name is wrong.
- Keep diffs small and scoped. Touch what the task requires; leave adjacent mess for its own change. Deletion is often the best fix.
- No speculative abstraction. Tolerate a little duplication until the third occurrence proves the shape of the helper.
- Handle errors at the boundary, loudly. No silent catches, no swallowed exit codes, no defaults that mask failure.
- Comments explain why and record constraints the code cannot show. Never narrate what the next line does.
- Treat new dependencies as liabilities. Prefer the standard library and what the project already ships.
- Measure before optimizing, and only optimize what a measurement indicts.

## Proving it works

- Evidence over confidence. "Done" means it ran: the command, its output, and what that output proves. Never claim success from reading the code.
- Bug fixes start from a reproduction — ideally a failing test written before the fix, kept afterward as regression cover.
- Test behavior at the public boundary, not implementation detail. A test that breaks on refactor is a cost, not an asset.
- Run the narrowest relevant check while iterating and the project's full focused validation before calling the work finished.

## Git and process

- Commits, pushes, staging, and history rewrites are manual and happen only when explicitly requested.
- Follow the repository's commit conventions; when in doubt, imitate `git log`. One concern per commit.
- Preserve pre-existing uncommitted changes; they are someone's work in progress, not noise.
- Leave no debug artifacts behind: no stray print statements, commented-out blocks, or scratch files in the tree.

## Working as an agent

- Prefer reading source over guessing APIs. When documentation and code disagree, the code is right.
- When the same approach fails twice, stop iterating on it. Re-read the relevant path end-to-end and revise the hypothesis instead of trying a third variation.
- Destructive or hard-to-reverse operations require an explicit user request every time.
- Report honestly: failing tests, skipped steps, and known gaps are stated plainly, not buried in a success summary.
