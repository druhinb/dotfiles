-- ============================================================================
-- Which-Key.nvim - Keybinding Popup (LazyVim Style)
-- Shows pending keybinds in a bottom-right popup
-- ============================================================================
return {
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts_extend = { 'spec' },
    opts = {
      -- Preset: 'classic', 'modern', 'helix'
      preset = 'modern',
      -- Delay before showing popup (instant feel)
      delay = 0,
      -- Window configuration (bottom-right positioning)
      win = {
        border = 'rounded',
        padding = { 1, 2 },
        wo = {
          winblend = 0,
        },
        -- Position calculated to be bottom-right
        row = -1,
        col = 0.99,
      },
      -- Layout configuration
      layout = {
        height = { min = 4, max = 25 },
        width = { min = 20, max = 50 },
        spacing = 3,
        align = 'left',
      },
      -- Icons configuration
      icons = {
        breadcrumb = '»',
        separator = '➜',
        group = '+',
        ellipsis = '…',
        mappings = vim.g.have_nerd_font,
        rules = {},
        colors = true,
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
        },
      },
      -- Show keybinding help
      show_help = true,
      show_keys = true,
      -- Key groups and mappings (LazyVim style organization)
      spec = {
        -- ════════════════════════════════════════════════════════════════════
        -- Leader Groups (Top-Level Categories)
        -- ════════════════════════════════════════════════════════════════════
        { '<leader>a', group = 'argument swap', icon = { icon = '󰌶', color = 'cyan' } },
        { '<leader>b', group = 'buffer', icon = { icon = '󰈔', color = 'blue' } },
        { '<leader>c', group = 'code', icon = { icon = '', color = 'orange' } },
        { '<leader>d', group = 'debug/diagnostics', icon = { icon = '', color = 'red' } },
        { '<leader>f', group = 'file/find', icon = { icon = '󰈞', color = 'cyan' } },
        { '<leader>g', group = 'git', icon = { icon = '', color = 'orange' } },
        { '<leader>gf', group = 'find', icon = { icon = '', color = 'cyan' } },
        { '<leader>gh', group = 'hunks', icon = { icon = '', color = 'orange' } },
        { '<leader>h', group = 'resize left', icon = { icon = '󰁍', color = 'blue' } },
        { '<leader>j', group = 'resize down', icon = { icon = '󰁅', color = 'blue' } },
        { '<leader>k', group = 'resize up', icon = { icon = '󰁝', color = 'blue' } },
        { '<leader>l', group = 'layout/resize right', icon = { icon = '󰁔', color = 'blue' } },
        { '<leader>n', group = 'noice/notifications', icon = { icon = '󰎟', color = 'yellow' } },
        { '<leader>o', group = 'organize', icon = { icon = '󱃔', color = 'purple' } },
        { '<leader>p', group = 'peek', icon = { icon = '󰍉', color = 'green' } },
        { '<leader>q', group = 'quit/session', icon = { icon = '󰈆', color = 'red' } },
        { '<leader>r', group = 'rename/refactor', icon = { icon = '󰑕', color = 'purple' } },
        { '<leader>s', group = 'search', icon = { icon = '', color = 'green' } },
        { '<leader>sn', group = 'noice', icon = { icon = '󰎟', color = 'yellow' } },
        { '<leader>t', group = 'toggle/tabs', icon = { icon = '󰔡', color = 'yellow' } },
        { '<leader>tg', group = 'git', icon = { icon = '', color = 'orange' } },
        { '<leader>u', group = 'ui/undo', icon = { icon = '󰙵', color = 'cyan' } },
        { '<leader>w', group = 'windows/write', icon = { icon = '', color = 'blue' } },
        { '<leader>x', group = 'trouble/quickfix', icon = { icon = '󱖫', color = 'red' } },
        { '<leader>xn', group = 'neotest', icon = { icon = '󰙨', color = 'green' } },
        -- ════════════════════════════════════════════════════════════════════
        -- Vim Motion Groups (Built-in Keys)
        -- ════════════════════════════════════════════════════════════════════
        { '<C-w>', group = 'window', icon = { icon = '', color = 'blue' } },
        { 'g', group = 'goto', icon = { icon = '󱞫', color = 'cyan' } },
        { 'z', group = 'fold/scroll', icon = { icon = '󰁌', color = 'purple' } },
        { 'm', group = 'mark', icon = { icon = '󰃀', color = 'yellow' } },
        { "'", group = 'jump to mark', icon = { icon = '󰃀', color = 'yellow' } },
        { '`', group = 'jump to mark (exact)', icon = { icon = '󰃀', color = 'yellow' } },
        { '"', group = 'registers', icon = { icon = '󱓥', color = 'orange' } },
        -- ════════════════════════════════════════════════════════════════════
        -- Navigation Groups ([ and ])
        -- ════════════════════════════════════════════════════════════════════
        { '[', group = 'prev', icon = { icon = '󰒮', color = 'cyan' } },
        { ']', group = 'next', icon = { icon = '󰒭', color = 'cyan' } },
        -- Quickfix navigation
        { '[q', desc = 'Prev Quickfix' },
        { ']q', desc = 'Next Quickfix' },
        { '[Q', desc = 'First Quickfix' },
        { ']Q', desc = 'Last Quickfix' },
        -- Location list navigation
        { '[l', desc = 'Prev Location' },
        { ']l', desc = 'Next Location' },
        { '[L', desc = 'First Location' },
        { ']L', desc = 'Last Location' },
        -- Tab navigation
        { '[t', desc = 'Prev Tab' },
        { ']t', desc = 'Next Tab' },
        { '[T', desc = 'First Tab' },
        { ']T', desc = 'Last Tab' },
        -- Diagnostic navigation
        { '[d', desc = 'Prev Diagnostic' },
        { ']d', desc = 'Next Diagnostic' },
        { '[e', desc = 'Prev Error' },
        { ']e', desc = 'Next Error' },
        { '[w', desc = 'Prev Warning' },
        { ']w', desc = 'Next Warning' },
        -- Treesitter/Code navigation
        { '[f', desc = 'Prev Function' },
        { ']f', desc = 'Next Function' },
        { '[c', desc = 'Prev Class/Change' },
        { ']c', desc = 'Next Class/Change' },
        { '[a', desc = 'Prev Argument' },
        { ']a', desc = 'Next Argument' },
        -- Git navigation
        { '[h', desc = 'Prev Hunk' },
        { ']h', desc = 'Next Hunk' },
        -- ════════════════════════════════════════════════════════════════════
        -- Surround/Text Object Groups (gs prefix for mini.surround)
        -- ════════════════════════════════════════════════════════════════════
        { 'gs', group = 'surround find', icon = { icon = '󰅪', color = 'purple' } },
        -- ════════════════════════════════════════════════════════════════════
        -- Text Objects (operator-pending and visual modes)
        -- ════════════════════════════════════════════════════════════════════
        { 'a', group = 'around', mode = { 'o', 'x' }, icon = { icon = '󰅪', color = 'yellow' } },
        { 'i', group = 'inside', mode = { 'o', 'x' }, icon = { icon = '󰅪', color = 'yellow' } },
        -- Common text object descriptions
        { 'af', desc = 'around function', mode = { 'o', 'x' } },
        { 'if', desc = 'inside function', mode = { 'o', 'x' } },
        { 'ac', desc = 'around class', mode = { 'o', 'x' } },
        { 'ic', desc = 'inside class', mode = { 'o', 'x' } },
        { 'aa', desc = 'around argument', mode = { 'o', 'x' } },
        { 'ia', desc = 'inside argument', mode = { 'o', 'x' } },
        { 'ab', desc = 'around block', mode = { 'o', 'x' } },
        { 'ib', desc = 'inside block', mode = { 'o', 'x' } },
        { 'ao', desc = 'around loop/conditional', mode = { 'o', 'x' } },
        { 'io', desc = 'inside loop/conditional', mode = { 'o', 'x' } },
        { 'ai', desc = 'around indent', mode = { 'o', 'x' } },
        { 'ii', desc = 'inside indent', mode = { 'o', 'x' } },
        { 'ag', desc = 'around buffer', mode = { 'o', 'x' } },
        { 'ig', desc = 'inside buffer', mode = { 'o', 'x' } },
      },
      -- Filter to only show mappings with descriptions
      filter = function(mapping)
        return mapping.desc and mapping.desc ~= ''
      end,
      -- Trigger which-key automatically
      triggers = {
        { '<auto>', mode = 'nixsotc' },
      },
      -- Plugin integrations
      plugins = {
        marks = true,
        registers = true,
        spelling = {
          enabled = true,
          suggestions = 20,
        },
        presets = {
          operators = true,
          motions = true,
          text_objects = true,
          windows = true,
          nav = true,
          z = true,
          g = true,
        },
      },
      -- Disable for certain filetypes
      disable = {
        ft = {},
        bt = {},
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
