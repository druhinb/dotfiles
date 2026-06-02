# C/C++ and Java LSP Rearchitecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace broken C/C++ and Java LSP setups with self-contained language plugin files that give full VSCode-extension parity out of the box.

**Architecture:** Remove `clangd` from the central `servers` table in `lspconfig.lua` and create `lua/custom/plugins/lang-cpp.lua` (clangd + clangd_extensions + cmake-tools) and `lua/custom/plugins/lang-java.lua` (nvim-jdtls with per-project workspaces, DAP, and test bundles). Java LSP was never actually running; C/C++ LSP runs but without extensions, and its debugger is broken.

**Tech Stack:** clangd, p00f/clangd_extensions.nvim, Civitasv/cmake-tools.nvim, codelldb (DAP), mfussenegger/nvim-jdtls, mason-org/mason.nvim, saghen/blink.cmp, mfussenegger/nvim-dap

---

## File Map

| File | Action | What changes |
|---|---|---|
| `lua/kickstart/plugins/lspconfig.lua` | Modify | Remove `clangd` block from `servers`; add `clangd`, `jdtls`, `java-debug-adapter`, `java-test`, `google-java-format` to `ensure_installed` |
| `lua/kickstart/plugins/debug.lua` | Modify | Fix empty `extension_path` for codelldb; add `liblldb_path` to adapter args |
| `lua/kickstart/plugins/conform.lua` | Modify | Add `java = { 'google-java-format' }` to `formatters_by_ft` |
| `lua/kickstart/plugins/which-key.lua` | Modify | Register `<leader>m` group as `cmake` |
| `lua/custom/plugins/lang-cpp.lua` | **Create** | clangd config + clangd_extensions setup + cmake-tools |
| `lua/custom/plugins/lang-java.lua` | **Create** | nvim-jdtls with per-project workspaces, DAP bundles, test runner, keymaps |

---

## Task 1: Remove clangd from lspconfig.lua and update Mason tools

**Files:**
- Modify: `lua/kickstart/plugins/lspconfig.lua`

- [ ] **Step 1: Remove the clangd block from the `servers` table**

  In `lspconfig.lua`, find and delete the entire `clangd` entry including its comment header. The section to remove is:

  ```lua
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
  ```

  Replace the section header comment with a new one covering only the remaining systems-lang entries:

  ```lua
    -- ===========================================================================
    -- Systems Programming
    -- ===========================================================================
    rust_analyzer = {
  ```

  (i.e., the clangd block is gone; rust_analyzer and asm_lsp remain unchanged)

- [ ] **Step 2: Add Mason ensure_installed entries**

  In `lspconfig.lua`, find the `ensure_installed` list (inside the `opts` function). Add these entries:

  ```lua
          -- C/C++ (LSP managed separately in lang-cpp.lua)
          'clangd',
  ```

  after `'cpplint'`, and add at the end of the list:

  ```lua
          -- Java (LSP managed separately in lang-java.lua)
          'jdtls',
          'java-debug-adapter',
          'java-test',
          'google-java-format',
  ```

