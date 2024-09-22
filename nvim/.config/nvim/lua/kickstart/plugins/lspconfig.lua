-- =============================================================================
-- LSP Configuration (LazyVim Architecture)
-- =============================================================================
-- This configuration follows LazyVim's declarative, table-based approach:
--   1. Dependencies are properly orchestrated (mason -> mason-lspconfig -> lspconfig)
--   2. Capabilities broadcast via blink.cmp to all servers
--   3. Centralized servers table for easy configuration
--   4. LazyVim-style keymaps with capability checking
--   5. Deep integration with trouble.nvim for diagnostics/references
-- =============================================================================

-- =============================================================================
-- Server Configurations Table
-- =============================================================================
-- Add/modify servers here. Each key is the server name, value is the config.
-- Industry-standard servers for each language.
local servers = {
  -- ===========================================================================
  -- Python
  -- ===========================================================================
  basedpyright = {
    settings = {
      basedpyright = {
        analysis = {
          typeCheckingMode = 'standard',
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          diagnosticMode = 'openFilesOnly',
          inlayHints = {
            variableTypes = true,
            functionReturnTypes = true,
            callArgumentNames = true,
            genericTypes = false,
          },
          diagnosticSeverityOverrides = {
            reportMissingImports = 'error',
            reportUndefinedVariable = 'error',
            reportUnboundVariable = 'error',
            reportGeneralTypeIssues = 'error',
            reportMissingTypeStubs = 'warning',
            reportOptionalMemberAccess = 'warning',
            reportOptionalSubscript = 'warning',
            reportPrivateUsage = 'warning',
            reportConstantRedefinition = 'warning',
            reportAssertAlwaysTrue = 'warning',
            reportSelfClsParameterName = 'warning',
            reportUnusedImport = 'none', -- ruff handles this
            reportUnusedVariable = 'none', -- ruff handles this
            reportUnusedFunction = 'none',
            reportDuplicateImport = 'none',
            reportUnknownMemberType = 'none',
            reportUnknownArgumentType = 'none',
            reportUnknownVariableType = 'none',
            reportUnknownLambdaType = 'none',
            reportMissingParameterType = 'none',
            reportMissingReturnType = 'none',
            reportImplicitStringConcatenation = 'none',
            reportInvalidStubStatement = 'none',
            reportIncompleteStub = 'none',
          },
        },
      },
    },
    -- Disable formatting (ruff handles it via conform)
    on_attach = function(client, bufnr)
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end,
  },

  ruff = {
    init_options = {
      settings = {
        logLevel = 'warn',
        showSyntaxErrors = true,
        organizeImports = true,
        fixAll = true,
        codeAction = {
          fixViolation = { enable = true },
          disableRuleComment = { enable = true },
        },
        lint = {
          select = { 'E', 'W', 'F', 'I', 'B', 'C4', 'UP' },
        },
      },
    },
  },

  -- ===========================================================================
  -- Web Development (TypeScript/JavaScript)
  -- ===========================================================================
  ts_ls = {
    settings = {
      typescript = {
        inlayHints = {
          includeInlayParameterNameHints = 'literals',
          includeInlayParameterNameHintsWhenArgumentMatchesName = false,
          includeInlayFunctionParameterTypeHints = false,
          includeInlayVariableTypeHints = false,
          includeInlayPropertyDeclarationTypeHints = false,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = false,
        },
      },
      javascript = {
        inlayHints = {
          includeInlayParameterNameHints = 'literals',
          includeInlayParameterNameHintsWhenArgumentMatchesName = false,
          includeInlayFunctionParameterTypeHints = false,
          includeInlayVariableTypeHints = false,
          includeInlayPropertyDeclarationTypeHints = false,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = false,
        },
      },
    },
  },

  svelte = {
    settings = {
      svelte = {
        enableFallbackPreprocessor = true,
        plugin = {
          svelte = {
            compilerWarnings = {
              ['css-unused-selector'] = 'ignore',
            },
          },
        },
      },
    },
  },

  html = {
    filetypes = { 'html', 'htmldjango' },
  },

  cssls = {
    settings = {
      css = {
        validate = true,
        lint = { unknownAtRules = 'ignore' },
      },
      scss = { validate = true },
      less = { validate = true },
    },
  },

  emmet_language_server = {
    filetypes = { 'html', 'css', 'scss', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'svelte' },
  },

  -- ===========================================================================
  -- Systems Programming
  -- ===========================================================================
  clangd = {
    cmd = {
      'clangd',
      '--background-index',
      '--clang-tidy',
      '--header-insertion=iwyu',
      '--completion-style=detailed',
      '--function-arg-placeholders',
      '--fallback-style=llvm',
    },
    init_options = {
      usePlaceholders = true,
      completeUnimported = true,
      clangdFileStatus = true,
    },
    -- clangd has its own completion ranking
    capabilities = {
      offsetEncoding = { 'utf-16' },
    },
  },

  rust_analyzer = {
    settings = {
      ['rust-analyzer'] = {
        cargo = {
          allFeatures = true,
          loadOutDirsFromCheck = true,
          buildScripts = { enable = true },
        },
        checkOnSave = {
          allFeatures = true,
          command = 'clippy',
          extraArgs = { '--no-deps' },
        },
        procMacro = {
          enable = true,
          ignored = {
            ['async-trait'] = { 'async_trait' },
            ['napi-derive'] = { 'napi' },
            ['async-recursion'] = { 'async_recursion' },
          },
        },
      },
    },
  },

  asm_lsp = {
    filetypes = { 'asm', 'nasm', 'masm', 's', 'S' },
  },

  -- ===========================================================================
  -- Go
  -- ===========================================================================
  gopls = {
    settings = {
      gopls = {
        analyses = {
          unusedparams = true,
          shadow = true,
          nilness = true,
          unusedwrite = true,
          useany = true,
        },
        staticcheck = true,
        hints = {
          assignVariableTypes = true,
          compositeLiteralFields = true,
          compositeLiteralTypes = true,
          constantValues = true,
          functionTypeParameters = true,
          parameterNames = true,
          rangeVariableTypes = true,
        },
        codelenses = {
          gc_details = true,
          generate = true,
          regenerate_cgo = true,
          run_govulncheck = true,
          test = true,
          tidy = true,
          upgrade_dependency = true,
          vendor = true,
        },
        gofumpt = true,
        semanticTokens = true,
        completeUnimported = true,
        usePlaceholders = true,
      },
    },
  },

  -- ===========================================================================
  -- Markdown
  -- ===========================================================================
  marksman = {},

  ltex = {
    filetypes = { 'markdown', 'text', 'latex', 'tex', 'bib', 'gitcommit' },
    settings = {
      ltex = {
        language = 'en-US',
        disabledRules = {
          ['en-US'] = { 'MORFOLOGIK_RULE_EN_US' },
        },
        dictionary = {},
        checkFrequency = 'save',
      },
    },
  },

  -- ===========================================================================
  -- Lua (Neovim)
  -- ===========================================================================
  lua_ls = {
    settings = {
      Lua = {
        completion = { callSnippet = 'Replace' },
        -- diagnostics = { disable = { 'missing-fields' } },
      },
    },
  },

  -- ===========================================================================
  -- Configuration Files (YAML, JSON, TOML)
  -- ===========================================================================
  yamlls = {
    settings = {
      yaml = {
        schemaStore = {
          enable = true,
          url = 'https://www.schemastore.org/api/json/catalog.json',
        },
        schemas = {
          ['https://json.schemastore.org/github-workflow.json'] = '/.github/workflows/*',
          ['https://json.schemastore.org/github-action.json'] = '/.github/actions/*/action.yml',
          ['https://json.schemastore.org/dependabot-2.0.json'] = '/.github/dependabot.yml',
          ['https://json.schemastore.org/docker-compose.json'] = 'docker-compose*.yml',
          ['https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json'] = 'docker-compose*.yml',
          ['https://json.schemastore.org/pre-commit-config.json'] = '.pre-commit-config.yml',
        },
        format = { enable = true, singleQuote = false, bracketSpacing = true },
        validate = true,
        hover = true,
        completion = true,
      },
    },
  },

  jsonls = {
    settings = {
      json = {
        validate = { enable = true },
        format = { enable = true },
      },
    },
    on_attach = function(client, bufnr)
      local ok, schemastore = pcall(require, 'schemastore')
      if ok and client.config and client.config.settings then
        client.config.settings.json.schemas = schemastore.json.schemas()
      end
    end,
  },

  taplo = {
    settings = {
      taplo = {
        formatter = {
          alignEntries = false,
          alignComments = true,
          arrayTrailingComma = true,
          arrayAutoExpand = true,
          arrayAutoCollapse = true,
          compactArrays = true,
          compactInlineTables = false,
          columnWidth = 80,
          indentTables = false,
          indentEntries = false,
          reorderKeys = true,
          trailingNewline = true,
        },
      },
    },
  },

  -- ===========================================================================
  -- Shell
  -- ===========================================================================
  bashls = {},

  -- ===========================================================================
  -- Docker
  -- ===========================================================================
  dockerls = {},
  docker_compose_language_service = {},

  -- ===========================================================================
  -- SQL
  -- ===========================================================================
  sqlls = {},
}

