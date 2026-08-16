# Target voice

The target is this repository's style, so the skill samples a profile from its own history instead of assuming one.

## Sampled profile

`scripts/comment-profile.sh [cutoff-date]` checks out the tree as of the last commit before the cutoff and reports, for line comments only:

- comment density per 100 lines of source
- median and 90th-percentile comment length in words
- share starting with a lowercase letter
- share ending in a period
- share containing a citation (ticket, RFC, CVE, URL, name)
- a random sample of 25 comments

Density and the sample matter most. Match the density by deciding how much to delete; match the sample by reading it and imitating the voice directly.

Capitalization and terminal punctuation do not follow the sample by default. Write lowercase with no terminal period regardless of what the percentages say, and defer to the file only when it is lopsided: `lowercase` under 30%, or `period` at 70% or more. A repository split near the middle gets the default, since that split means no convention exists to honor.

Report which cutoff you used and how many comments the sample drew from. Below roughly 20 comments the percentages are noise; use the fallback and say so.

## Fallback profile

For a repository with no usable pre-cutoff history. Grounded in the survey work cited in `markers.md` and in the conventions of long-lived open-source C, Python and Go.

**Shape.** Fragments over sentences. Lowercase start, no terminal period, ascii only, one line. A block comment carrying several sentences punctuates them normally, but still opens lowercase. No wrapping decoration.

**Content.** A comment earns its place by carrying what the code cannot:

- why this approach and not the obvious one
- the math behind a numeric or bit trick, spelled out enough to check
- a workaround for an upstream bug or spec ambiguity, with a citation
- a real footgun: ordering requirements, invalidation, thread affinity
- a constraint imposed from outside the file

**Voice.** Direct and unhedged. Blunt is fine; "this is a hack" is a legitimate and useful comment. Domain jargon goes unglossed. Name the bug, the standard, the version, the failure you saw.

**Density.** Bursty. Cluster comments where the code is subtle and leave straightforward code bare. Uniform density is the marker you are removing, so do not swap one uniform density for a lower one.

## Editing rules

Apply after classification, when rewriting a survivor.

1. Cut metadiscourse entirely. Anything about the comment rather than the code goes.
2. Remove hedges. If the claim is true, state it; if you cannot verify it, either check or say the specific thing you do know.
3. Drop the rejected alternative. "X, not Y" becomes "X".
4. Name the actor. "quotes are stripped first" becomes "kalshi strips quotes first". If no actor is worth naming, the comment is usually not worth keeping.
5. Un-nominalize. "performs a validation of the input" becomes "validates the input", and then usually deletes entirely as restatement.
6. Delete adverbs that duplicate the verb. "properly validates" is "validates".
7. Replace the abstract with the concrete. "handles edge cases" is worthless; "rejects trailing commas" is a comment.
8. Break parallel structure with a neighbor. If two adjacent comments have the same shape, at least one is wrong.
9. Re-read the result and ask whether it still says anything. Most rewrites should end as deletions.
