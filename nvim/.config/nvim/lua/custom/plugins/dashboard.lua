return {
  {
    'goolord/alpha-nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local dashboard = require 'alpha.themes.dashboard'

      -- Try to use ascii plugin for header
      local ok, ascii = pcall(require, 'ascii')
      if ok and ascii.art and ascii.art.text and ascii.art.text.neovim then
        dashboard.section.header.val = ascii.art.text.neovim.delta_corps_priest1
      else
        -- Fallback header if ascii plugin fails
        dashboard.section.header.val = {
          [[                               __                ]],
          [[  ___     ___    ___   __  __ /\_\    ___ ___    ]],
          [[ / _ `\  / __`\ / __`\/\ \/\ \/\ \  / __` __`\  ]],
          [[/\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \ ]],
          [[\ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\_\ ]],
          [[ \/_/\/_/\/____/\/____/ \/__/    \/_/\/_/\/_/\/_/]],
        }
      end

      dashboard.section.buttons.val = {
        dashboard.button('e', '  > New File', ':ene <BAR> startinsert <CR>'),
        dashboard.button('f', '  > Find File', ':FzfLua files<CR>'),
        dashboard.button('r', '  > Recent', ':FzfLua oldfiles<CR>'),
        dashboard.button('s', '  > Restore Session', [[:lua require("persistence").load() <cr>]]),
        dashboard.button('l', '󰒲  > Lazy', ':Lazy<CR>'),
        dashboard.button('q', '  > Quit', ':qa<CR>'),
      }

      -- Fortune Generator
      local fortunes = {
        'The only way to go fast, is to go well.',
        'Premature optimization is the root of all evil.',
        'Code is like humor. When you have to explain it, it’s bad.',
        'Simplicity is the soul of efficiency.',
        'Make it work, make it right, make it fast.',
        'Software is eating the world.',
        'Talk is cheap. Show me the code.',
        'Deleted code is debugged code.',
        "One man's crappy software is another man's full time job.",
        "It's not a bug - it's an undocumented feature.",
        'Computers are fast; developers keep them slow.',
        'The best error message is the one that never shows up.',
        'Debugging is twice as hard as writing the code in the first place. Therefore, if you write the code as cleverly as you possibly can, you are, by definition, not smart enough to debug it.',
        'There are only two hard things in computer science: cache invalidation, naming things, and off-by-one errors.',
        'Measuring programming progress by lines of code is like measuring aircraft building progress by weight.',
        'Walking on water and developing software from a specification are easy if both are frozen.',
        'Always code as if the guy who ends up maintaining your code will be a violent psychopath who knows where you live.',
        'The most important property of a program is whether it accomplishes the intention of its user.',
      }

      local function get_fortune()
        math.randomseed(os.time())
        return '   ' .. fortunes[math.random(#fortunes)] .. '   '
      end

      -- Stats Generator
      local function get_stats()
        local stats = require('lazy').stats()
        local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
        return '⚡ Neovim loaded ' .. stats.loaded .. '/' .. stats.count .. ' plugins in ' .. ms .. 'ms'
      end

      -- Define Layout
      dashboard.config.layout = {
        { type = 'padding', val = 2 },
        dashboard.section.header,
        {
          type = 'text',
          val = get_fortune(),
          opts = { hl = 'Comment', position = 'center' },
        },
        { type = 'padding', val = 2 },
        dashboard.section.buttons,
        { type = 'padding', val = 2 },
        { type = 'padding', val = 1 },
        {
          type = 'text',
          val = get_stats(),
          opts = { hl = 'Number', position = 'center' },
        },
      }

      require('alpha').setup(dashboard.config)
    end,
  },
  {
    'folke/persistence.nvim',
    event = 'BufReadPre',
    opts = {},
  },
}