-- =============================================================================
-- LSP Keymaps (LazyVim Style)
-- =============================================================================
-- Keymaps are capability-based and buffer-local
local function setup_keymaps(event)
  local map = function(keys, func, desc, mode)
    mode = mode or 'n'
    vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
  end

  -- ===========================================================================
  -- Core Navigation (LazyVim defaults)
  -- ===========================================================================
  map('gd', vim.lsp.buf.definition, 'Goto Definition')
  map('gD', vim.lsp.buf.declaration, 'Goto Declaration')
  map('gI', vim.lsp.buf.implementation, 'Goto Implementation')
  map('gy', vim.lsp.buf.type_definition, 'Goto Type Definition')
  map('K', vim.lsp.buf.hover, 'Hover Documentation')
  map('gK', vim.lsp.buf.signature_help, 'Signature Help')

  -- References → Opens in Trouble window (LazyVim workflow)
  map('gr', function()
    require('trouble').open { mode = 'lsp_references', focus = true }
  end, 'References (Trouble)')

  -- Also keep fzf-lua references on gR for quick fuzzy finding
  map('gR', function()
    require('fzf-lua').lsp_references()
  end, 'References (FZF)')

  -- ===========================================================================
  -- Code Actions (LazyVim style)
  -- ===========================================================================
  map('<leader>ca', vim.lsp.buf.code_action, 'Code Action', { 'n', 'x' })
  map('<leader>cA', function()
    vim.lsp.buf.code_action { context = { only = { 'source' }, diagnostics = {} } }
  end, 'Source Action')
  map('<leader>cr', vim.lsp.buf.rename, 'Rename')

  -- Quick fix - apply first preferred code action
  map('<leader>qf', function()
    vim.lsp.buf.code_action {
      filter = function(action)
        return action.isPreferred
      end,
      apply = true,
    }
  end, 'Quick Fix')

  -- ===========================================================================
  -- Document/Workspace Operations
  -- ===========================================================================
  map('<leader>ds', function()
    require('fzf-lua').lsp_document_symbols()
  end, 'Document Symbols')
  map('<leader>ws', function()
    require('fzf-lua').lsp_live_workspace_symbols()
  end, 'Workspace Symbols')

  -- ===========================================================================
  -- Diagnostics Navigation
  -- ===========================================================================
  map(']d', vim.diagnostic.goto_next, 'Next Diagnostic')
  map('[d', vim.diagnostic.goto_prev, 'Prev Diagnostic')
  map(']e', function()
    vim.diagnostic.goto_next { severity = vim.diagnostic.severity.ERROR }
  end, 'Next Error')
  map('[e', function()
    vim.diagnostic.goto_prev { severity = vim.diagnostic.severity.ERROR }
  end, 'Prev Error')
  map(']w', function()
    vim.diagnostic.goto_next { severity = vim.diagnostic.severity.WARN }
  end, 'Next Warning')
  map('[w', function()
    vim.diagnostic.goto_prev { severity = vim.diagnostic.severity.WARN }
  end, 'Prev Warning')

  -- ===========================================================================
  -- Code Organization
  -- ===========================================================================
  map('<leader>oi', function()
    vim.lsp.buf.code_action { context = { only = { 'source.organizeImports' } }, apply = true }
  end, 'Organize Imports')

  -- ===========================================================================
  -- Toggles
  -- ===========================================================================
  map('<leader>td', function()
    vim.diagnostic.enable(not vim.diagnostic.is_enabled())
  end, 'Toggle Diagnostics')
