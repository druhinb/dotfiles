return {
  -- ===========================================================================
  -- roslyn.nvim: C# Language Server (Microsoft Roslyn)
  -- Provides: diagnostics, completions, refactoring, go-to-definition, inlay hints
  -- ===========================================================================
  {
    'seblj/roslyn.nvim',
    ft = 'cs',
    dependencies = {
      'saghen/blink.cmp',
      {
        'mason-org/mason.nvim',
        opts = {
          registries = {
            'github:mason-org/mason-registry',
            'github:Crashdummyy/mason-registry',
          },
        },
      },
    },
    -- roslyn.nvim enables its LSP from plugin/roslyn.lua before lazy.nvim runs
    -- `config`, so register overrides during `init` to affect the first client.
    init = function()
      vim.lsp.config('roslyn', {
        before_init = function(_, config)
          config.capabilities = require('blink.cmp').get_lsp_capabilities(config.capabilities, true)
        end,
        settings = {
          ['csharp|background_analysis'] = {
            dotnet_analyzer_diagnostics_scope = 'openFiles',
            dotnet_compiler_diagnostics_scope = 'openFiles',
          },
          ['csharp|inlay_hints'] = {
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
            csharp_enable_inlay_hints_for_lambda_parameter_types = true,
            csharp_enable_inlay_hints_for_types = true,
            dotnet_enable_inlay_hints_for_indexer_parameters = false,
            dotnet_enable_inlay_hints_for_literal_parameters = true,
            dotnet_enable_inlay_hints_for_object_creation_parameters = false,
            dotnet_enable_inlay_hints_for_other_parameters = false,
            dotnet_enable_inlay_hints_for_parameters = true,
            dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
            dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
            dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
          },
          ['csharp|code_lens'] = {
            dotnet_enable_references_code_lens = false,
            dotnet_enable_tests_code_lens = false,
          },
          ['csharp|completion'] = {
            dotnet_provide_regex_completions = true,
            dotnet_show_completion_items_from_unimported_namespaces = true,
            dotnet_show_name_completion_suggestions = true,
          },
          ['csharp|symbol_search'] = {
            dotnet_search_reference_assemblies = true,
          },
        },
        on_attach = function(client, bufnr)
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end,
      })
    end,

    config = function()
      require('roslyn').setup {
        filewatching = 'roslyn',
        broad_search = true,
        lock_target = true,
      }

      -- C#-specific buffer-local keymaps
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('lang-csharp-lsp-attach', { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= 'roslyn' then
            return
          end
          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = args.buf, desc = 'C#: ' .. desc })
          end

          map('<leader>ro', function()
            vim.lsp.buf.code_action {
              context = { only = { 'source.organizeImports' } },
              apply = true,
            }
          end, 'Organize Usings')

          map('<leader>ru', function()
            vim.lsp.buf.code_action {
              context = { only = { 'source.removeUnusedImports' } },
              apply = true,
            }
          end, 'Remove Unused Usings')

          map('<leader>rx', function()
            vim.lsp.buf.code_action {
              context = { only = { 'source.fixAll' } },
              apply = true,
            }
          end, 'Fix All')

          map('<leader>rn', function()
            vim.lsp.buf.code_action {
              context = { only = { 'refactor.rewrite' } },
            }
          end, 'Refactor/Rewrite')

          map('<leader>rs', '<cmd>Roslyn target<cr>', 'Switch Solution')

          if vim.lsp.inlay_hint then
            vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
          end
        end,
      })
    end,
  },
}
