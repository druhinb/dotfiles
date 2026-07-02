---
paths:
  - "zsh/**"
  - "**/*.sh"
  - "**/*.bash"
---

# Shell and zsh conventions

- Use the interpreter named by the shebang. zsh syntax and Bash syntax are not interchangeable.
- `zsh/.zshenv` is command-free shared environment setup, `zsh/.zprofile` is login-only, and `zsh/.zshrc` is interactive-only.
- Guard optional tools before initialization. Keep machine-specific paths and devspace setup in the untracked `~/.zshrc.local`.
- Oh My Zsh stays intentionally small; `setup.sh` owns plugin installation. Syntax highlighting must remain last after widgets and keybindings.
- `fnm` is the only Node version manager, with its directory-change hook initialized once. Keep native `cd`; expose zoxide through `z` and `zi`.
- Quote paths and expansions, use `--` before user-controlled path arguments where supported, and keep macOS/Linux behavior portable.
- Claude hooks must be fast, non-interactive, and deterministic. Parse hook JSON once, never access `/dev/tty`, keep stdout limited to the documented hook contract, and send failures to stderr.
- Validate Bash with `bash -n`, zsh with `zsh -n`, and supported shell files with `shellcheck`. Use `shfmt -d` for Bash/POSIX shell only; do not run shfmt over zsh-specific files.
