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

        local jdtls_pkg = mason_registry.get_package 'jdtls'
        if not jdtls_pkg then
          vim.notify('jdtls not found in Mason registry — try restarting Neovim', vim.log.levels.WARN)
          return nil
        end
        local jdtls_path = jdtls_pkg:get_install_path()

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
          local debug_pkg = mason_registry.get_package 'java-debug-adapter'
          if debug_pkg then
            local debug_jars = vim.fn.glob(
              debug_pkg:get_install_path() .. '/extension/server/com.microsoft.java.debug.plugin-*.jar',
              true,
              true
            )
            for _, jar in ipairs(debug_jars) do
              table.insert(bundles, jar)
            end
          end
        end

        if mason_registry.is_installed 'java-test' then
          local test_pkg = mason_registry.get_package 'java-test'
          if test_pkg then
            for _, jar in ipairs(vim.fn.glob(test_pkg:get_install_path() .. '/extension/server/*.jar', true, true)) do
              table.insert(bundles, jar)
            end
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
        group = vim.api.nvim_create_augroup('lang-java-jdtls', { clear = true }),
        pattern = 'java',
        callback = start_jdtls,
      })
    end,
  },
}