end

-- =============================================================================
-- On Attach Handler
-- =============================================================================
local function on_attach(event)
  local client = vim.lsp.get_client_by_id(event.data.client_id)
  if not client then
    return
  end

  -- Setup keymaps
  setup_keymaps(event)

  -- ===========================================================================
  -- Capability-based features
  -- ===========================================================================
  local function client_supports_method(c, method, bufnr)
    if vim.fn.has 'nvim-0.11' == 1 then
      return c:supports_method(method, bufnr)
    else
      return c.supports_method(method, { bufnr = bufnr })
    end
  end

  -- Inlay hints toggle
  if client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
    vim.keymap.set('n', '<leader>th', function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
    end, { buffer = event.buf, desc = 'LSP: Toggle Inlay Hints' })
  end

  -- Document highlight
  if client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
    local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
    vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
      buffer = event.buf,
      group = highlight_augroup,
      callback = vim.lsp.buf.document_highlight,
    })
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
      buffer = event.buf,
      group = highlight_augroup,
      callback = vim.lsp.buf.clear_references,
    })
    vim.api.nvim_create_autocmd('LspDetach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
      callback = function(event2)
        vim.lsp.buf.clear_references()
        vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
      end,
    })
  end

  -- Code lens
  if client_supports_method(client, vim.lsp.protocol.Methods.textDocument_codeLens, event.buf) then
    vim.keymap.set('n', '<leader>cL', vim.lsp.codelens.run, { buffer = event.buf, desc = 'LSP: Run Code Lens' })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'InsertLeave' }, {
      buffer = event.buf,
      callback = vim.lsp.codelens.refresh,
    })
  end
