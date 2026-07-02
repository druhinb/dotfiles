-- Alternatively, use `config = function() ... end` for full control over the configuration.
-- If you prefer to call `setup` explicitly, use:
--    {
--        'lewis6991/gitsigns.nvim',
--        config = function()
--            require('gitsigns').setup({
--                -- Your gitsigns configuration here
--            })
--        end,
--    }
--
-- Here is a more advanced example where we pass configuration
-- options to `gitsigns.nvim`.
--
-- See `:help gitsigns` to understand what the configuration keys do
return {
  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      preview_config = {
        border = 'rounded',
      },
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Jump to next git [c]hange' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Jump to previous git [c]hange' })

        -- Actions
        -- visual mode
        map('v', '<leader>ghp', function()
          gitsigns.preview_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'Preview hunk' })
        map('v', '<leader>ghs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'Stage hunk' })
        map('v', '<leader>ghr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'Reset hunk' })
        -- normal mode
        map('n', '<leader>ghs', gitsigns.stage_hunk, { desc = 'Stage hunk' })
        map('n', '<leader>ghr', gitsigns.reset_hunk, { desc = 'Reset hunk' })
        map('n', '<leader>ghS', gitsigns.stage_buffer, { desc = 'Stage buffer' })
        map('n', '<leader>ghu', gitsigns.undo_stage_hunk, { desc = 'Undo stage hunk' })
        map('n', '<leader>ghR', gitsigns.reset_buffer, { desc = 'Reset buffer' })
        map('n', '<leader>ghp', gitsigns.preview_hunk, { desc = 'Preview hunk' })
        map('n', '<leader>ghb', gitsigns.blame_line, { desc = 'Blame line' })
        -- Toggles
        map('n', '<leader>tgd', gitsigns.toggle_deleted, { desc = 'Toggle git deleted' })
      end,
    },
    config = function(_, opts)
      require('gitsigns').setup(opts)

      -- Disable gitsigns when a merge or rebase conflict is detected
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
