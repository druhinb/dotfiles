return {
  -- ===========================================================================
  -- vtsls: TypeScript/JavaScript Language Server (faster ts_ls alternative)
  -- Provides: inlay hints, auto-imports, rename-file, source definitions
  -- ===========================================================================
  {
    'yioneko/nvim-vtsls',
    ft = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'html', 'css', 'scss', 'svelte' },
    dependencies = {
      'saghen/blink.cmp',
    },
    config = function()
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      vim.lsp.config('vtsls', {
        capabilities = capabilities,
        settings = {
          typescript = {
            updateImportsOnFileMove = { enabled = 'always' },
            suggest = {
              completeFunctionCalls = true,
            },
            inlayHints = {
              parameterNames = { enabled = 'literals' },
              parameterTypes = { enabled = false },
              variableTypes = { enabled = false },
              propertyDeclarationTypes = { enabled = false },
              functionLikeReturnTypes = { enabled = true },
              enumMemberValues = { enabled = false },
            },
          },
          javascript = {
            updateImportsOnFileMove = { enabled = 'always' },
            suggest = {
              completeFunctionCalls = true,
            },
            inlayHints = {
              parameterNames = { enabled = 'literals' },
              parameterTypes = { enabled = false },
              variableTypes = { enabled = false },
              propertyDeclarationTypes = { enabled = false },
              functionLikeReturnTypes = { enabled = true },
              enumMemberValues = { enabled = false },
            },
          },
          vtsls = {
            enableMoveToFileCodeAction = true,
            autoUseWorkspaceTsdk = true,
          },
        },
        on_attach = function(client, bufnr)
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end,
      })
      vim.lsp.enable 'vtsls'

      -- Tailwind CSS Language Server
      vim.lsp.config('tailwindcss', {
        capabilities = capabilities,
        filetypes = {
          'html',
          'css',
          'scss',
          'javascript',
          'javascriptreact',
          'typescript',
          'typescriptreact',
          'svelte',
        },
        settings = {
          tailwindCSS = {
            experimental = {
              classRegex = {
                { 'tw`([^`]*)', '([^`]*)' },
                { '(?:clsx|cva|cn)\\(([^)]*)\\)', '["\'`]([^"\'`]*).*?["\'`]' },
                { 'class(?:Name)?\\s*=\\s*["\']([^"\']*)', '([^"\']*)' },
              },
            },
            validate = true,
            lint = {
              cssConflict = 'warning',
              invalidApply = 'error',
              invalidConfigPath = 'error',
              invalidScreen = 'error',
              invalidTailwindDirective = 'error',
              invalidVariant = 'error',
              recommendedVariantOrder = 'warning',
            },
          },
        },
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          local root = vim.fs.root(fname, {
            'tailwind.config.js',
            'tailwind.config.cjs',
            'tailwind.config.mjs',
            'tailwind.config.ts',
            'postcss.config.js',
            'postcss.config.cjs',
            'postcss.config.mjs',
            'postcss.config.ts',
          })
          if root then
            on_dir(root)
          end
        end,
      })
      vim.lsp.enable 'tailwindcss'

      -- React/TypeScript-specific buffer-local keymaps
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('lang-react-lsp-attach', { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= 'vtsls' then
            return
          end
          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = args.buf, desc = 'React/TS: ' .. desc })
          end

          map('<leader>ro', function()
            vim.lsp.buf.code_action {
              context = { only = { 'source.organizeImports' } },
              apply = true,
            }
          end, 'Organize Imports')

          map('<leader>ri', function()
            vim.lsp.buf.code_action {
              context = { only = { 'source.addMissingImports' } },
              apply = true,
            }
          end, 'Add Missing Imports')

          map('<leader>ru', function()
            vim.lsp.buf.code_action {
              context = { only = { 'source.removeUnused' } },
              apply = true,
            }
          end, 'Remove Unused Imports')

          map('<leader>rx', function()
            vim.lsp.buf.code_action {
              context = { only = { 'source.fixAll' } },
              apply = true,
            }
          end, 'Fix All')

          map('<leader>rF', function()
            require('vtsls').commands.rename_file(0)
          end, 'Rename File (update imports)')

          map('<leader>rD', function()
            require('vtsls').commands.goto_source_definition(0)
          end, 'Goto Source Definition')

          map('<leader>rR', function()
            require('vtsls').commands.file_references(0)
          end, 'File References')

          if vim.lsp.inlay_hint then
            vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
          end
        end,
      })
    end,
  },

  -- ===========================================================================
  -- nvim-ts-autotag: Auto close/rename JSX tags
  -- ===========================================================================
  {
    'windwp/nvim-ts-autotag',
    ft = { 'html', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'svelte', 'xml' },
    opts = {
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = true,
      },
    },
  },
}
