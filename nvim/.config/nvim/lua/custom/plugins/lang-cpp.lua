return {
  -- clangd_extensions: VSCode-parity for C/C++
  -- Provides: AST viewer, inlay type hints, header<->source switch, type hierarchy, symbol info
  {
    'p00f/clangd_extensions.nvim',
    lazy = false, -- Load immediately to allow background indexing detection
    dependencies = {
      'saghen/blink.cmp',
    },
    config = function()
      local capabilities = require('blink.cmp').get_lsp_capabilities()
      -- clangd requires utf-16 offset encoding; without this it emits a warning on every attach
      capabilities.offsetEncoding = { 'utf-16' }

      -- Configure clangd via Neovim 0.11+ native LSP config
      -- No --compile-commands-dir: clangd walks up the tree automatically, so CMake,
      -- Make, Bazel, and hand-placed compile_commands.json all work without config.
      vim.lsp.config['clangd'] = {
        cmd = {
          'clangd',
          '--background-index',
          '--background-index-priority=normal',
          '--clang-tidy',
          '--all-scopes-completion',
          '--completion-style=detailed',
          '--header-insertion=iwyu',
          '--pch-storage=memory',
          '--function-arg-placeholders',
          '--cross-file-rename',
          '--fallback-style=llvm',
        },
        capabilities = capabilities,
        init_options = {
          usePlaceholders = true,
          completeUnimported = true,
          clangdFileStatus = true,
        },
      }
      vim.lsp.enable 'clangd'

      -- Background indexing trigger:
      -- If we're in a C/C++ project root, trigger clangd immediately to start background indexing
      -- even if no C/C++ file is open yet.
      local function trigger_background_indexing()
        local root_files = { 'compile_commands.json', 'CMakeLists.txt', '.clangd', 'Makefile' }
        local found = vim.fs.find(root_files, { upward = true, stop = vim.uv.os_homedir() })
        if #found > 0 then
          vim.schedule(function()
            -- Check if clangd is already running
            local clients = vim.lsp.get_clients { name = 'clangd' }
            if #clients == 0 then
              -- Create a hidden dummy buffer to trigger the FileType/LspAttach sequence.
              -- We keep it alive until a real C/C++ file is opened to ensure the server stays running.
              local indexing_buf = vim.api.nvim_create_buf(false, true)
              vim.api.nvim_set_option_value('filetype', 'cpp', { buf = indexing_buf })

              -- Clean up the dummy buffer when a real C file is opened
              vim.api.nvim_create_autocmd('LspAttach', {
                callback = function(args)
                  local client = vim.lsp.get_client_by_id(args.data.client_id)
                  if client and client.name == 'clangd' and args.buf ~= indexing_buf then
                    if indexing_buf and vim.api.nvim_buf_is_valid(indexing_buf) then
                      vim.api.nvim_buf_delete(indexing_buf, { force = true })
                      indexing_buf = nil
                    end
                    return true -- stop autocmd
                  end
                end,
              })
            end
          end)
        end
      end

      trigger_background_indexing()

      -- Configure clangd_extensions (AST viewer, inlay hints, commands)
      require('clangd_extensions').setup {
        ast = {
          role_icons = {
            type = '  ',
            declaration = '  ',
            expression = '  ',
            specifier = '  ',
            statement = '  ',
            ['template argument'] = '  ',
          },
          kind_icons = {
            Compound = '  ',
            Recovery = '  ',
            TranslationUnit = '  ',
            PackExpansion = '  ',
            TemplateTypeParm = '  ',
            TemplateTemplateParm = '  ',
            TemplateParamObject = '  ',
          },
          highlights = { detail = 'Comment' },
        },
        memory_usage = { border = 'rounded' },
        symbol_info = { border = 'rounded' },
      }

      -- Clangd-specific buffer-local keymaps
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('lang-cpp-lsp-attach', { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= 'clangd' then
            return
          end
          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = args.buf, desc = 'C/C++: ' .. desc })
          end
          map('<A-o>', '<cmd>ClangdSwitchSourceHeader<cr>', 'Switch Header/Source')
          map('<leader>cK', '<cmd>ClangdAST<cr>', 'AST Viewer')
          map('<leader>cM', '<cmd>ClangdMemoryUsage<cr>', 'Memory Usage')
          map('<leader>cH', '<cmd>ClangdTypeHierarchy<cr>', 'Type Hierarchy')
          map('<leader>cS', '<cmd>ClangdSymbolInfo<cr>', 'Symbol Info')
        end,
      })
    end,
  },

  -- cmake-tools: CMake project management
  -- Detects CMakeLists.txt automatically. Passes -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
  -- so clangd gets a compile_commands.json without manual steps.
  -- Stays dormant on non-CMake projects (Make, Bazel, plain compile_commands.json).
  {
    'Civitasv/cmake-tools.nvim',
    lazy = false,
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      cmake_command = 'cmake',
      cmake_build_directory = 'build',
      cmake_generate_options = { '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON' },
      cmake_soft_link_compile_commands = true,
      cmake_build_options = {},
      cmake_console_size = 10,
      cmake_show_console = 'always',
      cmake_dap_configuration = {
        name = 'cpp',
        type = 'codelldb',
        request = 'launch',
      },
      cmake_executor = { name = 'quickfix', opts = {} },
      cmake_runner = { name = 'terminal', opts = {} },
    },
    keys = {
      { '<leader>mg', '<cmd>CMakeGenerate<cr>', desc = 'CMake: Generate' },
      { '<leader>mb', '<cmd>CMakeBuild<cr>', desc = 'CMake: Build' },
      { '<leader>mr', '<cmd>CMakeRun<cr>', desc = 'CMake: Run' },
      { '<leader>md', '<cmd>CMakeDebug<cr>', desc = 'CMake: Debug' },
      { '<leader>mc', '<cmd>CMakeSelectBuildType<cr>', desc = 'CMake: Select Build Type' },
      { '<leader>mt', '<cmd>CMakeSelectBuildTarget<cr>', desc = 'CMake: Select Build Target' },
      { '<leader>mx', '<cmd>CMakeClose<cr>', desc = 'CMake: Close' },
      { '<leader>mC', '<cmd>CMakeClean<cr>', desc = 'CMake: Clean' },
    },
  },
}
