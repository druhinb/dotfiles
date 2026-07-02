return {
  'NeogitOrg/neogit',
  dependencies = {
    'nvim-lua/plenary.nvim', -- required
    'sindrets/diffview.nvim', -- optional - Diff integration

    -- Only one of these is needed, not both.
    'ibhagwan/fzf-lua', -- optional
  },
  cmd = 'Neogit',
  keys = {
    { '<leader>gs', '<cmd>Neogit<cr>', desc = 'Git status' },
    { '<leader>gc', '<cmd>Neogit commit<cr>', desc = 'Git commit' },
    { '<leader>gp', '<cmd>Neogit push<cr>', desc = 'Git push' },
    { '<leader>gl', '<cmd>Neogit log<cr>', desc = 'Git log' },
    { '<leader>gP', '<cmd>Neogit pull<cr>', desc = 'Git pull' },
    { '<leader>gb', '<cmd>Neogit branch<cr>', desc = 'Git branch' },
  },
  config = function()
    local neogit = require 'neogit'

    neogit.setup {
      -- Hides the hints at the top of the status buffer
      disable_hint = true,
      -- Integrations
      integrations = {
        diffview = true,
        fzf_lua = require('search').has_fzf(),
      },
    }
  end,
}
