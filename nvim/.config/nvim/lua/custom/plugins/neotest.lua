return {
  'nvim-neotest/neotest',
  keys = {
    {
      '<leader>Tn',
      function()
        require('neotest').run.run()
      end,
      desc = 'Run nearest test',
    },
    {
      '<leader>Tf',
      function()
        require('neotest').run.run(vim.fn.expand '%')
      end,
      desc = 'Run test file',
    },
    {
      '<leader>Ta',
      function()
        require('neotest').run.run(vim.uv.cwd())
      end,
      desc = 'Run all tests',
    },
    {
      '<leader>Td',
      function()
        require('neotest').run.run { strategy = 'dap' }
      end,
      desc = 'Debug nearest test',
    },
    {
      '<leader>To',
      function()
        require('neotest').output.open { enter = true }
      end,
      desc = 'Test output',
    },
    {
      '<leader>TO',
      function()
        require('neotest').output_panel.toggle()
      end,
      desc = 'Test output panel',
    },
    {
      '<leader>Ts',
      function()
        require('neotest').summary.toggle()
      end,
      desc = 'Test summary',
    },
    {
      '<leader>Tt',
      function()
        require('neotest').run.stop()
      end,
      desc = 'Stop test',
    },
  },
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
    'nvim-neotest/neotest-python',
    'nvim-neotest/neotest-go',
    'rouge8/neotest-rust',
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
        require 'neotest-python' {
          dap = { justMyCode = false },
        },
        require 'neotest-go' {
          experimental = { test_table = true },
          args = { '-count=1' },
        },
        require 'neotest-rust',
      },
    }
  end,
}