end

-- =============================================================================
-- Plugin Specifications
-- =============================================================================
return {
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      -- Mason orchestration (order matters)
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- LSP progress
      { 'j-hui/fidget.nvim', opts = {} },

      -- Completion capabilities
      'saghen/blink.cmp',

      -- Schema support
      'b0o/schemastore.nvim',
    },
    opts = function()
      return {
        -- ===========================================================================
        -- Diagnostics Configuration (LazyVim style)
        -- ===========================================================================
        diagnostics = {
          severity_sort = true,
          float = { border = 'rounded', source = 'if_many' },
          underline = { severity = vim.diagnostic.severity.ERROR },
          update_in_insert = false,
          signs = vim.g.have_nerd_font and {
            text = {
              [vim.diagnostic.severity.ERROR] = '󰅚 ',
              [vim.diagnostic.severity.WARN] = '󰀪 ',
              [vim.diagnostic.severity.INFO] = '󰋽 ',
              [vim.diagnostic.severity.HINT] = '󰌶 ',
            },
          } or {},
          virtual_text = {
            source = 'if_many',
            spacing = 4,
            prefix = '●',
          },
        },

        -- ===========================================================================
        -- Feature Toggles
        -- ===========================================================================
        inlay_hints = {
          enabled = true,
          exclude = { 'vue' },
        },
        codelens = {
          enabled = false,
        },

        -- ===========================================================================
        -- Server Configurations
        -- ===========================================================================
        servers = servers,

        -- ===========================================================================
        -- Mason Tools (formatters, linters)
        -- ===========================================================================
        ensure_installed = {
          -- Lua
          'stylua',
          -- C/C++
          'clang-format',
          'cpplint',
          -- Python
          'ruff',
          -- TypeScript/JavaScript
          'prettier',
          'eslint_d',
          -- HTML/CSS
          'prettierd',
          -- Shell
          'shellcheck',
          'shfmt',
          -- Go
          'gofumpt',
          'goimports',
          'golangci-lint',
          -- Markdown
          'markdownlint',
          -- YAML/JSON
          'yamllint',
          -- SQL
          'sqlfluff',
        },
      }
    end,
    config = function(_, opts)
      -- ===========================================================================
      -- Setup LspAttach autocmd
      -- ===========================================================================
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = on_attach,
      })

      -- ===========================================================================
      -- Configure Diagnostics
      -- ===========================================================================
      vim.diagnostic.config(opts.diagnostics)
      vim.opt.updatetime = 250

      -- ===========================================================================
      -- Enable Inlay Hints (if supported)
      -- ===========================================================================
      if opts.inlay_hints.enabled and vim.lsp.inlay_hint then
        vim.lsp.inlay_hint.enable(true)
      end

      -- ===========================================================================
      -- Setup Capabilities (blink.cmp)
      -- ===========================================================================
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- ===========================================================================
      -- Mason Tool Installer (formatters, linters)
      -- ===========================================================================
      local ensure_installed = vim.tbl_keys(opts.servers or {})
      vim.list_extend(ensure_installed, opts.ensure_installed or {})
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      -- ===========================================================================
      -- Configure LSP Servers (Neovim 0.11+ style)
      -- ===========================================================================
      for server_name, server_config in pairs(opts.servers) do
        -- Merge capabilities
        local config = vim.tbl_deep_extend('force', {
          capabilities = vim.tbl_deep_extend('force', {}, capabilities, server_config.capabilities or {}),
        }, server_config)

        -- Handle per-server on_attach
        if server_config.on_attach then
          local original_on_attach = server_config.on_attach
          config.on_attach = function(client, bufnr)
            original_on_attach(client, bufnr)
          end
        end

        -- Register with vim.lsp.config (Neovim 0.11+)
        vim.lsp.config[server_name] = config
      end

      -- Enable all configured servers
      vim.lsp.enable(vim.tbl_keys(opts.servers))

      -- ===========================================================================
      -- Mason-LSPConfig (bridges Mason to lspconfig)
      -- ===========================================================================
      require('mason-lspconfig').setup {
        ensure_installed = {},
        automatic_installation = false,
      }
    end,
  },
}

