return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',

    -- ADAPTERS
    'nvim-neotest/neotest-plenary',
    'marilari88/neotest-vitest',
    'nvim-neotest/neotest-jest',
    'Issafalcon/neotest-dotnet',
  },
  config = function()
    require('neotest').setup {
      adapters = {
        require 'neotest-plenary',
        require 'neotest-vitest',
        require 'neotest-jest' {
          jestCommand = 'npx jest',
          cwd = function()
            return vim.fn.getcwd()
          end,
        },
        require 'neotest-dotnet',
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
