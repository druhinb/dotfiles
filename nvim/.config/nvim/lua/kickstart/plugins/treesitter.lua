return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc', 'python', 'rust', 'toml' },
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },

      -- Incremental selection based on treesitter nodes
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = '<C-space>',
          node_incremental = '<C-space>',
          scope_incremental = false,
          node_decremental = '<bs>',
        },
      },

      -- Treesitter textobjects configuration
      textobjects = {
        -- Selection textobjects (use with v, d, c, y, etc.)
        select = {
          enable = true,
          lookahead = true, -- Automatically jump forward to textobj
          keymaps = {
            -- Functions/Methods
            ['af'] = { query = '@function.outer', desc = 'Around [F]unction' },
            ['if'] = { query = '@function.inner', desc = 'Inside [F]unction' },

            -- Classes
            ['ac'] = { query = '@class.outer', desc = 'Around [C]lass' },
            ['ic'] = { query = '@class.inner', desc = 'Inside [C]lass' },

            -- Blocks (scopes)
            ['ab'] = { query = '@block.outer', desc = 'Around [B]lock' },
            ['ib'] = { query = '@block.inner', desc = 'Inside [B]lock' },

            -- Comments
            ['a/'] = { query = '@comment.outer', desc = 'Around comment' },
            ['i/'] = { query = '@comment.inner', desc = 'Inside comment' },

            -- Assignments
            ['a='] = { query = '@assignment.outer', desc = 'Around assignment' },
            ['i='] = { query = '@assignment.inner', desc = 'Inside assignment' },
            ['l='] = { query = '@assignment.lhs', desc = '[L]eft side of assignment' },
            ['r='] = { query = '@assignment.rhs', desc = '[R]ight side of assignment' },

            -- Include surrounding whitespace
            include_surrounding_whitespace = true,
          },

          -- Swap textobjects (swap function parameters, etc.)
          swap = {
            enable = true,
            swap_next = {
              ['<leader>an'] = { query = '@parameter.inner', desc = 'Swap [A]rg with [N]ext' },
            },
            swap_previous = {
              ['<leader>ap'] = { query = '@parameter.inner', desc = 'Swap [A]rg with [P]rev' },
            },
          },

          -- Move to next/previous textobject
          move = {
            enable = true,
            set_jumps = true, -- Add to jumplist
            goto_next_start = {
              [']f'] = { query = '@function.outer', desc = 'Next [F]unction start' },
              [']k'] = { query = '@class.outer', desc = 'Next [K]lass start' },
              [']r'] = { query = '@return.outer', desc = 'Next [R]eturn' },
              [']/'] = { query = '@comment.outer', desc = 'Next comment' },
              [']='] = { query = '@assignment.outer', desc = 'Next assignment' },
            },
            goto_next_end = {
              [']F'] = { query = '@function.outer', desc = 'Next [F]unction end' },
              [']K'] = { query = '@class.outer', desc = 'Next [K]lass end' },
              [']O'] = { query = '@loop.outer', desc = 'Next l[O]op end' },
            },
            goto_previous_start = {
              ['[f'] = { query = '@function.outer', desc = 'Prev [F]unction start' },
              ['[k'] = { query = '@class.outer', desc = 'Prev [K]lass start' },
              ['[r'] = { query = '@return.outer', desc = 'Prev [R]eturn' },
              ['[/'] = { query = '@comment.outer', desc = 'Prev comment' },
              ['[='] = { query = '@assignment.outer', desc = 'Prev assignment' },
            },
            goto_previous_end = {
              ['[F'] = { query = '@function.outer', desc = 'Prev [F]unction end' },
              ['[K'] = { query = '@class.outer', desc = 'Prev [K]lass end' },
              ['[O'] = { query = '@loop.outer', desc = 'Prev l[O]op end' },
            },
          },

          -- LSP interop for smarter jumping
          lsp_interop = {
            enable = true,
            border = 'rounded',
            floating_preview_opts = {},
            peek_definition_code = {
              ['<leader>pf'] = { query = '@function.outer', desc = '[P]eek [F]unction definition' },
              ['<leader>pk'] = { query = '@class.outer', desc = '[P]eek [K]lass definition' },
            },
          },
        },
      },
      config = function(_, opts)
        require('nvim-treesitter.configs').setup(opts)

        -- Repeat movement with ; and ,
        local ts_repeat_move = require 'nvim-treesitter.textobjects.repeatable_move'

        -- Make ; and , repeat the last treesitter textobject move
        vim.keymap.set({ 'n', 'x', 'o' }, ';', ts_repeat_move.repeat_last_move_next, { desc = 'Repeat last move (next)' })
        vim.keymap.set({ 'n', 'x', 'o' }, ',', ts_repeat_move.repeat_last_move_previous, { desc = 'Repeat last move (previous)' })
      end,
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
