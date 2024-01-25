--THEME: KANAGAWA
return {
  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'rebelot/kanagawa.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      require('kanagawa').setup {
        theme = 'wave',
        term_colors = true,
        overrides = function(colors)
          local theme = colors.theme
          return {
            NormalFloat = { bg = 'none' },
            FloatBorder = { bg = 'none' },
            FloatTitle = { bg = 'none' },

            -- Save an hlgroup with dark background and dimmed foreground
            -- so that you can use it where your still want darker windows.
            -- E.g.: autocmd TermOpen * setlocal winhighlight=Normal:NormalDark
            NormalDark = { fg = theme.ui.fg_dim, bg = theme.ui.bg_m3 },

            -- Popular plugins that open floats will link to NormalFloat by default;
            -- set their background accordingly if you wish to keep them dark and borderless
            LazyNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },
            MasonNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },

            -- Grey out unused symbols (variables, imports, etc.)
            DiagnosticUnnecessary = { fg = theme.ui.fg_dim, italic = true },
          }
        end,
        colors = {
          theme = {
            all = {
              ui = {
                bg_gutter = 'none',
              },
            },
          },
        },
      }
      require('kanagawa').load()
      vim.cmd.colorscheme 'kanagawa'
    end,
  },
}

-- THEME: ONEDARK
-- return {
--   {
--     'navarasu/onedark.nvim',
--     priority = 1000, -- Make sure to load this before all the other start plugins.
--     config = function()
--       require('onedark').setup {
--         background = 'darker',
--         term_colors = true,
--       }
--       require('onedark').load()
--       vim.cmd.colorscheme 'onedark'
--     end,
--   },
-- }

-- vim: ts=2 sts=2 sw=2 et
