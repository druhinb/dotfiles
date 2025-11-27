return {
  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - gzaiw) - [G]o [Z]urround [A]dd [I]nner [W]ord [)]Paren
      -- - gzd'   - [G]o [Z]urround [D]elete [']quotes
      -- - gzr)'  - [G]o [Z]urround [R]eplace [)] [']
      require('mini.surround').setup {
        mappings = {
          add = 'gza',            -- Add surrounding in Normal and Visual modes
          delete = 'gzd',         -- Delete surrounding
          find = 'gzf',           -- Find surrounding (to the right)
          find_left = 'gzF',      -- Find surrounding (to the left)
          highlight = 'gzh',      -- Highlight surrounding
          replace = 'gzr',        -- Replace surrounding
          update_n_lines = 'gzn', -- Update `n_lines`
        },
      }

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      -- local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      -- statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      -- statusline.section_location = function()
      --   return '%2l:%-2v'
      -- end

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim

      -- Go comments
      require('mini.comment').setup()
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
