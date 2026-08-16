# Corpus

Comments harvested from source already on this machine: CPython 3.9 stdlib, the macOS SDK C headers, and Neovim Lua plugins. Nobody wrote these for a style guide. Read them before rewriting anything, and imitate them instead of the rules in `voice-profile.md` wherever the two disagree.

Reproduce the harvest:

```bash
PY=$(python3 -c "import sysconfig;print(sysconfig.get_paths()['stdlib'])")
grep -rhn --include="*.py" -E "^\s+#\s*(XXX|HACK|NB|Note:|BUG|FIXME)" "$PY"
grep -rh --include="*.h" -E "^\s*/\* .*(must|don't|never|hack|historical|compat) " \
  /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include
```

## Open questions, left open

```
# XXX what if encoded_part has no leading FWS?
# XXX else: raise ???
# XXX what error should be raised here?
# FIXME: what if the selector is "*" ?
# FIXME: can this be handled in XML 1.0?
# XXX selector: what about proxies and full urls
```

A real comment is allowed to not know. Generated comments always resolve.

## Blunt, resigned, funny

```
# too bad -- don't die here.
# but don't match "from future_builtins" :)
# 1 - change icon (we don't support this)
# don't bother reporting the empty string
-- Attention: use this only when testing
```

## Citations and constraints

```
# XXX according to RFC 2818, the most specific Common Name
# XXX Strictly you're supposed to follow RFC 2616
/* must be == _POSIX_STREAM_MAX <limits.h> */
/* Note: 'handler' must be in this same lexical context! */
/* state variable - do not modify */
/* --- the parameters below are private - do not modify --- */
/* RD and WR are never simultaneously asserted */
/* kHFSAttributeDataFileID is never stored on disk. */
```

## Rationale

```
# This is safe because there is no arm64 variant for
# because otherwise unknown charset is a silent
# This check is fine because the OPTCRE cannot
# We can't offer automatic processing of
# This includes raw_input as a workaround for the
-- don't abort, have to see all potential nodes to find longest match.
-- so we don't have to handle it here.
```

## Texture worth copying

Inconsistent spacing (`#otherwise fall through and fail`). Contractions everywhere. Sentences that wrap mid-clause onto the next comment line and finish there. Trailing thoughts. Lowercase starts next to capitalized ones in the same file. Nothing is uniform, because nobody enforced uniformity.

## What this corpus falsifies

Five rules stated elsewhere in this skill are too broad. The corpus wins.

**First person plural is normal.** "we don't need to update the snipstr_map", "We can't offer automatic processing of", "so we don't have to handle it here". Working "we" meaning this code is ordinary human idiom. The tell is narrating "we" that walks the reader through the next line ("here we iterate over the list"). Ban the narration, keep the idiom.

**"Note:" is normal.** `/* Note: 'handler' must be in this same lexical context! */` flags a real footgun. It is a tell only when what follows is trivial.

**"This is safe because" is normal** when an actual reason follows, as in `# This is safe because there is no arm64 variant for`. It is a tell when the clause after "because" restates the claim.

**"ensure" is normal.** It appears in the Lua corpus. Prefer a plainer verb, but a comment is not defective for containing the word.

**Parallel comments over parallel code are normal.**

```
-- don't abort, have to see all potential nodes to find longest match.
-- don't abort, have to see all potential nodes to find shortest match.
```

Two near-identical comments describing two near-identical branches. The Tier 1 rule about parallel structure means parallel comments over code that is *not* parallel. Repetition that mirrors real repetition in the code is correct.