- [ ] **Step 3: Verify clangd is decoupled**

  Open Neovim, then open any `.c` file. Run:
  ```
  :lua vim.print(vim.lsp.get_clients({ bufnr = 0 }))
  ```
  Expected: empty table `{}` — clangd is not yet started (lang-cpp.lua doesn't exist yet).
  This confirms the servers table no longer auto-starts clangd.

- [ ] **Step 4: Commit**

  ```bash
  git add lua/kickstart/plugins/lspconfig.lua
  git commit -m "refactor: remove clangd from central servers table, add java/clangd mason tools"
  ```

---

## Task 2: Fix codelldb debugger path in debug.lua

**Files:**
- Modify: `lua/kickstart/plugins/debug.lua` (around line 517)

- [ ] **Step 1: Fix the extension_path and add liblldb**

  Find the `setup_codelldb` function. The current broken code:

  ```lua
      local codelldb = mason_registry.get_package 'codelldb'
      local extension_path = '' --codelldb:get_install_handle() .. '/extension/'
      local codelldb_path = extension_path .. 'adapter/codelldb'
  ```

  Replace with:

  ```lua
      local codelldb = mason_registry.get_package 'codelldb'
      local extension_path = codelldb:get_install_path() .. '/extension/'
      local codelldb_path = extension_path .. 'adapter/codelldb'
      local liblldb_path = extension_path .. 'lldb/lib/liblldb' .. (vim.fn.has 'mac' == 1 and '.dylib' or '.so')
  ```

- [ ] **Step 2: Pass liblldb to the adapter executable**

  Find the `dap.adapters.codelldb` assignment immediately after. Current:

  ```lua
        dap.adapters.codelldb = {
          type = 'server',
          port = '${port}',
          executable = {
            command = codelldb_path,
            args = { '--port', '${port}' },
          },
        }
  ```

  Replace with:

  ```lua
        dap.adapters.codelldb = {
          type = 'server',
          port = '${port}',
          executable = {
            command = codelldb_path,
            args = { '--port', '${port}', '--liblldb', liblldb_path },
          },
        }
  ```

- [ ] **Step 3: Verify codelldb path resolves**

  Open Neovim and run:
  ```
  :lua local r = require('mason-registry'); local c = r.get_package('codelldb'); print(c:get_install_path() .. '/extension/adapter/codelldb')
  ```
  Expected: a real path like `~/.local/share/nvim/mason/packages/codelldb/extension/adapter/codelldb`

  If codelldb isn't installed yet:
  ```
  :MasonInstall codelldb
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add lua/kickstart/plugins/debug.lua
  git commit -m "fix: correct codelldb extension_path using get_install_path(), add liblldb arg"
  ```

---

## Task 3: Register cmake which-key group

**Files:**
- Modify: `lua/kickstart/plugins/which-key.lua`

- [ ] **Step 1: Add `<leader>m` group to the spec**

  In `which-key.lua`, find the leader groups section (around line 69). Add after `{ '<leader>l', ... }`:

  ```lua
          { '<leader>m', group = 'cmake', icon = { icon = '󰄉', color = 'cyan' } },
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add lua/kickstart/plugins/which-key.lua
  git commit -m "feat: register <leader>m as cmake which-key group"
  ```

---

## Task 4: Create lang-cpp.lua

**Files:**
- Create: `lua/custom/plugins/lang-cpp.lua`

- [ ] **Step 1: Create the file**

  Create `lua/custom/plugins/lang-cpp.lua` with this content:

  ```lua
  return {
    -- clangd_extensions: VSCode-parity for C/C++
    -- Provides: AST viewer, inlay type hints, header<->source switch, type hierarchy, symbol info
    {
      'p00f/clangd_extensions.nvim',
      ft = { 'c', 'cpp', 'objc', 'objcpp', 'cuda', 'proto' },
      dependencies = {
        'neovim/nvim-lspconfig',
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
          inlay_hints = {
            inline = true,
            only_current_line = false,
            show_parameter_hints = true,
            parameter_hints_prefix = ' <- ',
            other_hints_prefix = ' => ',
            highlight = 'Comment',
            priority = 100,
          },
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
  ```

- [ ] **Step 2: Install the new plugin**

  Open Neovim and run:
  ```
  :Lazy sync
  ```
  Wait for `clangd_extensions` and `cmake-tools` to install. Then:
  ```
  :MasonInstall clangd
  ```
  (if not already installed)

- [ ] **Step 3: Verify clangd attaches**

  Open any `.c` or `.cpp` file, then run:
  ```
  :lua vim.print(vim.lsp.get_clients({ bufnr = 0 }))
  ```
  Expected: a table containing a client with `name = "clangd"`.

  Also verify the keymaps by pressing `<A-o>` in a C file that has a corresponding header — it should switch files. If there's no header, it will show "no corresponding file found" which is still correct behavior.

- [ ] **Step 4: Verify clangd inlay hints**

  Open a C++ file with function calls. Run:
  ```
  :lua vim.lsp.inlay_hint.enable(true)
  ```
  Expected: parameter name hints appear inline at call sites.

- [ ] **Step 5: Commit**

  ```bash
  git add lua/custom/plugins/lang-cpp.lua
  git commit -m "feat: add lang-cpp.lua with clangd_extensions and cmake-tools"
  ```

---

## Task 5: Add Java formatter to conform.lua

**Files:**
- Modify: `lua/kickstart/plugins/conform.lua`

- [ ] **Step 1: Add java formatter**

  In `conform.lua`, find the `formatters_by_ft` table. Add after the `rust` entry:

  ```lua
          -- Java
          java = { 'google-java-format' },
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add lua/kickstart/plugins/conform.lua
  git commit -m "feat: add google-java-format for Java files"
  ```

---

## Task 6: Create lang-java.lua

**Files:**
- Create: `lua/custom/plugins/lang-java.lua`

- [ ] **Step 1: Install Mason packages first**

  Open Neovim and run:
  ```
  :MasonInstall jdtls java-debug-adapter java-test
  ```
  Wait for all three to finish. These are large downloads (~200MB total). Verify with:
  ```
  :Mason
  ```
  All three should show as installed.

- [ ] **Step 2: Create the file**

  Create `lua/custom/plugins/lang-java.lua` with this content:

  ```lua
  return {
    {
      'mfussenegger/nvim-jdtls',
      ft = 'java',
      dependencies = {
        'mason-org/mason.nvim',
        'mfussenegger/nvim-dap',
        'saghen/blink.cmp',
      },
      config = function()
        local function get_jdtls_config()
          local mason_registry = require 'mason-registry'

          if not mason_registry.is_installed 'jdtls' then
            vim.notify('jdtls not installed — run :MasonInstall jdtls', vim.log.levels.WARN)
            return nil
          end

          local jdtls_path = mason_registry.get_package('jdtls'):get_install_path()

          -- Launcher jar (glob since version is in the filename)
          local launcher_jars = vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar', true, true)
          if #launcher_jars == 0 then
            vim.notify('jdtls launcher jar not found in ' .. jdtls_path, vim.log.levels.ERROR)
            return nil
          end
          local launcher_jar = launcher_jars[1]

          -- OS-specific configuration directory
          local os_config
          if vim.fn.has 'mac' == 1 then
            os_config = 'mac'
          elseif vim.fn.has 'unix' == 1 then
            os_config = 'linux'
          else
            os_config = 'win'
          end
          local config_dir = jdtls_path .. '/config_' .. os_config

          -- Project root: use jdtls's own finder so it searches upward from the
          -- current buffer file, not from cwd (cwd breaks nested project layouts)
          local root_dir = require('jdtls.setup').find_root {
            'pom.xml', 'build.gradle', 'build.gradle.kts', 'mvnw', 'gradlew', '.git',
          }
          if not root_dir then
            root_dir = vim.fn.getcwd()
          end

          -- Unique workspace per project: name + short hash prevents collisions
          -- when two projects share a directory name
          local project_name = vim.fn.fnamemodify(root_dir, ':t')
          local project_hash = string.sub(vim.fn.sha256(root_dir), 1, 8)
          local workspace_dir = vim.fn.stdpath 'cache' .. '/jdtls/workspaces/' .. project_name .. '-' .. project_hash

          -- JVM flags tuned for large codebases
          local jvm_args = {
            '-XX:+UseParallelGC',
            '-XX:GCTimeRatio=4',
            '-XX:AdaptiveSizePolicyWeight=90',
            '-Dsun.zip.disableMemoryMapping=true',
            '-Xmx2G',
            '-Xms256m',
          }

          -- Lombok: check fixed known locations only (not the Maven cache)
          for _, lombok_path in ipairs {
            root_dir .. '/lombok.jar',
            root_dir .. '/lib/lombok.jar',
            root_dir .. '/.mvn/lombok.jar',
          } do
            if vim.fn.filereadable(lombok_path) == 1 then
              table.insert(jvm_args, '-javaagent:' .. lombok_path)
              break
            end
          end

          -- Java executable: prefer JAVA_HOME, fall back to PATH
          local java_home = os.getenv 'JAVA_HOME'
          local java_cmd = java_home and (java_home .. '/bin/java') or 'java'

          -- Build the full command array
          local cmd = {
            java_cmd,
            '-Declipse.application=org.eclipse.jdt.ls.core.id1',
            '-Dosgi.bundles.defaultStartLevel=4',
            '-Declipse.product=org.eclipse.jdt.ls.core.product',
            '-Dlog.protocol=true',
            '-Dlog.level=ALL',
          }
          vim.list_extend(cmd, jvm_args)
          vim.list_extend(cmd, {
            '-jar', launcher_jar,
            '-configuration', config_dir,
            '-data', workspace_dir,
          })

          -- DAP and test bundles
          local bundles = {}

          if mason_registry.is_installed 'java-debug-adapter' then
            local debug_path = mason_registry.get_package('java-debug-adapter'):get_install_path()
            local debug_jars = vim.fn.glob(
              debug_path .. '/extension/server/com.microsoft.java.debug.plugin-*.jar',
              true,
              true
            )
            for _, jar in ipairs(debug_jars) do
              table.insert(bundles, jar)
            end
          end

          if mason_registry.is_installed 'java-test' then
            local test_path = mason_registry.get_package('java-test'):get_install_path()
            for _, jar in ipairs(vim.fn.glob(test_path .. '/extension/server/*.jar', true, true)) do
              table.insert(bundles, jar)
            end
          end

          local capabilities = require('blink.cmp').get_lsp_capabilities()

          return {
            cmd = cmd,
            root_dir = root_dir,
            capabilities = capabilities,
            settings = {
              java = {
                inlayHints = {
                  parameterNames = { enabled = 'all' },
                },
                format = {
                  enabled = true,
                  settings = { profile = 'GoogleStyle' },
                },
                completion = {
                  favoriteStaticMembers = {
                    'org.junit.Assert.*',
                    'org.junit.jupiter.api.Assertions.*',
                    'org.mockito.Mockito.*',
                    'org.mockito.ArgumentMatchers.*',
                  },
                  importOrder = { 'java', 'javax', 'com', 'org' },
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
            init_options = {
              bundles = bundles,
            },
            on_attach = function(client, bufnr)
              -- Register DAP main class configs (enables F5 debug for Java applications)
              if #bundles > 0 then
                require('jdtls.dap').setup_dap_main_class_configs()
              end

              local map = function(keys, func, desc, mode)
                mode = mode or 'n'
                vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = 'Java: ' .. desc })
              end

              map('<leader>co', function() require('jdtls').organize_imports() end, 'Organize Imports')
              map('<leader>cv', function() require('jdtls').extract_variable() end, 'Extract Variable')
              map('<leader>cV', function() require('jdtls').extract_variable(true) end, 'Extract Variable (all occurrences)')
              map('<leader>cm', function() require('jdtls').extract_method() end, 'Extract Method', { 'n', 'v' })
              map('<leader>cC', function() require('jdtls').extract_constant() end, 'Extract Constant')
              map('<leader>cu', function() require('jdtls').update_project_config() end, 'Update Project Config')

              if mason_registry.is_installed 'java-test' then
                map('<leader>ct', function() require('jdtls').test_nearest_method() end, 'Run Nearest Test')
                map('<leader>cT', function() require('jdtls').test_class() end, 'Run Test Class')
              end
            end,
          }
        end

        local function start_jdtls()
          local cfg = get_jdtls_config()
          if cfg then
            require('jdtls').start_or_attach(cfg)
          end
        end

        -- Handle the buffer that triggered this plugin load
        vim.schedule(start_jdtls)

        -- Handle all future Java buffers
        vim.api.nvim_create_autocmd('FileType', {
          pattern = 'java',
          callback = start_jdtls,
        })
      end,
    },
  }
  ```

- [ ] **Step 3: Verify jdtls starts**

  Open any `.java` file. jdtls takes 10–30 seconds to start on first run (it indexes the project). Watch progress with:
  ```
  :lua vim.print(vim.lsp.get_clients({ bufnr = 0 }))
  ```
  Expected: a client with `name = "jdtls"`.

  Also check the fidget progress indicator (bottom-right) — it shows jdtls indexing status.

- [ ] **Step 4: Verify per-project workspace isolation**

  Open a `.java` file from project A, check the workspace dir used:
  ```
  :lua vim.print(vim.lsp.get_clients({ bufnr = 0 })[1].config.cmd)
  ```
  The `-data` argument in the printed cmd should be `~/.cache/nvim/jdtls/workspaces/<project-name>-<hash>`.

  Open a `.java` file from a different project — the `-data` path should be different.

- [ ] **Step 5: Verify Java keymaps**

  In a Java file with imports, press `<leader>co` — imports should be reorganized.
  In a Java file, position cursor on an expression and press `<leader>cv` — should prompt for variable name and extract it.

- [ ] **Step 6: Commit**

  ```bash
  git add lua/custom/plugins/lang-java.lua
  git commit -m "feat: add lang-java.lua with nvim-jdtls, per-project workspaces, DAP, and test runner"
  ```

---

## Self-check after all tasks

Run in Neovim after all tasks are complete:

```
:checkhealth lsp
```

For C/C++: clangd should be listed as attached with no errors.
For Java: jdtls should be listed with no errors.

```
:Lazy
```

`clangd_extensions`, `cmake-tools`, `nvim-jdtls` should all appear as installed.

```
:Mason
```

`clangd`, `jdtls`, `java-debug-adapter`, `java-test`, `google-java-format`, `codelldb` should all show as installed (green checkmark).
