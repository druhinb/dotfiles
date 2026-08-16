---
name: humanize-comments
description: Use when comments or docstrings read as machine-written, after a large AI-assisted change, before opening a PR, or when asked to "humanize", "de-slop", or "clean up" comments. Deletes low-information comments and rewrites the survivors into the repository's own historical voice.
---

# Humanize comments

Comments that read as generated share one cause: essay register applied to a genre that rejects it. Expository prose rewards hedging, signposting, and metadiscourse. A comment about deterministic code rewards none of them.

The fix is mostly deletion. The strongest marker is uniform density, a comment on every block spread evenly through the file. Rewording each one preserves that density and the file still reads as generated. Cut first, rewrite what survives.

Two failure modes to avoid: a thesaurus pass that swaps banned words and changes nothing structural, and a careless pass that destroys load-bearing text. `references/markers.md` is the detection taxonomy and the do-not-touch list. Read it before classifying anything.

## 1. Establish scope

Default with no argument: files with uncommitted changes, via `git diff --name-only HEAD` plus untracked files from `git ls-files --others --exclude-standard`.

A path or glob argument overrides that. `--all` sweeps every tracked source file; warn that the diff will be large and confirm before starting. Skip vendored trees, generated code, minified assets, and lockfiles.

## 2. Derive the target voice

Do not impose a generic house style. Match what this repository already sounds like.

```bash
scripts/comment-profile.sh              # samples comments from before 2022-11-30
scripts/comment-profile.sh 2020-01-01   # different cutoff
```

The cutoff defaults to just before generated comments became common, so the sample reflects human authorship. Read the profile it prints: comment density per 100 lines, median length, whether comments start lowercase, whether they end in a period, and a random sample to read directly.

The sample is the point. Read those comments and imitate them. If the repository has no history before the cutoff, or the sample is under ~20 comments, read `references/corpus.md` and imitate that instead, then say which source you used.

Read `references/corpus.md` either way. It holds real comments from CPython, the macOS SDK headers, and Neovim plugins, and it is the only part of this skill that shows the target rather than describing it. Where the corpus and the written rules disagree, the corpus wins.

Mechanical defaults, whichever profile you land on: lowercase start, no terminal period, ascii only, one line. Override only when the printed profile is lopsided the other way, meaning `lowercase` under 30% or `period` at 70% or more. Say so when you do.

## 3. Classify every comment in scope

Three outcomes. Assign one to each comment before editing anything.

**Delete.** The comment carries no information the code does not already carry. Next-line narration, identifier restatement, language tutorials, and docstrings on trivial functions all land here. This should be the most common outcome by a wide margin; a pass that deletes nothing has almost certainly failed to look.

**Rewrite.** The comment carries information in the wrong register. Keep the fact, drop the hedging, metadiscourse, contrastive framing, and adverbs. Usually this makes it much shorter. Check the result against the generator signatures section of `references/markers.md`; clearing the vocabulary list while keeping the sentence shape fixes nothing.

**Keep.** It already reads as human, or it appears in the do-not-touch list.

When a comment's only value is that it names a constraint you cannot verify, keep it. Deleting a warning because it sounds generated is worse than leaving one awkward sentence.

## 4. Apply

Edit directly. Watch three footguns:

- **Never change a non-comment line.** Not a rename, not a reformat, not a fix for a bug you noticed. Note it and raise it separately.
- **Python docstrings are runtime objects.** Deleting the sole statement of a function body is a `SyntaxError`; leave `pass` or keep the docstring. Anything reachable by `__doc__`, doctest, or a documentation build stays.
- **Comment-shaped directives are code.** `# noqa`, `// eslint-disable`, `//go:build`, `#pragma`, `// nolint`, `@ts-ignore`, type comments, and coverage pragmas are never touched.

Do not fix density by adding comments. If a genuinely hard passage has none, say so in your report and let the author decide.

## 5. Print the ledger

Direct edits to already-dirty files mean `git diff` will not isolate this work. Print a record grouped by file:

```
src/parser.rs
  L44  delete   narrates the next line
  L91  rewrite  hedging removed: "should generally handle" -> "rejects trailing commas"
  L120 keep     cites RFC 8259 section 9
```

Close with counts: deleted, rewritten, kept, files touched.

## 6. Verify

State the evidence, do not assert success:

- Confirm no code changed. `git diff -U0 -- <files>` and check every `+`/`-` line is a comment or blank.
- Run the cheapest check that would catch a broken file: the project's syntax check, linter, or focused test.
- For Python, import the module if you touched a docstring.

Report what ran and what it proved. If a file's checks fail, revert that file and say so.
