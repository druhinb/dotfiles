# Dotfiles

Terminal-first development environment for macOS and Linux. macOS with Homebrew
is the primary platform; Debian/Ubuntu package installation is best-effort.

## Install

Review the script before running it:

```bash
./setup.sh --dry-run --skip-neovim-tools
./setup.sh
```

`setup.sh` installs command-line dependencies, backs up conflicting targets,
creates symlinks, installs shell/Vim/tmux/Neovim plugins, installs the Neovim
tooling inventory, and may change the login shell to zsh. Use
`--skip-neovim-tools` to skip Mason tools and Tree-sitter parsers.

Machine-specific shell paths and environment setup belong in the untracked
`~/.zshrc.local`.

## Ownership

- This repository owns configuration sources; edit these files rather than
  their symlinks under `$HOME`.
- `setup.sh` owns package installation, symlinks, Oh My Zsh plugins, and TPM
  bootstrap.
- TPM owns runtime tmux plugins under `~/.tmux/plugins`.
- lazy.nvim owns Neovim plugins; `lazy-lock.json` pins them.
- `nvim/.config/nvim/lua/tooling.lua` is the single inventory for Mason
  packages, formatters, linters, debuggers, tests, and Tree-sitter parsers.
- `agents/skills/` is the single versioned source for shared agent skills.
  `setup.sh` links each skill to Claude Code, Codex, and OpenCode while
  preserving Codex's bundled `.system` skills. `codex/.codex/` supplies global
  Codex guidance and custom `plan`, `review`, `debug`, `docs`, `test-writer`,
  and `commit` subagent profiles; `.codex/config.toml` sets bounded,
  repository-level multi-agent defaults without replacing deCLAWd-managed
  authentication, provider, or sandbox settings.
- `opencode/` is the source for the global opencode config (`opencode.json`,
  `tui.json`), custom agents (`build`, `plan`, `review`, `debug`, `commit`,
  `docs`, `test-writer`), and commands (`/review`, `/tests`, `/explain`,
  `/goal`, `/commit`, `/pr`, `/debug`, `/tdd`, `/validate`); `setup.sh` links
  them into `~/.config/opencode/`. Its `small_model` is
  `llm-gateway/kimi-k2.6`, as confirmed by OpenCode's gateway logs. A repo-root
  `opencode.json` scopes rules and a `/validate` command to this dotfiles repo.

## Language support

- Python: basedpyright, Ruff, debugpy, pytest/neotest.
- TypeScript/JavaScript/React: vtsls, web LSPs, prettierd, eslint_d, js-debug,
  Jest, and Vitest.
- C/C++: clangd, clang-format, cpplint, codelldb, and CMake.
- Rust: rust-analyzer, rustfmt/clippy, codelldb, and cargo/neotest.
- Go: gopls, goimports/gofumpt, golangci-lint, Delve, and neotest-go.
- Java: jdtls, google-java-format, Java debug/test bundles.
- C#: Roslyn, CSharpier, netcoredbg, and neotest-dotnet.
- Lua/config/infra: Lua, shell, Markdown, YAML, JSON, TOML, Docker, and SQL
  LSP/format/lint support.

Go tooling requires a host `go` installation; Rust tooling requires a Rust
toolchain (`rustc`, Cargo, rustfmt, and Clippy). Project-local test dependencies
such as pytest, Jest, and Vitest remain owned by each project.

Install or repair the declared tools with `:MasonToolsInstallSync` and
`:ToolingInstallTreesitter`.

## Terminal workflow

tmux uses `Ctrl-b` as its prefix. Prefix then `|`/`-` creates a split rooted at
the current pane; prefix then `Ctrl-g` opens Claude Code in a horizontal split.
Claude's unprefixed `Ctrl-g` opens Neovim as the external editor. Prefix then
`Ctrl-s`/`Ctrl-r` manually saves/restores sessions through tmux-resurrect.

Neovim key groups include `<leader>f`/`<leader>s` for find/search,
`<leader>c` for code and formatting, `<leader>d` for debugging,
`<leader>T` for tests, `<leader>g` for Git, `<leader>x` for diagnostics,
`<leader>R` for remote workspaces, `<leader>M` for Markdown, and
`<leader>W` for layouts.

Over SSH, Neovim and the shell copy with OSC 52. Clipboard paste falls back to
Neovim's internal register so terminals that block remote clipboard reads do
not hang. Neovim uses built-in search/quickfix fallbacks when fzf is unavailable
or the session is remote; remote hosts must already contain the required Mason
binaries.

## Validation and benchmarks

Focused repository checks:

```bash
jq empty .claude/settings.json .claude/keybindings.json opencode/.config/opencode/opencode.json opencode/.config/opencode/tui.json opencode.json
bash -n setup.sh .claude/statusline.sh .claude/subagent-statusline.sh .claude/hooks/*.sh
zsh -n zsh/.zshenv zsh/.zprofile zsh/.zshrc
shfmt -d setup.sh .claude/*.sh .claude/hooks/*.sh
shellcheck setup.sh .claude/*.sh .claude/hooks/*.sh
stylua --check nvim/.config/nvim
./setup.sh --dry-run --skip-neovim-tools
nvim --headless "+checkhealth" +qa
git diff --check
```

Repeatable startup measurements:

```bash
python3 - <<'PY'
import statistics, subprocess, time

commands = {
    "zsh login": ["zsh", "-lic", "exit"],
    "zsh non-login": ["zsh", "-ic", "exit"],
    "Neovim headless": ["nvim", "--headless", "+qa"],
}
for label, command in commands.items():
    subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    samples = []
    for _ in range(10):
        started = time.perf_counter()
        subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        samples.append((time.perf_counter() - started) * 1000)
    print(f"{label}: median={statistics.median(samples):.1f}ms")
PY

tmux -L dotfiles-bench -f tmux/.tmux.conf start-server
tmux -L dotfiles-bench kill-server
nvim --startuptime /tmp/nvim-startup.log --headless +qa
```
