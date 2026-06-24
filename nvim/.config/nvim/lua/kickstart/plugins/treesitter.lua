local is_ssh = vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil

return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    dependencies = {
      {
        'nvim-treesitter/nvim-treesitter-textobjects',
        branch = 'main',
      },
    },
    config = function()
      -- 1. Initialize the plugin
      require('nvim-treesitter').setup()

      -- 2. Install / update parsers programmatically
      local ensure_installed = {
        'bash', 'c', 'c_sharp', 'cpp', 'diff', 'doxygen', 'html', 'java',
        'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim',
        'vimdoc', 'python', 'rust', 'toml'
      }

      local installed = require('nvim-treesitter.config').get_installed()
      local to_install = vim.tbl_filter(function(parser)
        return not vim.tbl_contains(installed, parser)
      end, ensure_installed)

      if #to_install > 0 then
        require('nvim-treesitter').install(to_install)
      end

      -- Enable Tree-sitter highlighting natively for all buffers with installed parsers.
      -- This fixes missing Doxygen syntax highlighting in code buffers and the LSP hover floating window.
      vim.api.nvim_create_autocmd('FileType', {
        desc = 'Start Tree-sitter highlight for buffer',
        group = vim.api.nvim_create_augroup('treesitter-highlight', { clear = true }),
        pattern = '*',
        callback = function(args)
          local buf = args.buf
          if not vim.api.nvim_buf_is_valid(buf) then
            return
          end
          pcall(vim.treesitter.start, buf)
        end,
      })

      -- 2. Configure incremental selection (native keymaps)
      -- In Neovim 0.12+, native incremental selection is built-in.
      -- v -> enters visual mode
      -- C-space in visual mode -> expands selection to parent node (native 'an')
      -- Backspace in visual mode -> shrinks selection to child node (native 'in')
      vim.keymap.set('n', '<C-space>', 'v', { desc = 'Visual Mode / Init Selection' })
      vim.keymap.set('v', '<C-space>', 'an', { desc = 'Increment Selection' })
      vim.keymap.set('v', '<bs>', 'in', { desc = 'Decrement Selection' })

      -- 3. Configure textobjects (new standalone configuration)
      require('nvim-treesitter-textobjects').setup {
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
      }
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
