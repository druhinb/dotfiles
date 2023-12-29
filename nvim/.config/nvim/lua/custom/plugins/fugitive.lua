return {
  'tpope/vim-fugitive',
  dependencies = {
    'tpope/vim-rhubarb', -- Enable :Gbrowse for GitHub
    'junegunn/gv.vim', -- Commit browser
  },
  config = function()
    -- Keymap to open the Git Status window
    vim.keymap.set('n', '<leader>gs', vim.cmd.Git, { desc = '[G]it [S]tatus' })

    -- Keymap for git blame
    vim.keymap.set('n', '<leader>gB', function()
      vim.cmd.Git 'blame'
    end, { desc = '[G]it [B]lame' })

    -- Keymap for git diff
    vim.keymap.set('n', '<leader>gd', function()
      vim.cmd.Gdiffsplit()
    end, { desc = '[G]it [D]iff' })

    -- Keymap for git commit
    vim.keymap.set('n', '<leader>gc', function()
      vim.cmd.Git 'commit'
    end, { desc = '[G]it [C]ommit' })

    -- Keymap for git push
    vim.keymap.set('n', '<leader>gp', function()
      vim.cmd.Git 'push'
    end, { desc = '[G]it [P]ush' })

    -- Keymap for git pull
    vim.keymap.set('n', '<leader>gP', function()
      vim.cmd.Git 'pull'
    end, { desc = '[G]it [P]ull' })

    -- Keymap for git log
    vim.keymap.set('n', '<leader>gl', function()
      vim.cmd.Git 'log'
    end, { desc = '[G]it [L]og' })

    -- Keymap for git browse (open in browser)
    vim.keymap.set('n', '<leader>go', function()
      vim.cmd.Git 'browse'
    end, { desc = '[G]it [O]pen in browser' })

    -- Keymap for commit browser
    vim.keymap.set('n', '<leader>gv', function()
      vim.cmd.GV()
    end, { desc = '[G]it commit [V]iewer' })
    vim.keymap.set('n', '<leader>gV', function()
      vim.cmd.GV '!'
    end, { desc = '[G]it commit [V]iewer (current file)' })
  end,
}
