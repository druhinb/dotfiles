-- NOTE: I don't really use telescope, recommend fzf instead - Druhin

-- NOTE: Plugins can specify dependencies.
--
-- The dependencies are proper plugin specifications as well - anything
-- you do for a plugin at the top level, you can do for a dependency.
--
-- Use the `dependencies` key to specify the dependencies of a particular plugin

return {
  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      local actions = require 'telescope.actions'
      require('telescope').setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        defaults = {
          mappings = {
            i = {
              ['<C-k>'] = actions.move_selection_previous,
              ['<C-j>'] = actions.move_selection_next,
            },
            n = {
              ['<C-k>'] = actions.move_selection_previous,
              ['<C-j>'] = actions.move_selection_next,
            },
          },
        },
        -- pickers = {}
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'

      local is_ssh = vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil

      -- fzf-lua owns these mappings locally, but is disabled over SSH.
      -- In devspaces SSH env vars are present even though fzf is installed, so
      -- Telescope needs to provide the fallback mappings in that case too.
      if is_ssh or vim.fn.executable('fzf') == 0 then
        -- File/Find
        vim.keymap.set('n', '<leader><space>', builtin.find_files, { desc = 'Find Files (Root)' })
        vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find Files (Root)' })
        vim.keymap.set('n', '<leader>fF', function() builtin.find_files({ cwd = vim.fn.expand('%:p:h') }) end, { desc = 'Find Files (cwd)' })
        vim.keymap.set('n', '<leader>fr', builtin.oldfiles, { desc = 'Recent Files' })
        vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Buffers' })
        vim.keymap.set('n', '<leader>fg', builtin.git_files, { desc = 'Git Files' })

        -- Search
        vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = 'Grep (Root)' })
        vim.keymap.set('n', '<leader>sG', function() builtin.live_grep({ cwd = vim.fn.expand('%:p:h') }) end, { desc = 'Grep (cwd)' })
        vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = 'Word (Root)' })
        vim.keymap.set('n', '<leader>sW', function() builtin.grep_string({ cwd = vim.fn.expand('%:p:h') }) end, { desc = 'Word (cwd)' })
        vim.keymap.set('v', '<leader>sw', function()
          -- In telescope we can grep selection using visual select
          local saved_reg = vim.fn.getreg('v')
          vim.cmd('normal! "vy')
          local selection = vim.fn.getreg('v')
          vim.fn.setreg('v', saved_reg)
          builtin.grep_string({ search = selection })
        end, { desc = 'Selection (Root)' })

        vim.keymap.set('n', '<leader>sb', builtin.current_buffer_fuzzy_find, { desc = 'Buffer Lines' })
        vim.keymap.set('n', '<leader>/', builtin.current_buffer_fuzzy_find, { desc = 'Search in Buffer' })
        vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = 'Telescope Builtins' })
        vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = 'Resume' })
        vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = 'Help Pages' })
        vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = 'Keymaps' })
        vim.keymap.set('n', '<leader>sd', function() builtin.diagnostics({ bufnr = 0 }) end, { desc = 'Document Diagnostics' })
        vim.keymap.set('n', '<leader>sD', builtin.diagnostics, { desc = 'Workspace Diagnostics' })
        vim.keymap.set('n', '<leader>sq', builtin.quickfix, { desc = 'Quickfix List' })
        vim.keymap.set('n', '<leader>sl', builtin.loclist, { desc = 'Location List' })
        vim.keymap.set('n', '<leader>sm', builtin.marks, { desc = 'Marks' })

        -- Git
        vim.keymap.set('n', '<leader>gfc', builtin.git_commits, { desc = 'Find Git Commits' })
        vim.keymap.set('n', '<leader>gfC', builtin.git_bcommits, { desc = 'Find Git Buffer Commits' })
        vim.keymap.set('n', '<leader>gfS', builtin.git_stash, { desc = 'Find Git Stash' })

        -- Shortcut for searching your Neovim configuration files
        vim.keymap.set('n', '<leader>sn', function()
          builtin.find_files { cwd = vim.fn.stdpath 'config' }
        end, { desc = 'Search Neovim files' })
      end
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
