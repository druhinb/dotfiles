local tooling = require 'tooling'

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    cmd = 'ToolingInstallTreesitter',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      require('nvim-treesitter').setup()

      vim.api.nvim_create_user_command('ToolingInstallTreesitter', function()
        vim.g.tooling_treesitter_install_ok = false
        local ok, installed = require('nvim-treesitter').install(tooling.treesitter, { summary = true }):pwait(1800000)
        if not ok or not installed then
          error 'Tree-sitter parser installation failed'
        end
        vim.g.tooling_treesitter_install_ok = true
      end, { desc = 'Install configured Tree-sitter parsers' })

      local function start(buf)
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype ~= '' then
          pcall(vim.treesitter.start, buf)
        end
      end

      vim.api.nvim_create_autocmd('FileType', {
        desc = 'Start Tree-sitter highlight for buffer',
        group = vim.api.nvim_create_augroup('treesitter-highlight', { clear = true }),
        pattern = '*',
        callback = function(args)
          start(args.buf)
        end,
      })
      start(vim.api.nvim_get_current_buf())

      vim.keymap.set('n', '<C-space>', 'v', { desc = 'Visual Mode / Init Selection' })
      vim.keymap.set('v', '<C-space>', 'an', { desc = 'Increment Selection' })
      vim.keymap.set('v', '<bs>', 'in', { desc = 'Decrement Selection' })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
