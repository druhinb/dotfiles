return {
  {
    'goolord/alpha-nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local dashboard = require 'alpha.themes.dashboard'
      dashboard.section.header.val = {
        [[                               __                ]],
        [[  ___     ___    ___   __  __ /\_\    ___ ___    ]],
        [[ / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\  ]],
        [[/\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \ ]],
        [[\ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
        [[ \/_/\/_/\/____/\/____/ \/__/    \/_/\/_/\/_/\/_/]],
      }
      dashboard.section.buttons.val = {
        dashboard.button('e', '  New file', ':ene <BAR> startinsert <CR>'),
        dashboard.button('f', '  Find file', ':Telescope find_files <CR>'),
        dashboard.button('r', '  Recent', ':Telescope oldfiles <CR>'),
        dashboard.button('s', '  Restore Session', [[:lua require("persistence").load() <cr>]]),
        dashboard.button('q', '  Quit', ':qa<CR>'),
      }
      require('alpha').setup(dashboard.config)
    end,
  },
  {
    'folke/persistence.nvim',
    event = 'BufReadPre', -- this will only start session saving when you open a file
    opts = {
      -- add any custom options here
    },
  },
}
