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
      --  - dii  - [D]elete [I]nside [I]ndent
      --  - vai  - [V]isually select [A]round [I]ndent
      local ai = require 'mini.ai'
      ai.setup {
        n_lines = 500,
        custom_textobjects = {
          -- Whole buffer
          g = function()
            local from = { line = 1, col = 1 }
            local to = {
              line = vim.fn.line '$',
              col = math.max(vim.fn.getline('$'):len(), 1),
            }
            return { from = from, to = to }
          end,

          -- Digit sequence
          d = { '%f[%d]%d+' },

          -- Word with case (for camelCase, snake_case, etc.)
          e = {
            { '%u[%l%d]+%f[^%l%d]', '%f[%S][%l%d]+%f[^%l%d]', '%f[%P][%l%d]+%f[^%l%d]', '^[%l%d]+%f[^%l%d]' },
            '^().*()$',
          },

          -- Indentation textobject (built-in from mini.ai)
          -- ai = around indent, ii = inside indent
          i = function(ai_type)
            local spaces = (' '):rep(vim.o.tabstop)
            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            local indents = {}

            for l, line in ipairs(lines) do
              if not line:find '^%s*$' then
                indents[#indents + 1] = { line = l, indent = #line:gsub('\t', spaces):match '^%s*', text = line }
              end
            end

            local cur_line = vim.fn.line '.'
            local cur_indent = 0
            for _, v in ipairs(indents) do
              if v.line == cur_line then
                cur_indent = v.indent
                break
              elseif v.line > cur_line then
                break
              end
              cur_indent = v.indent
            end

            local from_line, to_line = nil, nil
            for _, v in ipairs(indents) do
              if v.indent >= cur_indent then
                from_line = from_line or v.line
                to_line = v.line
              elseif from_line then
                break
              end
            end

            if not from_line then
              return nil
            end

            if ai_type == 'a' then
              -- Include blank lines below
              local last_line = vim.fn.line '$'
              while to_line < last_line and vim.fn.getline(to_line + 1):find '^%s*$' do
                to_line = to_line + 1
              end
            end

            return {
              from = { line = from_line, col = 1 },
              to = { line = to_line, col = #vim.fn.getline(to_line) },
            }
          end,

          -- Number (integer or float)
          n = { '%f[%d]%d+%.?%d*' },

          -- Key-value pair
          k = { { '%w+%s*=' }, '^%s*().-()%s*$' },

          -- URL
          u = {
            'https?://[%w._~:/?#%[%]@!$&\'()*+,;=-%%]+',
          },
        },
      }

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
