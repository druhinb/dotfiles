# Marker taxonomy

Three tiers, ordered by evidential strength. Tier 1 is the most reliable and the least visible; Tier 3 is the most visible and the least reliable. A pass that acts only on Tier 3 changes vocabulary and leaves the register intact, which is the common way this job gets done badly. The generator signatures section below covers what the tiers miss.

## Tier 1: distributional

Invisible in any single comment. Judge these by reading a whole file at once.

- **Uniform density.** A comment on every block, spread evenly. Human comment density is bursty: it spikes around the one subtle function and disappears for hundreds of lines. Density that tracks *line count* rather than *difficulty* is the single strongest marker.
- **Parallel grammatical structure across neighbors.** Three consecutive comments all opening with a gerund, or all shaped `Verb the noun`. Codebases accrete over years and across people, so real comments rarely rhyme. The exception matters: parallel code earns parallel comments, and `corpus.md` has two near-identical Lua comments over two near-identical branches. Convict when the comments rhyme and the code underneath does not.
- **Docstrings on trivial or private functions.** A full `Args:/Returns:/Raises:` block on `_get_name()`.
- **Uniform format compliance in an inconsistent project.** Every new function carrying a perfect docstring template while the surrounding code has none shows a generator applying a template where the project holds no convention.

Deletion fixes Tier 1. No wording repairs it.

## Tier 2: semantic

The comment exists but carries no information the reader could not get from the code.

- **Code/comment redundancy.** The comment is a natural-language transliteration of the line below it. This is a long-established defect, not a new one: Steidl, Hummel and Juergens (*Quality Analysis of Source Code Comments*, ICPC 2013) operationalize it as word overlap between a comment and the identifiers it describes. Generated comments simply saturate the metric.
- **Identifier restatement.** `// user manager` above `class UserManager`.
- **Language tutorial.** `// loop through the items`, `// increment the counter`, `// return the result`.
- **Speculative defensiveness.** Warning about a failure mode nobody has observed. "to avoid X" earns its place only when X is a concrete observed failure.
- **Aspirational description.** Describing intent rather than behavior, which goes stale silently the first time behavior diverges.
- **Restated summary.** A closing sentence in a docstring that recaps the opening one.

Default action: delete. Rewrite only if a fact is buried in it.

## Tier 3: lexical and rhetorical

Real signal, weak evidence. Careful humans write "ensure" too. Use these to find candidates, never to convict on their own.

**Vocabulary.** ensure, handle, robust, gracefully, seamlessly, simply, properly, carefully, elegant, crucial, essential, vital, appropriate, comprehensive, various, additional, leverage, utilize, facilitate, edge case, sanity check, under the hood, out of the box.

**Openers.** "This function…", "This method…", "This class is responsible for…", "Helper function to…", "Note that…", "It's important to note…", "Keep in mind…".

**Rhetoric.**
- Contrastive framing: "X, not Y", "rather than", "instead of". Advertises a rejected alternative the reader never proposed.
- The colon-explainer: "The trick: …", "Why? Because…".
- Signposting triplets: "First… Then… Finally…".
- Narrating first person: "here we", "let's", "we then". Working "we" for a constraint or a decision is ordinary idiom in real code; see `corpus.md`.
- Rule-of-three lists where two items would do.
- "not only… but also".

**Prose defects** (Williams, *Style: Lessons in Clarity and Grace*; Zinsser, *On Writing Well*). One rule from Williams drives most of this group: make the character the subject and the action the verb.

- Passive with the agent deleted: "quotes are stripped first" for "kalshi strips quotes first". In a comment the missing agent is almost always something the codebase can name, so the passive discards the most useful token in the sentence. Restoring it shortens the line and adds information at once.
- Passive with the agent trailing in a `by` phrase: "quotes are stripped by kalshi" for "kalshi strips quotes". Same facts, more words, subject and actor misaligned.
- Nominalization: "performs a validation of" for "validates".
- Adverb–verb redundancy: "effectively prevents", "properly validates".
- Metadiscourse: any clause about the comment instead of about the code.
- Hedge stacking: "should generally work in most cases".

Some passives are correct. Keep one when the agent is genuinely unknown, when the agent is the machine or the runtime and naming it adds nothing ("the page is swapped out"), or when the affected thing is the topic of the lines around it. Convict on the deleted agent, never on the auxiliary verb. A blanket hunt for `is` plus a participle mangles correct comments and is the usual way this rule gets applied badly.

