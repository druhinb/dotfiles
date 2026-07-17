# Dotfiles repository guidance

## Purpose and workflow

This repository is the source of truth for a terminal-first development environment. tmux owns layout, Claude Code runs in terminal panes, and Neovim remains `$EDITOR`/`$VISUAL`. In Claude Code, `Ctrl+g` opens the external editor; in tmux, prefix then `Ctrl+g` opens Claude in a split rooted at the current pane.

Do not add an in-Neovim agent plugin or another agent multiplexer. Neovim's autoread hooks already reflect edits made by Claude and other terminal tools.

## Repository layout

- `zsh/`: `.zshenv`, `.zprofile`, and interactive `.zshrc`.
- `tmux/`: tmux configuration; TPM owns plugins at runtime.
- `nvim/.config/nvim/`: modular Kickstart/lazy.nvim configuration and its nested `CLAUDE.md`.
- `.claude/`: shared Claude Code settings, keybindings, path-scoped rules, hooks, and status-line scripts.
- `.codex/`: project-level Codex settings. `codex/.codex/` contains global
  Codex guidance and custom subagent profiles linked by `setup.sh`.
- `agents/skills/`: canonical shared skills, linked into Claude Code, Codex,
  and OpenCode without replacing Codex's bundled `.system` skills.
- `opencode/`: opencode global config (`opencode.json`, `tui.json`), agents, and commands, linked into `~/.config/opencode/`. A repo-root `opencode.json` adds path-scoped rules and a `/validate` command for this repo.
- `vim/`, `wezterm/`, `starship/`, `atuin/`, `karabiner/`, and `ideavimrc/`: application-owned configuration sources.
- `setup.sh`: package installation, symlink creation, plugin bootstrap, and smoke-test orchestration.

## Symlink ownership

Edit the versioned source in this repository, not the linked file under `$HOME`.

`setup.sh` links individual zsh, tmux, Vim, Claude, Codex, OpenCode, and
application files, and links the full Neovim directory to `~/.config/nvim`.
Shared skill directories are linked individually into all three agent clients.
Before replacing an existing target, `link_file` moves it into a timestamped
backup directory. Add any new runtime script or hook to `link_dotfiles` during
the integration phase; creating links by hand is not the lasting fix.

Machine-specific shell paths belong in the untracked `~/.zshrc.local`, never in the shared zsh files.

## Safe editing

- Inspect `git status` and the relevant diff before editing. Preserve unrelated or in-progress user changes.
- Keep macOS as the primary platform without unnecessarily breaking Linux/devspace use.
- Prefer guarded optional integrations and lazy loading over unconditional startup work.
- Do not commit, push, stage broad file sets, rewrite history, discard changes, or run destructive commands unless the user explicitly requests that action.
- Do not run full setup, plugin updates, Mason installs, or clean-machine workflows as routine validation.
- Keep generated caches, credentials, and machine state out of versioned configuration; keep truly machine-local overrides untracked.

Path-specific conventions live in `.claude/rules/` and load when matching files are read. The nested Neovim guidance describes its current plugin and language-tooling architecture.

## Focused validation

Run only checks relevant to changed files:

```bash
jq empty .claude/settings.json .claude/keybindings.json opencode/.config/opencode/opencode.json opencode/.config/opencode/tui.json opencode.json
bash -n setup.sh .claude/statusline.sh .claude/subagent-statusline.sh .claude/hooks/*.sh
zsh -n zsh/.zshenv zsh/.zprofile zsh/.zshrc
shfmt -d setup.sh .claude/*.sh .claude/hooks/*.sh
shellcheck setup.sh .claude/*.sh .claude/hooks/*.sh
stylua --check nvim/.config/nvim
./setup.sh --dry-run --skip-neovim-tools
git diff --check
```

For Neovim, use focused headless startup or module checks while iterating. Reserve `:Lazy sync`, Mason installation, full `:checkhealth`, every-language workflows, Claude `/doctor` and UI command checks, and clean tmux/SSH validation for the final integration phase.

## Context preservation

When summarizing or compacting a long task, retain the user's requested file ownership, existing dirty-worktree boundaries, validation already run, unresolved setup/link/dependency follow-ups, and the rule that commits and destructive operations remain manual.
