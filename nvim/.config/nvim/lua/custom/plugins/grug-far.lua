return {
  'MagicDuck/grug-far.nvim',
  config = function()
    require('grug-far').setup {
      headerMaxWidth = 80,
      helpLine = { enabled = false },
    }
  end,
  keys = {
    {
      '<leader>rr',
      function()
        local grug = require 'grug-far'
        local ext = vim.bo.buftype == '' and vim.fn.expand '%:e'
        grug.open {
          transient = true,
          prefills = {
            filesFilter = ext and ext ~= '' and '*.' .. ext or nil,
          },
        }
      end,
      mode = { 'n', 'v' },
      desc = 'Search and [RR]eplace (Grug Far)',
    },
  },
}
