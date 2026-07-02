-- ============================================================================
-- Mini.nvim Ecosystem - LazyVim Style
-- Provides: text objects, surround, auto-pairs, commenting
-- ============================================================================
return {
  -- ══════════════════════════════════════════════════════════════════════════
  -- mini.ai - Enhanced Text Objects (replaces nvim-treesitter-textobjects)
  -- ══════════════════════════════════════════════════════════════════════════
  {
    'echasnovski/mini.ai',
    event = 'VeryLazy',
    opts = function()
      local ai = require 'mini.ai'
      return {
        n_lines = 500,
        custom_textobjects = {
          -- Function (around/inside) - af, if
          f = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }, {}),
          -- Class (around/inside) - ac, ic
          c = ai.gen_spec.treesitter({ a = '@class.outer', i = '@class.inner' }, {}),
          -- Argument/parameter - aa, ia
          a = ai.gen_spec.treesitter({ a = '@parameter.outer', i = '@parameter.inner' }, {}),
          -- Conditional - ao, io (if/else blocks)
          o = ai.gen_spec.treesitter({
            a = { '@conditional.outer', '@loop.outer' },
            i = { '@conditional.inner', '@loop.inner' },
          }, {}),
          -- Block (generic) - ab, ib
          b = ai.gen_spec.treesitter({ a = '@block.outer', i = '@block.inner' }, {}),
          -- Whole buffer - ag, ig
          g = function()
            local from = { line = 1, col = 1 }
            local to = {
              line = vim.fn.line '$',
              col = math.max(vim.fn.getline('$'):len(), 1),
            }
            return { from = from, to = to }
          end,
          -- Digit sequence - ad, id
          d = { '%f[%d]%d+' },
          -- Word with case (camelCase, snake_case) - ae, ie
          e = {
            { '%u[%l%d]+%f[^%l%d]', '%f[%S][%l%d]+%f[^%l%d]', '%f[%P][%l%d]+%f[^%l%d]', '^[%l%d]+%f[^%l%d]' },
            '^().*()$',
          },
          -- Indentation - ai, ii
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
          -- Number - an, in
          n = { '%f[%d]%d+%.?%d*' },
          -- Key-value pair - ak, ik
          k = { { '%w+%s*=' }, '^%s*().-()%s*$' },
          -- URL - au, iu
          u = {
            "https?://[%w._~:/?#%[%]@!$&'()*+,;=-%%]+",
          },
          -- Tag (HTML/XML) - at, it (built-in)
          t = { '<([%p%w]-)%f[^<%w][^<>]->.-</%1>', '^<.->().googletag<googletag/%1>$' },
        },
        -- Module mappings
        mappings = {
          -- Main textobject prefixes
          around = 'a',
          inside = 'i',
          -- Next/last variants
          around_next = 'an',
          inside_next = 'in',
          around_last = 'al',
          inside_last = 'il',
          -- Move cursor
          goto_left = 'g[',
          goto_right = 'g]',
        },
      }
    end,
    config = function(_, opts)
      require('mini.ai').setup(opts)
    end,
  },

  -- ══════════════════════════════════════════════════════════════════════════
  -- mini.surround - Surround Operations (ys, ds, cs style)
  -- ══════════════════════════════════════════════════════════════════════════
  {
    'echasnovski/mini.surround',
    event = 'VeryLazy',
    opts = {
      -- LazyVim-style mappings (ys, ds, cs)
      mappings = {
        add = 'ys', -- Add surrounding in Normal and Visual modes (ysiw), ys{motion}{char})
        delete = 'ds', -- Delete surrounding (ds{char})
        find = 'gsf', -- Find surrounding (to the right)
        find_left = 'gsF', -- Find surrounding (to the left)
        highlight = 'gsh', -- Highlight surrounding
        replace = 'cs', -- Replace surrounding (cs{target}{replacement})
        update_n_lines = 'gsn', -- Update `n_lines`
        suffix_last = 'l', -- Suffix to search with "prev" method
        suffix_next = 'n', -- Suffix to search with "next" method
      },
      -- Number of lines within which surrounding is searched
      n_lines = 50,
      -- Whether to respect selection type (charwise, linewise, blockwise)
      respect_selection_type = false,
      -- How to search for surrounding (find more on `:h MiniSurround.config`)
      search_method = 'cover_or_next',
      -- Duration in ms for highlight when calling `MiniSurround.highlight()`
      highlight_duration = 500,
    },
    -- Make sure to set up mapping for adding surrounding for line
    keys = {
      -- LazyVim adds this for a consistent "yss" to surround whole line
      { 'yss', 'ys_', desc = 'Surround line', remap = true },
    },
  },

  -- ══════════════════════════════════════════════════════════════════════════
  -- mini.pairs - Auto Pairs
  -- ══════════════════════════════════════════════════════════════════════════
  {
    'echasnovski/mini.pairs',
    event = 'InsertEnter',
    opts = {
      -- In which modes mappings from this `config` should be created
      modes = { insert = true, command = false, terminal = false },
      -- Global mappings
      mappings = {
        ['('] = { action = 'open', pair = '()', neigh_pattern = '[^\\].' },
        ['['] = { action = 'open', pair = '[]', neigh_pattern = '[^\\].' },
        ['{'] = { action = 'open', pair = '{}', neigh_pattern = '[^\\].' },
        [')'] = { action = 'close', pair = '()', neigh_pattern = '[^\\].' },
        [']'] = { action = 'close', pair = '[]', neigh_pattern = '[^\\].' },
        ['}'] = { action = 'close', pair = '{}', neigh_pattern = '[^\\].' },
        ['"'] = { action = 'closeopen', pair = '""', neigh_pattern = '[^\\].', register = { cr = false } },
        ["'"] = { action = 'closeopen', pair = "''", neigh_pattern = '[^%a\\].', register = { cr = false } },
        ['`'] = { action = 'closeopen', pair = '``', neigh_pattern = '[^\\].', register = { cr = false } },
      },
    },
    config = function(_, opts)
      require('mini.pairs').setup(opts)
    end,
  },

  -- ══════════════════════════════════════════════════════════════════════════
  -- mini.comment - Commenting (gcc, gc{motion})
  -- ══════════════════════════════════════════════════════════════════════════
  {
    'echasnovski/mini.comment',
    event = 'VeryLazy',
    dependencies = {
      -- For JSX/TSX and other embedded language support
      {
        'JoosepAlviste/nvim-ts-context-commentstring',
        lazy = true,
        opts = {
          enable_autocmd = false,
        },
      },
    },
    opts = {
      -- Options which control module behavior
      options = {
        -- Function to compute custom 'commentstring' (optional)
        custom_commentstring = function()
          return require('ts_context_commentstring').calculate_commentstring() or vim.bo.commentstring
        end,
        -- Whether to ignore blank lines
        ignore_blank_line = false,
        -- Whether to recognize as comment only lines without indent
        start_of_line = false,
        -- Whether to force single space inner padding for comment parts
        pad_comment_parts = true,
      },
      -- Module mappings
      mappings = {
        -- Toggle comment (like `gcip` - Loss comment inner paragraph)
        comment = 'gc',
        -- Toggle comment on current line
        comment_line = 'gcc',
        -- Toggle comment on visual selection
        comment_visual = 'gc',
        -- Define 'comment' textobject (like `dgc` - delete whole comment block)
        textobject = 'gc',
      },
    },
  },

  -- ══════════════════════════════════════════════════════════════════════════
  -- mini.icons - Icon provider (used by many plugins)
  -- ══════════════════════════════════════════════════════════════════════════
  {
    'echasnovski/mini.icons',
    lazy = true,
    opts = {
      file = {
        ['.keep'] = { glyph = '󰊢', hl = 'MiniIconsGrey' },
        ['devcontainer.json'] = { glyph = '', hl = 'MiniIconsAzure' },
      },
      filetype = {
        dotenv = { glyph = '', hl = 'MiniIconsYellow' },
      },
    },
    init = function()
      -- Mock nvim-web-devicons for compatibility with other plugins
      package.preload['nvim-web-devicons'] = function()
        require('mini.icons').mock_nvim_web_devicons()
        return package.loaded['nvim-web-devicons']
      end
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
