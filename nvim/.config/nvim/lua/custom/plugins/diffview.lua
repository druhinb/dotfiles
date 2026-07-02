return {
  'sindrets/diffview.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewToggleFiles', 'DiffviewFocusFiles', 'DiffviewFileHistory' },
  keys = {
    { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = 'Git diff' },
    { '<leader>gD', '<cmd>DiffviewClose<cr>', desc = 'Close Git diff' },
    { '<leader>gF', '<cmd>DiffviewFileHistory %<cr>', desc = 'File history' },
    { '<leader>gH', '<cmd>DiffviewFileHistory<cr>', desc = 'Repository history' },
  },
  config = function()
    local actions = require 'diffview.actions'
    require('diffview').setup {
      enhanced_diff_hl = true,
      use_icons = true,
      icons = {
        folder_closed = '',
        folder_open = '',
        file = '',
      },
      signs = {
        add = { text = '+' },
        modify = { text = '~' },
        remove = { text = '-' },
      },
      view = {
        default = {
          layout = 'diff2_horizontal',
        },
        merge_tool = {
          layout = 'diff3_mixed',
          disable_diagnostics = true,
        },
        file_history = {
          layout = 'diff2_horizontal',
        },
      },
      file_panel = {
        listing_style = 'tree',
        tree_options = {
          flatten_dirs = true,
          folder_statuses = 'only_folded',
        },
      },
      file_history_panel = {
        log_options = {
          git = {
            single_file = { diff_merges = 'combined' },
            multi_file = { diff_merges = 'first-parent' },
          },
        },
      },
      keymaps = {
        view = {
          { 'n', '<leader>cc', actions.conflict_choose 'ours', { desc = 'Choose Current (Ours)' } },
          { 'n', '<leader>ci', actions.conflict_choose 'theirs', { desc = 'Choose Incoming (Theirs)' } },
          { 'n', '<leader>cb', actions.conflict_choose 'base', { desc = 'Choose Base' } },
          { 'n', '<leader>ca', actions.conflict_choose 'all', { desc = 'Choose All (Both)' } },
        },
      },
    }
  end,
}
