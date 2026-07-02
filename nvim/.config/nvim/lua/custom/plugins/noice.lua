-- ============================================================================
-- Noice.nvim - Complete UI Replacement (LazyVim Style)
-- Replaces: messages, cmdline, popupmenu, notifications
-- ============================================================================
local is_ssh = vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil

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
        stages = is_ssh and 'static' or 'fade_in_slide_out',
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
          if is_ssh then
            -- Disable winblend inside the terminal on SSH for better rendering performance
            pcall(vim.api.nvim_win_set_option, win, 'winblend', 0)
          end
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
    { '<leader>snt', function() require('noice').cmd 'pick' end, desc = 'Noice picker' },
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
          winblend = is_ssh and 0 or 10,
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
          winblend = is_ssh and 0 or 10,
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
        win_options = {
          winblend = is_ssh and 0 or 10,
          winhighlight = {
            Normal = 'NormalFloat',
            FloatBorder = 'FloatBorder',
          },
        },
      },
    },
    -- Route configuration for different message types
    routes = {
      -- Skip standard, spammy editing, undo, search wrap, and status messages from popping up
      {
        filter = {
          event = 'msg_show',
          any = {
            -- File saves
            { find = 'written' },
            -- Undo/Redo state changes
            { find = '; before #' },
            { find = '; after #' },
            { find = 'already at oldest change' },
            { find = 'already at newest change' },
            -- Line edits, deletions, pastes, and indentation changes
            { find = 'line less' },
            { find = 'lines less' },
            { find = 'more line' },
            { find = 'more lines' },
            { find = 'change;' },
            { find = 'changes;' },
            { find = 'indent' },
            { find = 'indented' },
            -- Search wrapping and alerts
            { find = 'search hit BOTTOM' },
            { find = 'search hit TOP' },
            { find = 'Pattern not found' },
          },
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

    -- =========================================================================
    -- LSP Hover Doxygen Cleaner Hook for Noice
    -- =========================================================================

    -- Custom hover formatter to clean up Doxygen comments
    local function clean_doxygen(text)
      if type(text) ~= 'string' then
        return text
      end

      local lines = {}
      local in_params = false

      for line in text:gmatch '[^\r\n]+' do
        line = line:gsub('\r$', '')

        -- 1. Check for @brief or \brief
        if line:match '^%s*[@\\]brief' then
          line = line:gsub('^%s*[@\\]brief%s*', '')
        end

        -- 2. Check for @param or \param
        local p_in_out, p_name, p_desc = line:match '^%s*[@\\]param%s*%[([^%]]+)%]%s+([^%s]+)%s+(.*)$'
        if p_name then
          if not in_params then
            table.insert(lines, '')
            table.insert(lines, '**Parameters:**')
            in_params = true
          end
          line = string.format('* **%s** *(%s)*: %s', p_name, p_in_out, p_desc)
        else
          local p_name2, p_desc2 = line:match '^%s*[@\\]param%s+([^%s]+)%s+(.*)$'
          if p_name2 then
            if not in_params then
              table.insert(lines, '')
              table.insert(lines, '**Parameters:**')
              in_params = true
            end
            line = string.format('* **%s**: %s', p_name2, p_desc2)
          else
            if in_params and not line:match '^%s' and line ~= '' then
              in_params = false
            end
          end
        end

        -- 3. Check for @return / \return
        local ret_match = line:match '^%s*[@\\]returns?%s*(.*)$'
        if ret_match then
          table.insert(lines, '')
          line = '**Returns:** ' .. ret_match
        end

        -- 4. Check for @note / \note
        local note_match = line:match '^%s*[@\\]note%s*(.*)$'
        if note_match then
          line = '> **Note:** ' .. note_match
        end

        -- 5. Check for @warning / \warning
        local warn_match = line:match '^%s*[@\\]warning%s*(.*)$'
        if warn_match then
          line = '> **Warning:** ' .. warn_match
        end

        -- 6. Check for @see / \see
        local see_match = line:match '^%s*[@\\]see%s*(.*)$'
        if see_match then
          line = '*See also:* ' .. see_match
        end

        -- 7. Check for @tparam / \tparam
        local tp_name, tp_desc = line:match '^%s*[@\\]tparam%s+([^%s]+)%s+(.*)$'
        if tp_name then
          line = string.format('* **%s** *(template parameter)*: %s', tp_name, tp_desc)
        end

        table.insert(lines, line)
      end

      return table.concat(lines, '\n')
    end

    local function process_contents(contents)
      if type(contents) == 'string' then
        return clean_doxygen(contents)
      elseif type(contents) == 'table' then
        if contents.kind == 'markdown' or contents.kind == 'plaintext' then
          if type(contents.value) == 'string' then
            contents.value = clean_doxygen(contents.value)
          end
        elseif contents.value and type(contents.value) == 'string' then
          -- Always clean markdown/plain language blocks
          local lang = contents.language
          if not lang or lang == 'markdown' or lang == 'plaintext' or lang == 'plain' then
            contents.value = clean_doxygen(contents.value)
          end
        else
          for i, item in ipairs(contents) do
            contents[i] = process_contents(item)
          end
        end
      end
      return contents
    end

    -- Wrap Noice hover callback to process and clean up Doxygen comments
    local noice_hover = require 'noice.lsp.hover'
    local original_on_hover = noice_hover.on_hover
    noice_hover.on_hover = function(err, result, ctx)
      if result and result.contents then
        result.contents = process_contents(result.contents)
      end
      return original_on_hover(err, result, ctx)
    end
  end,
}
