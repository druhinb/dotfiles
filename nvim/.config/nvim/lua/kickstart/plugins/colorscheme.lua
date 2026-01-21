--THEME: KANAGAWA
-- return {
--   { -- You can easily change to a different colorscheme.
--     -- Change the name of the colorscheme plugin below, and then
--     -- change the command in the config to whatever the name of that colorscheme is.
--     --
--     -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
--     'rebelot/kanagawa.nvim',
--     priority = 1000, -- Make sure to load this before all the other start plugins.
--     config = function()
--       require('kanagawa').setup {
--         theme = 'wave',
--         term_colors = true,
--         overrides = function(colors)
--           local theme = colors.theme
--           return {
--             NormalFloat = { bg = 'none' },
--             FloatBorder = { bg = 'none' },
--             FloatTitle = { bg = 'none' },
--
--             -- Save an hlgroup with dark background and dimmed foreground
--             -- so that you can use it where your still want darker windows.
--             -- E.g.: autocmd TermOpen * setlocal winhighlight=Normal:NormalDark
--             NormalDark = { fg = theme.ui.fg_dim, bg = theme.ui.bg_m3 },
--
--             -- Popular plugins that open floats will link to NormalFloat by default;
--             -- set their background accordingly if you wish to keep them dark and borderless
--             LazyNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },
--             MasonNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },
--
--             -- Grey out unused symbols (variables, imports, etc.)
--             DiagnosticUnnecessary = { fg = theme.ui.fg_dim, italic = true },
--           }
--         end,
--         colors = {
--           theme = {
--             all = {
--               ui = {
--                 bg_gutter = 'none',
--               },
--             },
--           },
--         },
--       }
--       require('kanagawa').load()
--       vim.cmd.colorscheme 'kanagawa'
--     end,
--   },
-- }

-- THEME: ONEDARK PRO (Custom "Modern Pro" Variant)
return {
  {
    'olimorris/onedarkpro.nvim',
    priority = 1000,
    config = function()
      require('onedarkpro').setup {
        colors = {
          onedark = {
            bg = '#1F1F1F',
            fg = '#CCCCCC',
            red = '#e06c75',
            green = '#98c379',
            yellow = '#e5c07b',
            blue = '#61afef',
            purple = '#c678dd',
            cyan = '#56b6c2',
            orange = '#d19a66',
            gray = '#7f848e',
          },
        },
        highlights = {
          -- 1. CUSTOM CURSOR COLOR
          -- Sets the cursor block to White (#FFFFFF) and text inside it to Black
          Cursor = { bg = '#FFFFFF', fg = '#000000' },
          -- Use this if you are using a terminal that supports 'termguicolors'
          TermCursor = { bg = '#FFFFFF', fg = '#000000' },

          -- 2. STICKY SCROLL / SCOPE HEADER
          -- Most plugins (like nvim-treesitter-context) use these groups.
          -- We set the background to match the editor (#1F1F1F) so it looks seamless.
          TreesitterContext = { bg = '#1F1F1F' },
          TreesitterContextLineNumber = { bg = '#1F1F1F', fg = '#6E7681' },
          TreesitterContextBottom = { style = 'underline', sp = '#2B2B2B' }, -- Optional: small line to separate
          LspInlayHint = { bg = '#2B2B2B', fg = '#888888', italic = false },
          Normal = { bg = '#1F1F1F', fg = '#CCCCCC' },
          NormalFloat = { bg = '#1F1F1F', fg = '#CCCCCC' },
          FloatBorder = { bg = '#1F1F1F', fg = '#0078d4' }, -- Blue border, transparent-looking bg
          LazyNormal = { bg = '#1F1F1F' },
          MasonNormal = { bg = '#1F1F1F' },

          NormalNC = { bg = '#1F1F1F', fg = '#CCCCCC' },
          CursorLine = { bg = '#2B2B2B' },
          LineNr = { fg = '#6E7681' },
          CursorLineNr = { fg = '#CCCCCC', bold = true },
          SignColumn = { bg = '#1F1F1F' },
          StatusLine = { bg = '#181818', fg = '#CCCCCC' },
          StatusLineNC = { bg = '#181818', fg = '#9D9D9D' },
          VertSplit = { fg = '#2B2B2B', bg = '#1F1F1F' },
          WinSeparator = { fg = '#2B2B2B', bg = '#1F1F1F' },
          Pmenu = { bg = '#202020', fg = '#CCCCCC' },
          PmenuSel = { bg = '#0078d4', fg = '#FFFFFF' },
          Search = { bg = '#9E6A03', fg = '#FFFFFF' },

          -- Java semantic token tuning: keep modifiers keyword-colored so
          -- declarations like `public static final class ...` are distinct.
          ['@lsp.type.modifier.java'] = { link = '@keyword' },
          ['@lsp.type.keyword.java'] = { link = '@keyword' },
          ['@lsp.type.class.java'] = { link = '@type' },
        },
        styles = {
          comments = 'italic',
          keywords = 'bold',
          functions = 'bold',
        },
      }

      vim.cmd 'colorscheme onedark'
    end,
  },
} -- vim: ts=2 sts=2 sw=2 et
