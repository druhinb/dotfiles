# Dotfiles

This is my terminal setup. It's tuned for macOS with Homebrew, and Debian/Ubuntu mostly works too, though I test that path far less often. tmux holds everything together as a window manager, Neovim is where I write code, and Claude Code lives in its own pane beside it. I like keeping the editor and the agent as separate processes that watch the same files, so a change from either side shows up in the other without any plugin gluing them together.

## Installing it

Read the script before you run it. It touches your shell config and your home directory, and you should know what that means before it happens.

```bash
./setup.sh --dry-run --skip-neovim-tools
./setup.sh
```

The dry run shows you what would change. The real run installs command-line tools, backs up anything it's about to overwrite, lays down the symlinks, installs shell and tmux and Neovim plugins, pulls in the full Neovim tooling inventory, and may switch your login shell to zsh. Pass `--skip-neovim-tools` if you don't want it grabbing every Mason tool and Tree-sitter parser on a fresh machine.

Anything specific to one machine, like a work-only PATH entry or a local API key, goes in `~/.zshrc.local`. That file is never tracked, so it's the right place for things that shouldn't leave this laptop.

## How it's organized

The rule across this whole repo is simple: edit the file here, not the symlink it creates in your home directory. `setup.sh` is the only thing that should be writing into `$HOME`.

Package installation, symlinking, Oh My Zsh plugins, and the TPM bootstrap all live in `setup.sh`. Once tmux is running, TPM takes over managing plugins under `~/.tmux/plugins`, and lazy.nvim does the same job for Neovim, with `lazy-lock.json` pinning versions so an update doesn't silently break something. `nvim/.config/nvim/lua/tooling.lua` is where every Mason package, formatter, linter, debugger, and Tree-sitter parser is declared. If a language feels half-configured, that file is where to look first.

Agent tooling is its own small ecosystem here. `agents/skills/` holds the skills I wrote and want available everywhere, and `setup.sh` links them into Claude Code, Codex, and OpenCode without stepping on Codex's own bundled skills. `codex/.codex/` carries Codex-specific guidance and a handful of subagent profiles (plan, review, debug, docs, test-writer, commit), and its `config.toml` sets sane multi-agent defaults without overriding whatever deCLAWd already manages for auth and sandboxing. `opencode/` mirrors that setup for OpenCode: global config, the same family of custom agents, and commands like `/review`, `/commit`, and `/tdd`. A repo-root `opencode.json` adds a `/validate` command scoped just to this repo. For every agent and command with a source under `.claude/` — the ship trio, the verifier agent, and the `/ship-slice`, `/review`, `/commit`, and `/tdd` commands — Claude Code is canonical: `sync-agents.sh` generates the matching Codex `.toml` and OpenCode `.md` definitions from `.claude/`, and `setup.sh` runs it before linking, so I edit the Claude sources and let the other clients follow. `./sync-agents.sh --check` flags any drift without writing. `.claude/` also carries a global `CLAUDE.md` of engineering principles (linked to `~/.claude/CLAUDE.md`) and hooks that auto-format edited files, feed lint diagnostics straight back to the agent, block edits that would land on a symlink instead of its source, and brief each new session on repository state.

## Language tooling

Each language gets a full toolchain:

- Python: basedpyright, Ruff, debugpy, pytest through neotest
- TypeScript, JavaScript, React: vtsls, prettierd, eslint_d, js-debug, Jest, Vitest
- C and C++: clangd, clang-format, cpplint, codelldb, CMake
- Rust: rust-analyzer, rustfmt, clippy, codelldb, cargo through neotest
- Go: gopls, goimports, gofumpt, golangci-lint, Delve
- Java: jdtls, google-java-format, the Java debug and test bundles
- C#: Roslyn, CSharpier, netcoredbg, neotest-dotnet
- Everything else (Lua, shell, Markdown, YAML, JSON, TOML, Docker, SQL): the usual LSP, formatter, and linter set

Go and Rust need their own toolchains installed on the host; Mason can't substitute for a missing `go` or `rustc`. Project-level test runners like pytest or Vitest stay owned by whatever project you're in.

If a tool is missing or feels out of date, `:MasonToolsInstallSync` and `:ToolingInstallTreesitter` will fix it.

## Living in the terminal

tmux's prefix is `Ctrl-b`. From there, `|` and `-` split the current pane, and `Ctrl-g` opens Claude Code in a horizontal split rooted wherever you were standing. Inside Claude, an unprefixed `Ctrl-g` opens Neovim as the external editor for the current buffer. `Ctrl-s` and `Ctrl-r` save and restore the whole session through tmux-resurrect, which matters more than it sounds like the first time you lose a nine-pane layout.

Neovim's leader key groups things by what you're trying to do: `<leader>f` and `<leader>s` for finding and searching, `<leader>c` for code actions and formatting, `<leader>d` for the debugger, `<leader>T` for tests, `<leader>g` for git, `<leader>x` for diagnostics, `<leader>R` for remote workspaces, `<leader>M` for markdown, and `<leader>W` for window layouts.

Over SSH, both Neovim and the shell copy through OSC 52, so clipboard sync works even on a remote box. Paste falls back to Neovim's internal register on terminals that refuse remote clipboard reads, so a paste never just hangs. Fuzzy finding works the same over SSH as it does locally, as long as `fzf` is installed on the remote host. If it isn't, Neovim falls back to telescope.nvim, and if that isn't installed either, it drops to built-in search and quickfix.

## Checking your work

These are the checks to run after touching something, scoped to whatever you changed:

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

And if you're chasing a startup-time regression, this gives you real numbers:

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
