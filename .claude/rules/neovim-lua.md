---
paths:
  - "nvim/.config/nvim/*.lua"
  - "nvim/.config/nvim/**/*.lua"
  - "nvim/.config/nvim/.stylua.toml"
---

# Neovim Lua conventions

- This is a modular Kickstart configuration using lazy.nvim, not LazyVim. `init.lua` loads options, keymaps, lazy bootstrap, and `lua/lazy-plugins.lua`.
- Core plugin specs live in `lua/kickstart/plugins/`; personal and filetype-specific specs are auto-imported from `lua/custom/plugins/`.
- Give plugins a precise `event`, `cmd`, `ft`, or `keys` trigger. Keep startup free of parser, Mason, or package installation.
- `lua/tooling.lua` is the shared inventory for LSP servers, formatters, linters, DAP adapters, tests, and Tree-sitter parsers. Extend it instead of duplicating package lists.
- Servers owned by filetype-specific language bundles belong in `tooling.bundle_servers` so Mason's automatic enablement does not create duplicate clients.
- Prefer Neovim 0.11+ `vim.lsp.config` and `vim.lsp.enable`, buffer-local capability-aware mappings, and native LSP document highlighting.
- fzf-lua is the preferred picker. Preserve the lightweight built-in fallbacks in `lua/search.lua` for hosts without `fzf`.
- Keep plugin specs declarative and return a spec table. Include `desc` on user-facing keymaps and register new leader groups with which-key.
- Format changed Lua with `stylua`; use `stylua --check <paths>` for validation.
