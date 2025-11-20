return {
  'sindrets/diffview.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('diffview').setup({
      diff_bin = 'diff', -- Use the system diff command
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
        -- Configure the layout of the diff view
        layout = {
          {
            type = 'diff',
            win_opts = {
              -- You can specify window options here
            },
          },
          {
            type = 'file_history',
            win_opts = {
              -- You can specify window options here
            },
          },
        },
      },
      file_panel = {
        listing_style = 'tree',
        tree_options = {
          -- Options for the tree listing style
        },
      },
      file_history_panel = {
        log_options = {
          -- Options for the git log command
        },
      },
      merge_tool = {
        -- Configuration for the merge tool
        layout = 'diff3',
        -- Other merge tool options
      },
    })
  end,
}