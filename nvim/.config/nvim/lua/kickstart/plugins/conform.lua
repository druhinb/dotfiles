return {
  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- Disable format_on_save for specific filetypes if needed
        -- C/C++ formatting is now enabled with clang-format
        local disable_filetypes = {}
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 1000,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        -- Lua
        lua = { 'stylua' },

        -- C/C++
        c = { 'clang-format' },
        cpp = { 'clang-format' },

        -- Python - Ruff is the modern standard (replaces black + isort)
        python = { 'ruff_organize_imports', 'ruff_format' },

        -- TypeScript/JavaScript - Prettier is the industry standard
        javascript = { 'prettierd', 'prettier', stop_after_first = true },
        typescript = { 'prettierd', 'prettier', stop_after_first = true },
        javascriptreact = { 'prettierd', 'prettier', stop_after_first = true },
        typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },

        -- HTML/CSS
        html = { 'prettierd', 'prettier', stop_after_first = true },
        css = { 'prettierd', 'prettier', stop_after_first = true },
        scss = { 'prettierd', 'prettier', stop_after_first = true },
        less = { 'prettierd', 'prettier', stop_after_first = true },

        -- C#
        cs = { 'csharpier' },

        -- Rust - rustfmt is the standard
        rust = { 'rustfmt', lsp_format = 'fallback' },

        -- Java
        java = { 'google-java-format' },

        -- JSON/YAML/Markdown
        json = { 'prettierd', 'prettier', stop_after_first = true },
        jsonc = { 'prettierd', 'prettier', stop_after_first = true },
        yaml = { 'prettierd', 'prettier', stop_after_first = true },
        markdown = { 'prettierd', 'prettier', stop_after_first = true },
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
