-- NOTE: Plugins can also be configured to run Lua code when they are loaded.
--
-- This is often very useful to both group configuration, as well as handle
-- lazy loading plugins that don't need to be loaded immediately at startup.
--
-- For example, in the following configuration, we use:
--  event = 'VimEnter'
--
-- which loads which-key before all the UI elements are loaded. Events can be
-- normal autocommands events (`:help autocmd-events`).
--
-- Then, because we use the `opts` key (recommended), the configuration runs
-- after the plugin has been loaded as `require(MODULE).setup(opts)`.

return {
  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    opts = {
      preset = 'modern', -- 'classic', 'modern', 'helix'
      -- delay between pressing a key and opening which-key (milliseconds)
      -- this setting is independent of vim.o.timeoutlen
      delay = 0,
      win = {
        border = 'rounded', -- none, single, double, shadow
        -- position = 'bottom', -- INVALID in v3
        -- margin = { 1, 0, 1, 0 }, -- INVALID in v3
        padding = { 2, 2 }, -- extra window padding [top/bottom, right/left]
        wo = {
          winblend = 0,
        },
      },
      layout = {
        height = { min = 4, max = 25 }, -- min and max height of the columns
        width = { min = 20, max = 50 }, -- min and max width of the columns
        spacing = 3, -- spacing between columns
        align = 'left', -- align columns left, center or right
      },
      -- ignore_missing = true, -- DEPRECATED
      -- show_help = true, -- DEPRECATED
      -- show_keys = true, -- DEPRECATED
      -- triggers = 'auto', -- DEPRECATED

      icons = {
        breadcrumb = '»', -- symbol used in the command line area that shows your active key combo
        separator = '➜', -- symbol used between a key and it's label
        group = '+', -- symbol prepended to a group
        -- set icon mappings to true if you have a Nerd Font
        mappings = vim.g.have_nerd_font,
        -- If you are using a Nerd Font: set icons.keys to an empty table which will use the
        -- default which-key.nvim defined Nerd Font icons, otherwise define a string table
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
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },

      -- Document existing key chains
      spec = {
        -- Leader groups
        { '<leader>a', group = '[A]rgument swap' },
        { '<leader>b', group = '[B]uffer' },
        { '<leader>c', group = '[C]onflict' },
        { '<leader>d', group = '[D]iagnostics' },
        { '<leader>g', group = '[G]it' },
        { '<leader>h', group = 'Git [H]unk / Resize Left', mode = { 'n', 'v' } },
        { '<leader>l', group = '[L]ayout / Resize Right' },
        { '<leader>o', group = '[O]rganize' },
        { '<leader>p', group = '[P]eek Definition' },
        { '<leader>q', group = '[Q]uickfix' },
        { '<leader>r', group = '[R]ename/Refactor' },
        { '<leader>s', group = '[S]earch' },
        { '<leader>t', group = '[T]oggle/Tabs' },
        { '<leader>w', group = '[W]rite/Workspace' },

        -- Vim motion groups
        { '<C-w>', group = '[W]indow' },
        { 'g', group = '[G]o to' },
        { 'z', group = '[Z] Fold/Scroll' },
        { 'm', group = 'Set [M]ark' },
        { "'", group = "Jump to [']Mark" },
        { '`', group = 'Jump to [`]Mark (exact)' },
        { '"', group = '["]Registers' },

        -- Navigation groups
        { '[', group = '[P]revious ...' },
        { ']', group = '[N]ext ...' },

        -- Quickfix navigation
        { '[q', desc = 'Prev [Q]uickfix item' },
        { ']q', desc = 'Next [Q]uickfix item' },
        { '[Q', desc = 'First [Q]uickfix item' },
        { ']Q', desc = 'Last [Q]uickfix item' },

        -- Location list navigation
        { '[l', desc = 'Prev [L]ocation list item' },
        { ']l', desc = 'Next [L]ocation list item' },
        { '[L', desc = 'First [L]ocation list item' },
        { ']L', desc = 'Last [L]ocation list item' },

        -- Tab navigation
        { '[t', desc = 'Prev [T]ab' },
        { ']t', desc = 'Next [T]ab' },
        { '[T', desc = 'First [T]ab' },
        { ']T', desc = 'Last [T]ab' },

        -- Diagnostic navigation
        { '[d', desc = 'Prev [D]iagnostic' },
        { ']d', desc = 'Next [D]iagnostic' },

        -- Treesitter textobject navigation (defined in treesitter.lua)
        { '[f', desc = 'Prev [F]unction start' },
        { ']f', desc = 'Next [F]unction start' },
        { '[F', desc = 'Prev [F]unction end' },
        { ']F', desc = 'Next [F]unction end' },
        { '[k', desc = 'Prev [K]lass start' },
        { ']k', desc = 'Next [K]lass start' },
        { '[K', desc = 'Prev [K]lass end' },
        { ']K', desc = 'Next [K]lass end' },
        { '[a', desc = 'Prev [A]rgument' },
        { ']a', desc = 'Next [A]rgument' },
        { '[o', desc = 'Prev l[O]op' },
        { ']o', desc = 'Next l[O]op' },
        { '[r', desc = 'Prev [R]eturn' },
        { ']r', desc = 'Next [R]eturn' },
        { '[/', desc = 'Prev comment' },
        { ']/', desc = 'Next comment' },
        { '[=', desc = 'Prev assignment' },
        { ']=', desc = 'Next assignment' },

        -- Spell navigation
        { '[s', desc = 'Prev mi[S]spelled word' },
        { ']s', desc = 'Next mi[S]spelled word' },

        -- Git/Diff change navigation (gitsigns)
        { '[c', desc = 'Prev [C]hange hunk' },
        { ']c', desc = 'Next [C]hange hunk' },

        -- Method navigation (built-in)
        { '[m', desc = 'Prev [M]ethod start' },
        { ']m', desc = 'Next [M]ethod start' },
        { '[M', desc = 'Prev [M]ethod end' },
        { ']M', desc = 'Next [M]ethod end' },

        -- Section navigation
        { '[[', desc = 'Prev section start' },
        { ']]', desc = 'Next section start' },
        { '[]', desc = 'Prev section end' },
        { '][', desc = 'Next section end' },

        -- Fold navigation
        { '[z', desc = 'Start of current fold' },
        { ']z', desc = 'End of current fold' },
        { 'zj', desc = 'Next fold' },
        { 'zk', desc = 'Prev fold' },

        -- Empty line/paragraph navigation
        { '{', desc = 'Prev empty line/paragraph' },
        { '}', desc = 'Next empty line/paragraph' },

        -- Brace/paren navigation
        { '[(', desc = 'Prev unmatched (' },
        { '])', desc = 'Next unmatched )' },
        { '[{', desc = 'Prev unmatched {' },
        { ']}', desc = 'Next unmatched }' },

        -- Operator-pending textobject descriptions
        { 'a', group = '[A]round (textobject)', mode = { 'o', 'x' } },
        { 'i', group = '[I]nside (textobject)', mode = { 'o', 'x' } },
      },
      filter = function(mapping)
        -- return true to include the mapping, false to exclude it
        return mapping.desc and mapping.desc ~= ''
      end,
      triggers = {
        { '<auto>', mode = 'nixsotc' },
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
