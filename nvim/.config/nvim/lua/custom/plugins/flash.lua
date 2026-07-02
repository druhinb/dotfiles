-- ============================================================================
-- Flash.nvim - Advanced Navigation (LazyVim Style)
-- Jump anywhere instantly with search labels
-- ============================================================================
return {
  'folke/flash.nvim',
  event = 'VeryLazy',
  vscode = true,
  ---@type Flash.Config
  opts = {
    -- Labels configuration
    labels = 'asdfghjklqwertyuiopzxcvbnm',
    -- Search configuration
    search = {
      -- Search direction
      multi_window = true,
      forward = true,
      wrap = true,
      -- Search mode: exact, search, fuzzy, fun(str)
      mode = 'exact',
      -- Behave like `incsearch`
      incremental = false,
      -- Excluded filetypes
      exclude = {
        'notify',
        'cmp_menu',
        'noice',
        'flash_prompt',
        function(win)
          -- Exclude non-focusable windows
          return not vim.api.nvim_win_get_config(win).focusable
        end,
      },
      -- When `false`, find only matches in the given direction
      trigger = '',
      -- Max pattern length, -1 for no limit
      max_length = false,
    },
    -- Jump configuration
    jump = {
      -- Save location to jumplist
      jumplist = true,
      -- Jump position
      pos = 'start', -- 'start', 'end', 'range'
      -- Cursor history
      history = false,
      -- Register for storing jumped position
      register = false,
      -- Do not jump when pressing <CR> or <Esc>
      nohlsearch = false,
      -- Automatically jump when there is only one match
      autojump = false,
      -- Include matches when jumping
      inclusive = nil,
      -- Relative offset from jump position
      offset = nil,
    },
    -- Label configuration
    label = {
      -- Allow uppercase labels
      uppercase = true,
      -- Exclude labels from matches
      exclude = '',
      -- Position of the label (offset from match)
      current = true,
      -- After position
      after = true,
      -- Before position
      before = false,
      -- Label style: 'overlay', 'eol', 'right_align', 'inline'
      style = 'overlay',
      -- Show label before or after the match
      reuse = 'lowercase',
      -- Flash tries to re-use labels that were already assigned
      distance = true,
      -- Minimum pattern length for showing labels
      min_pattern_length = 0,
      -- Rainbow colors
      rainbow = {
        enabled = true,
        shade = 5,
      },
      -- Format the label
      format = function(opts)
        return { { opts.match.label, opts.hl_group } }
      end,
    },
    -- Highlight configuration
    highlight = {
      -- Show backdrop
      backdrop = true,
      -- Highlight matched text
      matches = true,
      -- Priority
      priority = 5000,
      groups = {
        match = 'FlashMatch',
        current = 'FlashCurrent',
        backdrop = 'FlashBackdrop',
        label = 'FlashLabel',
      },
    },
    -- Action when pressing a key
    action = nil,
    -- Pattern to highlight
    pattern = '',
    -- Show flash when searching with / or ?
    continue = false,
    -- Configuration for different modes
    modes = {
      -- Regular search (/)
      search = {
        enabled = false, -- disable to use default search
        highlight = { backdrop = false },
        jump = { history = true, register = true, nohlsearch = true },
        search = {
          -- `forward` will be automatically set to the search direction
          -- `mode` is always set to `search`
          -- `incremental` is set to `true` when `incsearch` is enabled
        },
      },
      -- Char mode (f/F/t/T)
      char = {
        enabled = true,
        -- Dynamic configuration for ftFT motions
        config = function(opts)
          -- Autohide flash when in operator-pending mode
          opts.autohide = opts.autohide or (vim.fn.mode(true):find 'no' and vim.v.operator == 'y')
          -- Disable jump labels when not enabled, using a count, or in operator-pending mode
          opts.jump_labels = opts.jump_labels and vim.v.count == 0 and vim.fn.reg_executing() == '' and vim.fn.reg_recording() == ''
        end,
        -- Show jump labels
        autohide = false,
        jump_labels = false,
        multi_line = true,
        label = { exclude = 'hjkliardcx' },
        -- By default, all keymaps are enabled
        keys = { 'f', 'F', 't', 'T', ';', ',' },
        -- Char highlight
        char_actions = function(motion)
          return {
            [';'] = 'next',
            [','] = 'prev',
            [motion:lower()] = 'next',
            [motion:upper()] = 'prev',
          }
        end,
        search = { wrap = false },
        highlight = { backdrop = true },
        jump = {
          register = false,
          -- When using jump labels, set to 'seek' for the current position
          autojump = false,
        },
      },
      -- Treesitter mode
      treesitter = {
        labels = 'abcdefghijklmnopqrstuvwxyz',
        jump = { pos = 'range', autojump = true },
        search = { incremental = false },
        label = { before = true, after = true, style = 'inline' },
        highlight = {
          backdrop = false,
          matches = false,
        },
      },
      -- Treesitter search
      treesitter_search = {
        jump = { pos = 'range' },
        search = { multi_window = true, wrap = true, incremental = false },
        remote_op = { restore = true },
        label = { before = true, after = true, style = 'inline' },
      },
      -- Remote mode
      remote = {
        remote_op = { restore = true, motion = true },
      },
    },
    -- Prompt configuration
    prompt = {
      enabled = true,
      prefix = { { '⚡', 'FlashPromptIcon' } },
      win_config = {
        relative = 'editor',
        width = 1, -- Magic number to center
        height = 1,
        row = -1,
        col = 0,
        zindex = 1000,
      },
    },
    -- Remote operation configuration
    remote_op = {
      restore = false,
      motion = false,
    },
  },
  -- stylua: ignore
  keys = {
    -- s: Flash jump (anywhere on screen)
    { 's', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash' },
    -- S: Flash treesitter (select treesitter nodes)
    { 'S', mode = { 'n', 'x', 'o' }, function() require('flash').treesitter() end, desc = 'Flash Treesitter' },
    -- r: Remote flash (for operator-pending mode)
    -- Example: yr to yank a remote area, dr to delete remotely
    { 'r', mode = 'o', function() require('flash').remote() end, desc = 'Remote Flash' },
    -- R: Treesitter search (search & select)
    { 'R', mode = { 'o', 'x' }, function() require('flash').treesitter_search() end, desc = 'Treesitter Search' },
    -- <c-s>: Toggle flash in search mode
    { '<c-s>', mode = { 'c' }, function() require('flash').toggle() end, desc = 'Toggle Flash Search' },
  },
}
