-- ============================================================================
-- Noice.nvim - Complete UI Replacement (LazyVim Style)
-- Replaces: messages, cmdline, popupmenu, notifications
-- ============================================================================
return {
  'folke/noice.nvim',
  event = 'VeryLazy',
  dependencies = {
    'MunifTanjim/nui.nvim',
    -- Notification backend (optional but recommended)
    {
      'rcarriga/nvim-notify',
      opts = {
        -- Top-right notification bubbles (LazyVim style)
        stages = 'fade_in_slide_out',
        timeout = 3000,
        max_height = function()
          return math.floor(vim.o.lines * 0.75)
        end,
        max_width = function()
          return math.floor(vim.o.columns * 0.75)
        end,
        -- Position: top_right is the LazyVim default
        top_down = true,
        render = 'compact',
        background_colour = '#000000',
        on_open = function(win)
          vim.api.nvim_win_set_config(win, { zindex = 100 })
        end,
      },
      init = function()
        -- Set as default notification handler
        vim.notify = require 'notify'
      end,
    },
  },
  -- stylua: ignore
  keys = {
    { '<S-Enter>', function() require('noice').redirect(vim.fn.getcmdline()) end, mode = 'c', desc = 'Redirect Cmdline' },
    { '<leader>snl', function() require('noice').cmd 'last' end, desc = 'Noice Last Message' },
    { '<leader>snh', function() require('noice').cmd 'history' end, desc = 'Noice History' },
    { '<leader>sna', function() require('noice').cmd 'all' end, desc = 'Noice All' },
    { '<leader>snd', function() require('noice').cmd 'dismiss' end, desc = 'Dismiss All' },
    { '<leader>snt', function() require('noice').cmd 'pick' end, desc = 'Noice Picker (Telescope/Fzf)' },
    { '<c-f>', function() if not require('noice.lsp').scroll(4) then return '<c-f>' end end, silent = true, expr = true, desc = 'Scroll Forward', mode = { 'i', 'n', 's' } },
    { '<c-b>', function() if not require('noice.lsp').scroll(-4) then return '<c-b>' end end, silent = true, expr = true, desc = 'Scroll Backward', mode = { 'i', 'n', 's' } },
  },
  opts = {
    -- Command line configuration
    cmdline = {
      enabled = true,
      view = 'cmdline_popup', -- Centered command line popup (LazyVim style)
      opts = {},
      format = {
        cmdline = { pattern = '^:', icon = '', lang = 'vim' },
        search_down = { kind = 'search', pattern = '^/', icon = ' ', lang = 'regex' },
        search_up = { kind = 'search', pattern = '^%?', icon = ' ', lang = 'regex' },
        filter = { pattern = '^:%s*!', icon = '$', lang = 'bash' },
        lua = { pattern = { '^:%s*lua%s+', '^:%s*lua%s*=%s*', '^:%s*=%s*' }, icon = '', lang = 'lua' },
        help = { pattern = '^:%s*he?l?p?%s+', icon = '󰋖' },
        input = { view = 'cmdline_input', icon = '󰥻 ' },
      },
    },
    -- Messages configuration
    messages = {
      enabled = true,
      view = 'notify',
      view_error = 'notify',
      view_warn = 'notify',
      view_history = 'messages',
      view_search = 'virtualtext', -- Virtual text for search count
    },
    -- Popup menu (wild menu, completion menu)
    popupmenu = {
      enabled = true,
      backend = 'nui',
      kind_icons = {},
    },
    -- Redirect output of commands
    redirect = {
      view = 'popup',
      filter = { event = 'msg_show' },
    },
    -- Command history
    commands = {
      history = {
        view = 'split',
        opts = { enter = true, format = 'details' },
        filter = {
          any = {
            { event = 'notify' },
            { error = true },
            { warning = true },
            { event = 'msg_show', kind = { '' } },
            { event = 'lsp', kind = 'message' },
          },
        },
      },
      last = {
        view = 'popup',
        opts = { enter = true, format = 'details' },
        filter = {
          any = {
            { event = 'notify' },
            { error = true },
            { warning = true },
            { event = 'msg_show', kind = { '' } },
            { event = 'lsp', kind = 'message' },
          },
        },
        filter_opts = { count = 1 },
      },
      errors = {
        view = 'popup',
        opts = { enter = true, format = 'details' },
        filter = { error = true },
        filter_opts = { reverse = true },
      },
      all = {
        view = 'split',
        opts = { enter = true, format = 'details' },
        filter = {},
      },
    },
    -- Notifications configuration
    notify = {
      enabled = true,
      view = 'notify',
    },
    -- LSP integration
    lsp = {
      progress = {
        enabled = true,
        format = 'lsp_progress',
        format_done = 'lsp_progress_done',
        throttle = 1000 / 30,
        view = 'mini',
      },
      override = {
        -- Override LSP markdown rendering for better formatting
        ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
        ['vim.lsp.util.stylize_markdown'] = true,
        ['cmp.entry.get_documentation'] = true,
      },
      hover = {
        enabled = true,
        silent = false,
        view = nil,
        opts = {},
      },
      signature = {
        enabled = true,
        auto_open = {
          enabled = true,
          trigger = true,
          luasnip = true,
          throttle = 50,
        },
        view = nil,
        opts = {},
      },
      message = {
        enabled = true,
        view = 'notify',
        opts = {},
      },
      documentation = {
        view = 'hover',
        opts = {
          lang = 'markdown',
          replace = true,
          render = 'plain',
          format = { '{message}' },
          win_options = { concealcursor = 'n', conceallevel = 3 },
        },
      },
    },
    -- Health check
    health = {
      checker = true,
    },
    -- Presets (LazyVim style)
    presets = {
      bottom_search = true, -- Classic bottom cmdline for search
      command_palette = true, -- Position cmdline and popupmenu together
      long_message_to_split = true, -- Long messages sent to split
      inc_rename = false, -- Enable if using inc-rename.nvim
      lsp_doc_border = true, -- Add border to hover docs and signature help
    },
    -- Throttle for better performance
    throttle = 1000 / 30,
    -- Views configuration
    views = {
      -- Centered command line popup
      cmdline_popup = {
        position = {
          row = 5,
          col = '50%',
        },
        size = {
          width = 60,
          height = 'auto',
        },
        border = {
          style = 'rounded',
          padding = { 0, 1 },
        },
        win_options = {
          winhighlight = {
            Normal = 'NormalFloat',
            FloatBorder = 'FloatBorder',
          },
        },
      },
      -- Popupmenu connected to cmdline
      popupmenu = {
        relative = 'editor',
        position = {
          row = 8,
          col = '50%',
        },
        size = {
          width = 60,
          height = 10,
        },
        border = {
          style = 'rounded',
          padding = { 0, 1 },
        },
        win_options = {
          winhighlight = {
            Normal = 'NormalFloat',
            FloatBorder = 'FloatBorder',
          },
        },
      },
      -- Mini view for LSP progress (bottom right)
      mini = {
        win_options = {
          winblend = 0,
        },
        position = {
          row = -2,
          col = '100%',
        },
      },
      -- Hover documentation
      hover = {
        border = {
          style = 'rounded',
        },
        position = { row = 2, col = 2 },
      },
    },
    -- Route configuration for different message types
    routes = {
      -- Skip "written" messages
      {
        filter = {
          event = 'msg_show',
          kind = '',
          find = 'written',
        },
        opts = { skip = true },
      },
      -- Skip search virtual text for short searches
      {
        filter = {
          event = 'msg_show',
          kind = 'search_count',
        },
        opts = { skip = true },
      },
      -- Route long messages to split
      {
        filter = {
          event = 'msg_show',
          min_height = 20,
        },
        view = 'split',
      },
    },
  },
  config = function(_, opts)
    -- PERF: Skip loading if inside a special buffer
    if vim.o.filetype == 'lazy' then
      vim.cmd [[messages clear]]
    end
    require('noice').setup(opts)
  end,
}
