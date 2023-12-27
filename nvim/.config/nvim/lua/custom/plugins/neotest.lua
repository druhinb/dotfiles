return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',

    -- ADAPTERS: Add your language adapters here!
    -- Examples:
    -- "nvim-neotest/neotest-python",
    -- "nvim-neotest/neotest-go",
    'nvim-neotest/neotest-plenary', -- This is for testing Lua plugins
  },
  config = function()
    require('neotest').setup {
      adapters = {
        -- Load your adapters here
        require 'neotest-plenary',
        --require 'neotest-python',
        -- require("neotest-go"),
      },
    }

    -- Keymaps
    -- Run the test under the cursor
    vim.keymap.set('n', '<leader>tr', function()
      require('neotest').run.run()
    end, { desc = '[T]est [R]un' })
    -- Run the current file
    vim.keymap.set('n', '<leader>tf', function()
      require('neotest').run.run(vim.fn.expand '%')
    end, { desc = '[T]est [F]ile' })
    -- Open the output window
    vim.keymap.set('n', '<leader>to', function()
      require('neotest').output.open { enter = true }
    end, { desc = '[T]est [O]utput' })
    -- Open the summary window
    vim.keymap.set('n', '<leader>ts', function()
      require('neotest').summary.toggle()
    end, { desc = '[T]est [S]ummary' })
  end,
}