**Formatting.** Emoji. `# ===== Section Banners =====`. Markdown bold inside a comment. Curly quotes, arrows, or checkmarks in an ASCII codebase. Title Case Headers. Trailing suggestions like "TODO: consider adding tests here".

## Generator signatures

Tier 3 catches vocabulary. It does not catch rhythm, and rhythm is what gives a rewrite away. A comment can clear every word check above and still read as generated because the sentence shape never changed. Check your own output against this list before accepting it.

**Punctuation and syntax**

- Em dash as the default connector, above all the appositive interruption: "the ledger, file and action and reason, because". Use a period. Split the sentence.
- Colon as drumroll: "Two failure modes:", "The rule:", "One caveat:".
- Balanced antithesis: "a cost, not an asset". The shape is the tell even when the claim is correct.
- Anaphoric triples: "not a rename, not a reformat, not a fix".
- Tricolon anywhere. Three examples where two would do. Three adjectives. Three clauses.
- A sentence fragment dropped after a full sentence for emphasis.

**Rhetorical moves**

- The reframe: "X is not A, it is B", "the real problem is", "what makes this work is".
- The aphoristic closer: a short, quotable, faintly witty declarative ending a paragraph.
- Concessive pivot: "X is fine. But Y."
- Cost metaphors for effort: cheap, expensive, pays for itself, buys you.
- Bold lead-in enumeration where every item is **Word.** followed by one sentence.
- Self-referential flagging: "worth noting", "worth flagging", "the point is", "the thing is".

**Boosters**

genuinely, actually, really, truly, precisely, exactly, simply, just, quite, particularly, specifically. These add emphasis without meaning. Delete one and check whether the sentence lost anything.

**In comments specifically**

- "Note:" or "Important:" in front of something trivial. Real code uses "Note:" for real footguns; the corpus has one.
- "This is safe because" with a clause that restates the claim. With an actual reason after it, the form is fine and appears in the stdlib.
- "our approach", "we then", and any "we" that walks the reader through the next line.
- "for now", "in a real implementation", "in production you would", "this is a simplified version". Scope disclaimers and apologies belong in a commit message or an issue.
- A paragraph of design rationale above a five-line function.
- Perfectly formed Args/Returns/Raises on every function including the trivial ones.

**Self-check**

This file and the skill around it are bound by these rules too. The most common failure is a rewrite that clears the Tier 3 vocabulary list and arrives as a balanced antithesis with an em dash. If your output matches anything in this section, it is not finished.

## Why hedging in particular

Academic register treats hedging as a virtue. Hyland's work on hedging in research articles frames "may suggest" and "typically" as marks of scholarly caution. Code comments invert this. The code is deterministic and the comment asserts something about a machine, so a hedge is either false or an admission the author did not check. Models trained heavily on expository prose import the hedging register wholesale, which is why it is the most consistent giveaway after density.

## What real comments do instead

Padioleau, Tan and Zhou (*Listening to Programmers*, ICSE 2009) surveyed comments across Linux, FreeBSD and OpenSolaris and found them clustered on information **not recoverable from the code**: cross-cutting constraints, rationale, historical residue. Pascarella and Bacchelli (MSR 2017) derived a sixteen-category taxonomy from Java open source in which the load-bearing categories are rationale, usage contracts, pointers to other code or issues, and warnings.

Read as prose, comments in long-lived codebases tend to be fragments rather than sentences; frequently lowercase with no terminal period; blunt to the point of rude ("this is a hack", "do not touch without reading RFC 2616 section 4.4"); specific about bugs, tickets, people and standards; free with unexplained domain jargon and abbreviations (wrt, iff, n.b., cf.); and wildly uneven in density.

## Do not touch

Not candidates, regardless of how they read.

- License and copyright headers, SPDX identifiers, attribution required by a license.
- Tool directives: `# noqa`, `# type:`, `// eslint-disable*`, `//go:build`, `//go:generate`, `// nolint`, `#pragma`, `@ts-ignore`, `@ts-expect-error`, coverage and formatter pragmas.
- Doctests, and any docstring consumed by a documentation build or asserted on by a test.
- Structured API documentation whose tags are read by tooling or type checkers: Javadoc and JSDoc `@param`/`@returns`/`@throws`, XML doc comments, Sphinx and rustdoc directives. Tighten the prose if you like; never drop a tag.
- Commented-out code. It is a separate cleanup with a different judgment call.
- Anything citing a ticket, CVE, RFC, standard section, or named person.
- `TODO`, `FIXME`, `HACK`, `XXX` markers. Tighten the prose after them; keep the marker.
- Files under vendored, generated, or third-party paths.
