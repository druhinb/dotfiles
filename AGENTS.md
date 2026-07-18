# Dotfiles repository guidance for Codex

This repository is the source of truth for a terminal-first development
environment. tmux owns layout, terminal coding agents run in panes, and Neovim
remains `$EDITOR`/`$VISUAL`. Do not add another in-Neovim agent plugin or agent
multiplexer.

## Ownership

- Edit versioned sources in this repository, never their links under `$HOME`.
- `setup.sh` owns installation and all symlinks. Add persistent runtime files
  there instead of creating hand-managed links.
- `agents/skills/` is the canonical copy of shared skills. Setup links each
  skill into Claude Code, Codex, and OpenCode. Codex's built-in
  `~/.codex/skills/.system` directory is intentionally left untouched.
- `codex/.codex/` owns global Codex guidance and custom-agent profiles. Any
  agent `.toml` with a matching Claude source is generated from it by
  `sync-agents.sh`; edit `.claude/agents/*.md`, not the generated output.
- `opencode/` owns OpenCode's configuration, agents, and commands. Agents and
  commands with a matching Claude source (currently the ship-* set, verifier,
  ship-slice, review, commit, and tdd) are likewise generated from the Claude
  sources by `sync-agents.sh`; client-only agents and commands are hand-owned.
- Keep machine-specific shell setup in the untracked `~/.zshrc.local`.

## Safe editing

- Start with `git status` and inspect the relevant diff. Preserve unrelated or
  in-progress changes.
- Read the surrounding code and follow its conventions. Keep edits focused;
  do not reformat unrelated files or introduce dependencies unnecessarily.
- Do not commit, push, stage broad file sets, rewrite history, discard work,
  or run destructive commands unless explicitly requested.
- Do not run full setup, plugin updates, Mason installs, or clean-machine
  workflows as routine validation.
- Keep generated state, credentials, and machine-local configuration out of
  version control.

## Delegation

Use direct child agents only for independent, bounded work that benefits from
parallelism. Prefer the `plan`, `review`, `debug`, `docs`, `test-writer`, and
`commit` roles when their specialties match. Keep planning, review, debugging,
and commit-message tasks read-only; do not delegate trivial work.

## Focused validation

Run only checks relevant to changed files. Common checks are:

```bash
jq empty .claude/settings.json .claude/keybindings.json opencode/.config/opencode/opencode.json opencode/.config/opencode/tui.json opencode.json
bash -n setup.sh .claude/statusline.sh .claude/subagent-statusline.sh .claude/hooks/*.sh
zsh -n zsh/.zshenv zsh/.zprofile zsh/.zshrc
shfmt -d setup.sh .claude/*.sh .claude/hooks/*.sh
shellcheck setup.sh .claude/*.sh .claude/hooks/*.sh
stylua --check nvim/.config/nvim
./sync-agents.sh --check
./setup.sh --dry-run --skip-neovim-tools
git diff --check
```
