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
    'rcasia/neotest-java',
    'nvim-neotest/neotest-plenary', -- This is for testing Lua plugins
  },
  config = function()
    require('neotest').setup {
      adapters = {
        -- Load your adapters here
        require 'neotest-java' {
          ignore_wrapper = false,
        },
        require 'neotest-plenary',
        --require 'neotest-python',
        -- require("neotest-go"),
      },
    }

    -- Keymaps
    -- Run the test under the cursor
    vim.keymap.set('n', '<leader>xnr', function()
      require('neotest').run.run()
    end, { desc = 'Test Run' })
    -- Run the current file
    vim.keymap.set('n', '<leader>xnf', function()
      require('neotest').run.run(vim.fn.expand '%')
    end, { desc = 'Test File' })
    -- Open the output window
    vim.keymap.set('n', '<leader>xno', function()
      require('neotest').output.open { enter = true }
    end, { desc = 'Test Output' })
    -- Open the summary window
    vim.keymap.set('n', '<leader>xns', function()
      require('neotest').summary.toggle()
    end, { desc = 'Test Summary' })
  end,
}
