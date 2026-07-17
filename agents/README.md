# Shared Agent Resources

`skills/` is the single versioned source for reusable skills. `setup.sh` links
each skill directory into all three clients:

- `~/.claude/skills/<name>`
- `~/.codex/skills/<name>`
- `~/.config/opencode/skills/<name>`

The per-skill links keep Codex's bundled `~/.codex/skills/.system` skills in
place. Do not edit a client link or an installed snapshot directly; edit the
source here and rerun setup.

Custom subagent formats are client-specific. OpenCode profiles live in
`opencode/.config/opencode/agents/`; Codex profiles live in
`codex/.codex/agents/`. Both expose the same role names where the client can
support them: `plan`, `review`, `debug`, `docs`, `test-writer`, and `commit`.
Keep their scope and safety rules aligned when changing a role.
