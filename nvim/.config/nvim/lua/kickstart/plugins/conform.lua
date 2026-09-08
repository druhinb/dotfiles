local tooling = require 'tooling'

return {
  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo', 'Format', 'FormatToggle', 'FormatHunks', 'FormatHunksBase' },
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
        '<leader>cF',
        '<cmd>FormatHunks<cr>',
        desc = 'Format changed hunks',
      },
      {
        '<leader>uf',
        '<cmd>FormatToggle<cr>',
        desc = 'Toggle format on save',
      },
    },
    opts = {
      notify_on_error = false,
      formatters_by_ft = tooling.formatters_by_ft,
    },
    config = function(_, opts)
      require('conform').setup(opts)
      -- format_on_save is deliberately unset: format_hunks owns BufWritePre so
      -- saving rewrites only the lines that differ from the git base.
      local format_hunks = require 'format_hunks'
      format_hunks.setup_autocmd()

      vim.api.nvim_create_user_command('Format', function()
        require('conform').format { async = true, lsp_format = 'fallback' }
      end, { desc = 'Format current buffer' })

      vim.api.nvim_create_user_command('FormatHunks', function(command)
        format_hunks.format_hunks(0, { base = command.args ~= '' and command.args or nil, quiet = false })
      end, { nargs = '?', desc = 'Format hunks changed since the git base' })

      vim.api.nvim_create_user_command('FormatHunksBase', function()
        format_hunks.config.base = format_hunks.config.base == 'HEAD' and ':0' or 'HEAD'
        vim.notify(('Hunk format base: %s'):format(format_hunks.config.base))
      end, { desc = 'Toggle hunk format base between HEAD and the index' })

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
