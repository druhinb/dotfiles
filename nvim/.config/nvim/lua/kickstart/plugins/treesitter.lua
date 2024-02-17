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
            ['af'] = '@function.outer',
            ['if'] = '@function.inner',

            -- Classes
            ['ac'] = '@class.outer',
            ['ic'] = '@class.inner',

            -- Blocks (scopes)
            ['ab'] = '@block.outer',
            ['ib'] = '@block.inner',

            -- Comments
            ['a/'] = '@comment.outer',
            ['i/'] = '@comment.inner',

            -- Assignments
            ['a='] = '@assignment.outer',
            ['i='] = '@assignment.inner',
            ['l='] = '@assignment.lhs',
            ['r='] = '@assignment.rhs',
          },
          include_surrounding_whitespace = true,
        },

        -- Swap textobjects (swap function parameters, etc.)
        swap = {
          enable = true,
          swap_next = {
            ['<leader>an'] = '@parameter.inner',
          },
          swap_previous = {
            ['<leader>ap'] = '@parameter.inner',
          },
        },

        -- Move to next/previous textobject
        move = {
          enable = true,
          set_jumps = true, -- Add to jumplist
          goto_next_start = {
            [']f'] = '@function.outer',
            [']k'] = '@class.outer',
            [']r'] = '@return.outer',
            [']/'] = '@comment.outer',
            [']='] = '@assignment.outer',
          },
          goto_next_end = {
            [']F'] = '@function.outer',
            [']K'] = '@class.outer',
            [']O'] = '@loop.outer',
          },
          goto_previous_start = {
            ['[f'] = '@function.outer',
            ['[k'] = '@class.outer',
            ['[r'] = '@return.outer',
            ['[/'] = '@comment.outer',
            ['[='] = '@assignment.outer',
          },
          goto_previous_end = {
            ['[F'] = '@function.outer',
            ['[K'] = '@class.outer',
            ['[O'] = '@loop.outer',
          },
        },

        -- LSP interop for smarter jumping
        lsp_interop = {
          enable = true,
          border = 'rounded',
          floating_preview_opts = {},
          peek_definition_code = {
            ['<leader>pf'] = '@function.outer',
            ['<leader>pk'] = '@class.outer',
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
      vim.keymap.set({ 'n', 'x', 'o' }, ',', ts_repeat_move.repeat_last_move_previous,
        { desc = 'Repeat last move (previous)' })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
