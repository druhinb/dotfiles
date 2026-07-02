---
paths:
  - "tmux/**"
  - "tmux/.tmux.conf"
---

# tmux conventions

- tmux owns the terminal layout and remains the primary Claude Code workspace. Do not add a second agent multiplexer.
- Preserve the `C-b` prefix, current-directory-aware windows/splits, and the prefixed `C-g` split that launches Claude beside the active pane.
- Leave unprefixed `C-g` available to Claude Code so its external-editor action opens `$EDITOR`/`$VISUAL` in Neovim.
- The zsh `tmux-ssh` helper is the canonical remote-session workflow. Do not add overlapping SSH window bindings.
- TPM is the only plugin installation path. Keep resurrect manual, with pane capture and automatic restore disabled.
- Keep status content lightweight and avoid polling CPU, memory, network, or external scripts.
- Validate in an isolated tmux server with the repository config; do not replace or kill the user's active server.
