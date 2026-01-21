return {
  {
    'nvim-java/nvim-java',
    event = 'VeryLazy',
    dependencies = {
      'MunifTanjim/nui.nvim',
      'mfussenegger/nvim-dap',
      'nvim-lua/plenary.nvim',
      'saghen/blink.cmp',
    },
    config = function()
      require('java').setup {
        checks = {
          nvim_jdtls_conflict = false,
        },
        spring_boot_tools = {
          enable = false,
        },
        jdk = {
          auto_install = false,
        },
        log = {
          use_console = false,
          level = 'warn',
        },
        lombok = {
          enable = true,
        },
        java_test = {
          enable = true,
        },
        java_debug_adapter = {
          enable = true,
        },
      }

      vim.lsp.config('jdtls', {
        capabilities = require('blink.cmp').get_lsp_capabilities(),
        settings = {
          java = {
            configuration = {
              updateBuildConfiguration = 'interactive',
            },
            inlayHints = {
              parameterNames = {
                enabled = 'all',
              },
            },
            format = {
              enabled = true,
              settings = {
                profile = 'GoogleStyle',
              },
            },
            completion = {
              favoriteStaticMembers = {
                'org.junit.Assert.*',
                'org.junit.jupiter.api.Assertions.*',
                'org.mockito.Mockito.*',
                'org.mockito.ArgumentMatchers.*',
              },
              importOrder = {
                'java',
                'javax',
                'com',
                'org',
              },
            },
            sources = {
              organizeImports = {
                starThreshold = 9999,
                staticStarThreshold = 9999,
              },
            },
            codeGeneration = {
              toString = {
                template = '${object.className}{${member.name()}=${member.value}, ${otherMembers}}',
              },
              useBlocks = true,
            },
          },
        },
        on_attach = function(_, bufnr)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = 'Java: ' .. desc })
          end

          map('<leader>co', function()
            vim.lsp.buf.code_action {
              apply = true,
              context = {
                only = { 'source.organizeImports' },
                diagnostics = {},
              },
            }
          end, 'Organize Imports')
          map('<leader>cv', function() require('java').refactor.extract_variable() end, 'Extract Variable')
          map(
            '<leader>cV',
            function() require('java').refactor.extract_variable_all_occurrence() end,
            'Extract Variable (all occurrences)'
          )
          map('<leader>cm', function() require('java').refactor.extract_method() end, 'Extract Method')
          map('<leader>cm', function() require('java').refactor.extract_method() end, 'Extract Method', 'v')
          map('<leader>cC', function() require('java').refactor.extract_constant() end, 'Extract Constant')
          map('<leader>cF', function() require('java').refactor.extract_field() end, 'Extract Field')
          map('<leader>ct', function() require('java').test.run_current_method() end, 'Run Nearest Test')
          map('<leader>cT', function() require('java').test.run_current_class() end, 'Run Test Class')
        end,
      })

      vim.lsp.enable 'jdtls'
    end,
  },
}
