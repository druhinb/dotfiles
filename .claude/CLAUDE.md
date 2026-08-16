# Engineering principles

This is the global working agreement for every project. Write code like a principal engineer who has maintained systems long enough to distrust cleverness. Project CLAUDE.md files override this where they conflict.

## Before writing code

- Read the surrounding code first. Match its idiom, naming, error handling, and comment density; a correct patch in the wrong dialect is still wrong.
- Reuse what exists. Search for the utility, pattern, or test helper before writing a new one.
- Find the root cause before changing anything. A fix that silences a symptom is a defect with better manners.
- Restate the acceptance criteria before starting; if the task has none, say what "done" will mean.
- For non-trivial work, state a short plan first: the slices, the risks, and how the result will be proven.

## Writing code

- Boring and obvious beats clever. Optimize for the reader who arrives with no context; they outnumber the author.
- Elegance is less to read, not more machinery. A new layer must remove more than it adds.
- Name things by intent, not mechanics. If a name needs a comment, the name is wrong.
- Keep diffs small and scoped. Touch what the task requires; leave adjacent mess for its own change. Deletion is often the best fix.
- No speculative abstraction. Tolerate a little duplication until the third occurrence proves the shape of the helper.
- One function, one job. Split an N-phase function into named phase helpers so the top level reads as an outline.
- Dispatch on data, not a wall of `if`/`else`. Branches differing only by a key and which field they set become a table and one driver loop. Keep the exhaustive `switch` where a missing case must be a compile-time or startup failure.
- Validate an input once, at the boundary, next to where the raw value lives. Don't smear it across the parser, a later range check, and a third validator. Code past the boundary assumes validated input.
- Handle errors at the boundary, loudly. No silent catches, no swallowed exit codes, no defaults that mask failure. Propagate with the project's existing idiom instead of hand-rolling the same check after every call.
- Treat new dependencies as liabilities. Prefer the standard library and what the project already ships, and ask before adding one.
- Measure before optimizing, and only optimize what a measurement indicts.

## Comments

Comments explain why and record constraints the code cannot show. Default to none and earn each one: most functions get zero. Write one only when the reason for a choice isn't visible in the code, a numeric or bit trick needs the math spelled out to be checkable, a workaround for an upstream bug or spec ambiguity needs a citation, or a real footgun needs naming ("must be called before X or the cache is stale").

These are defects, not style preferences:

- Never narrate the next line, and never restate an identifier in prose.
- No contrastive framing: no "X, not Y", "not X but Y", "instead of X". State what is true and drop the rejected alternative.
- No rhetorical structure: no "why?", no "the trick:", no "note:", no "important:", no colon-then-explanation.
- No first person: never "we", "our", "here we", "let's". No gerund openers ("handling the case where", "ensuring that").
- Banned words: ensure, handle, robust, gracefully, simply, properly, carefully, elegant, clean, crucial, essentially, effectively, leverage, edge case, sanity check.
- No adjectives or adverbs unless load-bearing. "unaligned" is load-bearing, "carefully" is not.
- "to avoid X" only when X names a concrete observed failure, never a hypothetical.
- No two adjacent comments with the same grammatical shape; parallel structure across comments is a tell.
- Keep them short and lowercase unless the file's existing style says otherwise; match the surrounding density.

## Proving it works

- Evidence over confidence. "Done" means it ran: the command, its output, and what that output proves. Never claim success from reading the code.
- Bug fixes start from a reproduction — ideally a failing test written before the fix, kept afterward as regression cover.
- Test behavior at the public boundary, not implementation detail. A test that breaks on refactor is a cost, not an asset.
- Run the narrowest relevant check while iterating and the project's full focused validation before calling the work finished.

## Git and process

- Commits, pushes, staging, and history rewrites are manual and happen only when explicitly requested.
- Follow the repository's commit conventions; when in doubt, imitate `git log`.
- One concern per commit. Never mix a behavior change with a rename, reformat, or optimization; if the message needs "and", split it.
- Name the thing that changed, not the quality it gained: `retry token refresh on 401`, not `improve auth reliability`. Banned: improve, enhance, cleanup, various, minor, better, robust, streamline, polish.
- No commit body unless the change has genuinely unrelated parts. No co-author or generation footers.
- Preserve pre-existing uncommitted changes; they are someone's work in progress, not noise.
- Leave no debug artifacts behind: no stray print statements, commented-out blocks, or scratch files in the tree.
- Never mention CLAUDE.md, prompts, or AI assistance in code, comments, docs, or commit messages.

## Working as an agent

- Prefer reading source over guessing APIs. When documentation and code disagree, the code is right.
- When the same approach fails twice, stop iterating on it. Re-read the relevant path end-to-end and revise the hypothesis. If the revised attempt also fails, summarize what is known and ask rather than trying a fourth variation.
- Documented invariants (architecture, data layout, protocol order) are binding. Update the doc first, in its own change, before writing code that deviates.
- Destructive or hard-to-reverse operations require an explicit user request every time.
- Report honestly: failing tests, skipped steps, and known gaps are stated plainly, not buried in a success summary.
