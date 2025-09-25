return {
  -- clangd_extensions: VSCode-parity for C/C++
  -- Provides: AST viewer, inlay type hints, header<->source switch, type hierarchy, symbol info
  {
    'p00f/clangd_extensions.nvim',
    ft = { 'c', 'cpp', 'objc', 'objcpp', 'cuda', 'proto' },
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
    ft = { 'cmake', 'c', 'cpp', 'objc', 'objcpp' },
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
