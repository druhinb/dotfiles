local tooling = require 'tooling'

return {
  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo', 'Format', 'FormatToggle' },
    keys = {
      {
        '<leader>cf',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = { 'n', 'x' },
        desc = 'Format buffer',
      },
      {
        '<leader>uf',
        '<cmd>FormatToggle<cr>',
        desc = 'Toggle format on save',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        if vim.g.autoformat_enabled == false or vim.b[bufnr].autoformat_enabled == false then
          return
        end
        return {
          timeout_ms = 1000,
          lsp_format = 'fallback',
        }
      end,
      formatters_by_ft = tooling.formatters_by_ft,
    },
    config = function(_, opts)
      require('conform').setup(opts)
      vim.api.nvim_create_user_command('Format', function()
        require('conform').format { async = true, lsp_format = 'fallback' }
      end, { desc = 'Format current buffer' })
      vim.api.nvim_create_user_command('FormatToggle', function(command)
        if command.bang then
          vim.b.autoformat_enabled = vim.b.autoformat_enabled == false
          vim.notify(('Buffer format on save %s'):format(vim.b.autoformat_enabled == false and 'disabled' or 'enabled'))
        else
          vim.g.autoformat_enabled = vim.g.autoformat_enabled == false
          vim.notify(('Global format on save %s'):format(vim.g.autoformat_enabled == false and 'disabled' or 'enabled'))
        end
      end, { bang = true, desc = 'Toggle format on save (! for buffer)' })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
