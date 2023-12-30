return {
  'NeogitOrg/neogit',
  dependencies = {
    'nvim-lua/plenary.nvim', -- required
    'sindrets/diffview.nvim', -- optional - Diff integration

    -- Only one of these is needed, not both.
    'nvim-telescope/telescope.nvim', -- optional
  },
  config = function()
    local neogit = require 'neogit'

    neogit.setup {
      -- Hides the hints at the top of the status buffer
      disable_hint = true,
      -- Integrations
      integrations = {
        diffview = true,
      },
    }

    -- Keymaps
    vim.keymap.set('n', '<leader>gs', neogit.open, { desc = '[G]it [S]tatus (Neogit)' })
    vim.keymap.set('n', '<leader>gc', ':Neogit commit<CR>', { desc = '[G]it [C]ommit' })
    vim.keymap.set('n', '<leader>gp', ':Neogit push<CR>', { desc = '[G]it [P]ush' })
    vim.keymap.set('n', '<leader>gl', ':Neogit log<CR>', { desc = '[G]it [L]og' })
    vim.keymap.set('n', '<leader>gP', ':Neogit pull<CR>', { desc = '[G]it [P]ull' })
  end,
}
