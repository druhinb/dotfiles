-- debug.lua
--
-- DAP (Debug Adapter Protocol) configuration for multiple languages:
-- Go, Python, C/C++, Rust, JavaScript/TypeScript

return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'nvim-neotest/nvim-nio',
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',
    'leoluz/nvim-dap-go',
    'mfussenegger/nvim-dap-python',
    'theHamsta/nvim-dap-virtual-text',
  },
  keys = {
    -- Breakpoints
    { '<leader>db', function() require('dap').toggle_breakpoint() end,                                          desc = 'Debug: Toggle Breakpoint' },
    { '<leader>dB', function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end,        desc = 'Debug: Conditional Breakpoint' },
    { '<leader>dl', function() require('dap').set_breakpoint(nil, nil, vim.fn.input 'Log point message: ') end, desc = 'Debug: Log Point' },
    {
      '<leader>dL',
      function()
        require('dap').list_breakpoints()
        vim.cmd('copen')
      end,
      desc = 'Debug: List Breakpoints'
    },
    { '<leader>dx', function() require('dap').clear_breakpoints() end,                      desc = 'Debug: Clear All Breakpoints' },
    -- Session control
    { '<leader>dc', function() require('dap').continue() end,                               desc = 'Debug: Continue/Start' },
    { '<leader>dr', function() require('dap').run_last() end,                               desc = 'Debug: Run Last' },
    { '<leader>dC', function() require('dap').run_to_cursor() end,                          desc = 'Debug: Run to Cursor' },
    { '<leader>dp', function() require('dap').pause() end,                                  desc = 'Debug: Pause' },
    { '<leader>dt', function() require('dap').terminate() end,                              desc = 'Debug: Terminate' },
    { '<leader>dq', function() require('dap').close() end,                                  desc = 'Debug: Quit Session' },
    { '<leader>dD', function() require('dap').disconnect({ terminateDebuggee = true }) end, desc = 'Debug: Disconnect' },
    -- Stepping
    { '<leader>di', function() require('dap').step_into() end,                              desc = 'Debug: Step Into' },
    { '<leader>do', function() require('dap').step_over() end,                              desc = 'Debug: Step Over' },
    { '<leader>dO', function() require('dap').step_out() end,                               desc = 'Debug: Step Out' },
    { '<leader>dI', function() require('dap').step_into({ askForTargets = true }) end,      desc = 'Debug: Force Step Into' },
    -- Stack frame navigation
    { '<leader>dj', function() require('dap').down() end,                                   desc = 'Debug: Down Stack Frame' },
    { '<leader>dk', function() require('dap').up() end,                                     desc = 'Debug: Up Stack Frame' },
    { '<leader>df', function() require('dap').focus_frame() end,                            desc = 'Debug: Focus Current Frame' },
    {
      '<leader>ds',
      function()
        local w = require('dap.ui.widgets')
        w.centered_float(w.scopes)
      end,
      desc = 'Debug: Show Scopes (float)'
    },
    {
      '<leader>dS',
      function()
        local w = require('dap.ui.widgets')
        w.centered_float(w.frames)
      end,
      desc = 'Debug: Show Stack Frames (float)'
    },
    {
      '<leader>dT',
      function()
        local w = require('dap.ui.widgets')
        w.centered_float(w.threads)
      end,
      desc = 'Debug: Show Threads (float)'
    },
    -- UI
    { '<leader>du', function() require('dapui').toggle() end,                                   desc = 'Debug: Toggle UI' },
    { '<leader>de', function() require('dapui').eval() end,                                     mode = { 'n', 'v' },                   desc = 'Debug: Eval Expression' },
    { '<leader>dE', function() require('dapui').eval(vim.fn.input('Expression: ')) end,         desc = 'Debug: Eval Input' },
    { '<leader>dh', function() require('dap.ui.widgets').hover() end,                           mode = { 'n', 'v' },                   desc = 'Debug: Hover Variables' },
    { '<leader>dw', function() require('dapui').float_element('watches', { enter = true }) end, desc = 'Debug: Watches' },
    { '<leader>dR', function() require('dap').repl.toggle() end,                                desc = 'Debug: Toggle REPL' },
    -- Function keys (JetBrains-style)
    { '<F5>',       function() require('dap').continue() end,                                   desc = 'Debug: Continue' },
    { '<S-F5>',     function() require('dap').terminate() end,                                  desc = 'Debug: Stop' },
    { '<C-F5>',     function() require('dap').run_last() end,                                   desc = 'Debug: Restart' },
    { '<F7>',       function() require('dap').step_into() end,                                  desc = 'Debug: Step Into' },
    { '<S-F7>',     function() require('dap').step_into({ askForTargets = true }) end,          desc = 'Debug: Smart Step Into' },
    { '<F8>',       function() require('dap').step_over() end,                                  desc = 'Debug: Step Over' },
    { '<S-F8>',     function() require('dap').step_out() end,                                   desc = 'Debug: Step Out' },
    { '<F9>',       function() require('dap').toggle_breakpoint() end,                          desc = 'Debug: Toggle Breakpoint' },
    { '<C-F8>',     function() require('dap').set_breakpoint(vim.fn.input 'Condition: ') end,   desc = 'Debug: Conditional Breakpoint' },
    { '<A-F9>',     function() require('dap').run_to_cursor() end,                              desc = 'Debug: Run to Cursor' },
    -- VS Code / legacy function keys
    { '<F10>',      function() require('dap').step_over() end,                                  desc = 'Debug: Step Over' },
    { '<F11>',      function() require('dap').step_into() end,                                  desc = 'Debug: Step Into' },
    { '<F12>',      function() require('dap').step_out() end,                                   desc = 'Debug: Step Out' },
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    require('mason-nvim-dap').setup {
      automatic_installation = true,
      handlers = {},
      ensure_installed = {
        'delve',            -- Go
        'debugpy',          -- Python
        'codelldb',         -- C/C++/Rust
        'js-debug-adapter', -- JavaScript/TypeScript
      },
    }

    -- DAP UI setup (JetBrains-inspired layout)
    dapui.setup {
      icons = { expanded = '▾', collapsed = '▸', current_frame = '>' },
      mappings = {
        expand = { '<CR>', '<2-LeftMouse>' },
        open = 'o',
        remove = 'd',
        edit = 'e',
        repl = 'r',
        toggle = 't',
      },
      element_mappings = {},
      expand_lines = true,
      force_buffers = true,
      floating = {
        max_height = 0.8,
        max_width = 0.8,
        border = 'rounded',
        mappings = { close = { 'q', '<Esc>' } },
      },
      controls = {
        enabled = true,
        element = 'repl', -- Show controls in stacks panel (more visible)
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '↓',
          step_over = '→',
          step_out = '↑',
          step_back = '←',
          run_last = '⟲',
          terminate = '■',
          disconnect = '⊘',
        },
      },
      render = {
        max_type_length = nil,
        max_value_lines = 100,
        indent = 1,
      },
      layouts = {
        -- Left sidebar (like JetBrains Debug tool window)
        {
          elements = {
            { id = 'scopes',      size = 0.35 },
            { id = 'watches',     size = 0.25 },
            { id = 'stacks',      size = 0.25 },
            { id = 'breakpoints', size = 0.15 },
          },
          size = 50,
          position = 'left',
        },
        -- Bottom panel (Console + REPL like JetBrains)
        {
          elements = {
            { id = 'console', size = 0.6 },
            { id = 'repl',    size = 0.4 },
          },
          size = 12,
          position = 'bottom',
        },
      },
    }

    -- Virtual text for variable values (JetBrains-style inline values)
    require('nvim-dap-virtual-text').setup {
      enabled = true,
      enabled_commands = true,
      highlight_changed_variables = true,
      highlight_new_as_changed = true,
      show_stop_reason = true,
      commented = false,
      only_first_definition = true,
      all_references = true,
      clear_on_continue = false,
      virt_text_pos = 'eol',
      all_frames = false,
      virt_lines = false,
      virt_text_win_col = nil,
      display_callback = function(variable, buf, stackframe, node, options)
        if options.virt_text_pos == 'inline' then
          return ' = ' .. variable.value:gsub('%s+', ' ')
        else
          return ' -> ' .. variable.name .. ' = ' .. variable.value:gsub('%s+', ' ')
        end
      end,
    }

    -- Breakpoint icons
    vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    local icons = vim.g.have_nerd_font
        and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
        or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    for type, icon in pairs(icons) do
      local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
      vim.fn.sign_define('Dap' .. type, { text = icon, texthl = hl, numhl = hl })
    end

    -- Auto open/close UI with session management
    dap.listeners.after.event_initialized['dapui_config'] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated['dapui_config'] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited['dapui_config'] = function()
      dapui.close()
    end

    -- Exception breakpoints helper (JetBrains-style)
    -- Use: :lua SetExceptionBreakpoints('all') for Python
    -- Use: :lua SetExceptionBreakpoints('uncaught') for JS
    _G.SetExceptionBreakpoints = function(filter)
      local filters = filter and { filter } or { 'raised', 'uncaught' }
      dap.set_exception_breakpoints(filters)
      vim.notify('Exception breakpoints set: ' .. table.concat(filters, ', '), vim.log.levels.INFO)
    end

    -- Quick commands for debugging
    vim.api.nvim_create_user_command('DapExceptionBreakpoints', function(opts)
      local filter = opts.args ~= '' and opts.args or nil
      _G.SetExceptionBreakpoints(filter)
    end, {
      nargs = '?',
      complete = function()
        return { 'all', 'raised', 'uncaught', 'userUnhandled' }
      end,
      desc = 'Set exception breakpoints',
    })

    vim.api.nvim_create_user_command('DapEval', function(opts)
      if opts.args ~= '' then
        require('dapui').eval(opts.args)
      else
        require('dapui').eval()
      end
    end, { nargs = '?', desc = 'Evaluate expression' })

    vim.api.nvim_create_user_command('DapCondition', function()
      require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))
    end, { desc = 'Set conditional breakpoint' })

    vim.api.nvim_create_user_command('DapLogPoint', function()
      require('dap').set_breakpoint(nil, nil, vim.fn.input('Log message: '))
    end, { desc = 'Set log point' })

    vim.api.nvim_create_user_command('DapHitCondition', function()
      require('dap').set_breakpoint(nil, vim.fn.input('Hit condition (e.g., >5, ==10): '))
    end, { desc = 'Set hit count breakpoint' })

    -------------------------
    -- Language-specific setup
    -------------------------

    -- Go
    require('dap-go').setup {
      delve = { detached = vim.fn.has 'win32' == 0 },
    }

    -- Python
    require('dap-python').setup 'python'

    table.insert(dap.configurations.python, {
      type = 'python',
      request = 'launch',
      name = 'Launch with arguments',
      program = '${file}',
      args = function()
        return vim.split(vim.fn.input('Arguments: '), ' ')
      end,
      console = 'integratedTerminal',
    })
    table.insert(dap.configurations.python, {
      type = 'python',
      request = 'launch',
      name = 'Debug pytest',
      module = 'pytest',
      args = { '${file}', '-v' },
      console = 'integratedTerminal',
    })

    -- C/C++/Rust (codelldb)
    local mason_registry = require 'mason-registry'
    local function setup_codelldb()
      if not mason_registry.is_installed 'codelldb' then
        return
      end

      local extension_path = vim.fn.stdpath 'data' .. '/mason/packages/codelldb/extension/'
      local codelldb_path = extension_path .. 'adapter/codelldb'
      local liblldb_path = extension_path .. 'lldb/lib/liblldb' .. (vim.fn.has 'mac' == 1 and '.dylib' or '.so')

      dap.adapters.codelldb = {
        type = 'server',
        port = '${port}',
        executable = {
          command = codelldb_path,
          args = { '--port', '${port}', '--liblldb', liblldb_path },
        },
      }

      local function find_executable()
        local cwd = vim.fn.getcwd()
        for _, dir in ipairs { 'build', 'cmake-build-debug', 'target/debug', 'out', 'bin', '.' } do
          local path = cwd .. '/' .. dir
          if vim.fn.isdirectory(path) == 1 then
            for _, file in ipairs(vim.fn.globpath(path, '*', false, true)) do
              if vim.fn.executable(file) == 1 and not file:match '%.%w+$' then
                return file
              end
            end
          end
        end
        return vim.fn.input('Path to executable: ', cwd .. '/', 'file')
      end

      local codelldb_config = {
        {
          name = 'Launch file',
          type = 'codelldb',
          request = 'launch',
          program = find_executable,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
        },
        {
          name = 'Attach to process',
          type = 'codelldb',
          request = 'attach',
          pid = require('dap.utils').pick_process,
        },
      }
      dap.configurations.rust = codelldb_config
      dap.configurations.c = codelldb_config
      dap.configurations.cpp = codelldb_config
    end

    if mason_registry.is_installed 'codelldb' then
      setup_codelldb()
    else
      mason_registry.refresh(function()
        if mason_registry.is_installed 'codelldb' then
          setup_codelldb()
        end
      end)
    end

    -- JavaScript/TypeScript (explicit configurations)
    dap.adapters['pwa-node'] = {
      type = 'server',
      host = 'localhost',
      port = '${port}',
      executable = {
        command = 'js-debug-adapter',
        args = { '${port}' },
      },
    }

    dap.adapters['pwa-chrome'] = {
      type = 'server',
      host = 'localhost',
      port = '${port}',
      executable = {
        command = 'js-debug-adapter',
        args = { '${port}' },
      },
    }

    -- Alias for convenience
    dap.adapters['node'] = dap.adapters['pwa-node']
    dap.adapters['chrome'] = dap.adapters['pwa-chrome']

    -- JavaScript configurations
    dap.configurations.javascript = {
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Launch file',
        program = '${file}',
        cwd = '${workspaceFolder}',
        sourceMaps = true,
        skipFiles = { '<node_internals>/**', 'node_modules/**' },
      },
      {
        type = 'pwa-node',
        request = 'attach',
        name = 'Attach to process',
        processId = require('dap.utils').pick_process,
        cwd = '${workspaceFolder}',
        sourceMaps = true,
      },
      {
        type = 'pwa-chrome',
        request = 'launch',
        name = 'Launch Chrome (localhost:3000)',
        url = 'http://localhost:3000',
        webRoot = '${workspaceFolder}',
        sourceMaps = true,
      },
    }

    -- TypeScript configurations
    dap.configurations.typescript = {
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Launch file',
        program = '${file}',
        cwd = '${workspaceFolder}',
        sourceMaps = true,
        skipFiles = { '<node_internals>/**', 'node_modules/**' },
        runtimeExecutable = 'npx',
        runtimeArgs = { 'ts-node' },
      },
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Launch compiled JS',
        program = '${file}',
        cwd = '${workspaceFolder}',
        sourceMaps = true,
        outFiles = { '${workspaceFolder}/dist/**/*.js' },
        skipFiles = { '<node_internals>/**', 'node_modules/**' },
      },
      {
        type = 'pwa-node',
        request = 'attach',
        name = 'Attach to process',
        processId = require('dap.utils').pick_process,
        cwd = '${workspaceFolder}',
        sourceMaps = true,
      },
      {
        type = 'pwa-chrome',
        request = 'launch',
        name = 'Launch Chrome (localhost:3000)',
        url = 'http://localhost:3000',
        webRoot = '${workspaceFolder}',
        sourceMaps = true,
      },
    }

    -- React/JSX configurations
    dap.configurations.javascriptreact = {
      {
        type = 'pwa-chrome',
        request = 'launch',
        name = 'Launch Chrome (localhost:3000)',
        url = 'http://localhost:3000',
        webRoot = '${workspaceFolder}',
        sourceMaps = true,
      },
      {
        type = 'pwa-chrome',
        request = 'launch',
        name = 'Launch Chrome (localhost:5173 - Vite)',
        url = 'http://localhost:5173',
        webRoot = '${workspaceFolder}',
        sourceMaps = true,
      },
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Launch file (Node)',
        program = '${file}',
        cwd = '${workspaceFolder}',
        sourceMaps = true,
        skipFiles = { '<node_internals>/**', 'node_modules/**' },
      },
    }

    -- TypeScript React configurations
    dap.configurations.typescriptreact = {
      {
        type = 'pwa-chrome',
        request = 'launch',
        name = 'Launch Chrome (localhost:3000)',
        url = 'http://localhost:3000',
        webRoot = '${workspaceFolder}',
        sourceMaps = true,
      },
      {
        type = 'pwa-chrome',
        request = 'launch',
        name = 'Launch Chrome (localhost:5173 - Vite)',
        url = 'http://localhost:5173',
        webRoot = '${workspaceFolder}',
        sourceMaps = true,
      },
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Launch file (ts-node)',
        program = '${file}',
        cwd = '${workspaceFolder}',
        sourceMaps = true,
        runtimeExecutable = 'npx',
        runtimeArgs = { 'ts-node' },
        skipFiles = { '<node_internals>/**', 'node_modules/**' },
      },
    }
  end,
}
