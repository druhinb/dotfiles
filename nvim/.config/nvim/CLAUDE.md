# Neovim configuration guidance

## Architecture

This is a modular Kickstart configuration managed by lazy.nvim. It is not LazyVim.

```text
init.lua                         leader, options, keymaps, lazy bootstrap, plugins, autoread
lua/lazy-plugins.lua             lazy.nvim setup and explicit core specs
lua/tooling.lua                  shared LSP/format/lint/DAP/test/parser inventory
lua/search.lua                   built-in search and quickfix fallbacks
lua/kickstart/plugins/           core LSP, completion, format, lint, DAP, treesitter, UI specs
lua/custom/plugins/              auto-imported personal and language-bundle specs
```

`lua/lazy-plugins.lua` imports selected core specs directly and auto-imports every spec under `lua/custom/plugins/`. Core behavior belongs in `kickstart/plugins`; optional integrations and filetype-specific bundles belong in `custom/plugins`.

Neovim autoread is enabled in `init.lua`. External edits made by Claude are picked up on focus, buffer entry, and cursor-hold checks. Claude Code remains in tmux; do not add an in-editor agent plugin.

## Tool ownership

`lua/tooling.lua` is the authoritative inventory for:

- native LSP server to Mason package mappings;
- formatters and `formatters_by_ft`;
- linters and `linters_by_ft`;
- DAP packages and adapter names;
- Java debug/test support;
- Tree-sitter parsers;
- the documented language capability matrix.

`lua/kickstart/plugins/lspconfig.lua`, `conform.lua`, `int.lua`, `debug.lua`, and `treesitter.lua` consume that inventory. Add tools there rather than creating a second install list.

Most servers use Neovim 0.11+ `vim.lsp.config` and `vim.lsp.enable` in `lspconfig.lua`. clangd, vtsls/Tailwind, jdtls, and Roslyn are owned by filetype-triggered bundles under `custom/plugins/lang-*.lua`; keep those server names in `tooling.bundle_servers` to avoid duplicate clients.

Mason installation is explicit. `mason-tool-installer.nvim` has `run_on_start = false`; `setup.sh` invokes `:MasonToolsInstallSync`. Tree-sitter parser installation is exposed through `:ToolingInstallTreesitter`, not normal startup.

## Plugin conventions

Return a lazy.nvim spec table and choose the narrowest appropriate trigger:

```lua
return {
  'owner/repo',
  ft = 'python',
  keys = {
    { '<leader>xy', function() require('plugin').action() end, desc = 'Action' },
  },
  opts = {},
}
```

- Use `ft` for language bundles, `cmd` for command workflows, `keys` for user actions, and a real event only when needed.
- Include `desc` on user-facing keymaps. Register new leader groups in `lua/kickstart/plugins/which-key.lua`.
- Do not install packages, parsers, or tools during ordinary startup.
- Prefer native Neovim APIs and the existing focused plugin over another overlapping subsystem.
- fzf-lua is the preferred picker, local or over SSH, whenever the `fzf` binary is present. `custom/plugins/telescope.lua` is the fallback picker when it isn't (e.g. a remote host without `fzf` installed); keep `lua/search.lua`'s native fallbacks working for hosts with neither.
- Preserve capability-aware, buffer-local LSP mappings and native document highlighting.

## Language bundles

The first-class bundles are Python, TypeScript/JavaScript/React, C/C++, Rust, Go, Java, and C#. Config/infra support is centralized in the core LSP, conform, lint, and tooling files.

- Python and Go bundle files currently provide filetype-triggered neotest adapters; core LSP/DAP/format/lint setup is centralized.
- React/TypeScript owns vtsls, Tailwind, and TS autotag behavior.
- C/C++ owns clangd extensions and CMake commands.
- Java owns jdtls startup, Java debug/test bundles, and Java-specific actions.
- C# owns Roslyn; shared DAP and neotest provide .NET debugging/testing.
- `lua/custom/plugins/neotest.lua` defines the common test mappings and adapter setup.

## Focused checks

From `nvim/.config/nvim`:

```bash
stylua --check init.lua lua
nvim --headless "+qa"
nvim --headless "+lua require('tooling').mason_packages()" +qa
```

Useful interactive diagnostics are `:checkhealth`, `:Lazy`, `:Mason`, `:ConformInfo`, `:LspInfo`, and the DAP/neotest UIs. Do not run `:Lazy update`, `:Lazy clean`, Mason installation, or every-language checks unless the task calls for integration testing.

`kickstart/plugins/int.lua` is the nvim-lint spec despite its historical filename. Formatting uses `:Format`/`:FormatToggle`; linting uses `:Lint`/`:LintToggle`.
