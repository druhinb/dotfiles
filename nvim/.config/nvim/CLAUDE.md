# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

**Formatting Lua files:**
```bash
stylua lua/          # Format all Lua files (uses .stylua.toml: 160-char line width)
stylua path/to/file.lua
```

**Health check (run inside Neovim):**
```
:checkhealth
:Lazy          -- Plugin manager UI
:Lazy update   -- Update all plugins
:Lazy clean    -- Remove unused plugins
:Mason         -- LSP/DAP/formatter installer
```

## Architecture

Built on **kickstart.nvim** with custom extensions. Plugin manager is **lazy.nvim**.

```
init.lua                        -- Entry point: sets leader, loads options/keymaps/plugins
lua/
  options.lua                   -- vim.opt settings
  keymaps.lua                   -- Global keybindings (~365 lines)
  lazy-bootstrap.lua            -- Installs lazy.nvim if missing
  lazy-plugins.lua              -- Plugin spec: imports kickstart + auto-scans custom/plugins/
  kickstart/plugins/            -- Base plugins (LSP, treesitter, completion, fzf, dap, etc.)
    lsp/                        -- Per-language LSP configs (14 languages)
  custom/plugins/               -- Auto-discovered; drop a file here to add a plugin
```

**The split between `kickstart/` and `custom/`:** `kickstart/plugins/` holds the stable base (lspconfig, treesitter, blink-cmp, conform, fzf-lua, dap). `custom/plugins/` is where all personal additions live — lazy.nvim auto-imports every file in that directory.

## Adding/Modifying Plugins

**New plugin** — create `lua/custom/plugins/<name>.lua` returning a spec table:
```lua
return {
  'owner/repo',
  event = 'VeryLazy',   -- or: cmd, ft, keys for lazy loading
  opts = { ... },       -- passed to require('plugin').setup(opts)
}
```

**Override a kickstart plugin** — edit the file in `lua/kickstart/plugins/` directly, or shadow specific keys in a custom file.

**LSP server** — add server config to the `servers` table in `lua/kickstart/plugins/lspconfig.lua`, then add a per-language file under `lua/kickstart/plugins/lsp/` if it needs custom setup.

**Formatter** — extend the `formatters_by_ft` table in `lua/kickstart/plugins/conform.lua`.

## Key Conventions

**Lazy loading patterns used throughout:**
- `event = 'VeryLazy'` — defer until after UI is ready
- `event = 'LazyFile'` — load on first file open
- `keys = { { '<leader>x', ..., desc = '...' } }` — load on keypress; always include `desc` for which-key
- `ft = 'python'` — filetype-triggered
- `cmd = 'CommandName'` — command-triggered

**Which-key group registration** — new `<leader>` prefixes should be registered in `lua/kickstart/plugins/which-key.lua` under the `spec` table.

**Plugin spec shape:**
```lua
return {
  'owner/repo',
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = {
    { '<leader>xy', function() require('plugin').action() end, desc = 'Short description' },
  },
  opts = function()            -- use a function when opts depend on runtime state
    return { ... }
  end,
}
```

## Plugin Landscape

| Category | Plugin |
|---|---|
| Fuzzy finder | fzf-lua (`<leader>f*`, `<leader>s*`) |
| LSP | nvim-lspconfig + Mason + blink-cmp |
| Formatting | conform.nvim (`:Format` or on save) |
| Linting | nvim-lint (`kickstart/plugins/int.lua` — toggle via `<leader>tl`) |
| Git | gitsigns, neogit, diffview, lazygit (via snacks) |
| Git conflicts | git-conflict.nvim (inline conflict markers UI) |
| Diagnostics | trouble.nvim (`<leader>x*`) |
| Debug | nvim-dap + dap-ui (`lua/kickstart/plugins/debug.lua`) |
| File marks | harpoon2 (`<leader>a` add, `<leader>1-6` jump) |
| Find & replace | grug-far.nvim (`<leader>rr`) |
| Session restore | persistence.nvim (`<leader>qs` restore, `<leader>ql` last) |
| Undo history | undotree (`<leader>uu`) |
| Markdown preview | render-markdown.nvim (`<leader>mr` toggle) |
| Doc generation | neogen (`<leader>nf` generate annotation) |
| UI | noice (cmdline/messages), snacks, lualine, dashboard |
| UI extras | mini-indentscope, satellite (scrollbar), smear-cursor, illuminate |
| Navigation | flash.nvim, yazi, tmux.nvim (seamless pane navigation) |
| Testing | neotest |
| Editing helpers | hardtime.nvim (habit enforcement), text-case.nvim, rip-substitute |

## Non-obvious Files

- `kickstart/plugins/int.lua` — this is the **linting** plugin (`nvim-lint`), not "integration"; the name is a kickstart artifact
- `kickstart/plugins/telescope.lua` — telescope is installed but **fzf-lua is preferred**; reach for fzf-lua keymaps (`<leader>f*`) when adding new pickers
- `custom/plugins/lang-cpp.lua`, `lang-java.lua` — **language bundles**: each file groups LSP extras + DAP + test runner + formatter for one language; follow this pattern when adding full language support
