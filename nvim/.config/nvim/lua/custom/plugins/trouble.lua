-- =============================================================================
-- Trouble.nvim Configuration (LazyVim Workflow)
-- =============================================================================
-- Deep integration with LSP:
--   - Diagnostics for buffer and project
--   - LSP references open in Trouble (not quickfix)
--   - Code symbols with <leader>cs
--   - DevIcon integration for files/folders
-- =============================================================================

return {
  'folke/trouble.nvim',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },
  cmd = 'Trouble',
  opts = {
    -- Auto-focus the Trouble window when opened
    focus = true,

    -- Default window configuration
    win = {
      type = 'split',
      position = 'bottom',
      size = 0.3,
    },

    -- ===========================================================================
    -- Icons (LazyVim/DevIcon style)
    -- ===========================================================================
    icons = {
      indent = {
        top = '│ ',
        middle = '├╴',
        last = '└╴',
        fold_open = ' ',
        fold_closed = ' ',
        ws = '  ',
      },
      folder_closed = ' ',
      folder_open = ' ',
      kinds = {
        Array = ' ',
        Boolean = '󰨙 ',
        Class = ' ',
        Constant = '󰏿 ',
        Constructor = ' ',
        Enum = ' ',
        EnumMember = ' ',
        Event = ' ',
        Field = ' ',
        File = ' ',
        Function = '󰊕 ',
        Interface = ' ',
        Key = ' ',
        Method = '󰊕 ',
        Module = ' ',
        Namespace = '󰦮 ',
        Null = ' ',
        Number = '󰎠 ',
        Object = ' ',
        Operator = ' ',
        Package = ' ',
        Property = ' ',
        String = ' ',
        Struct = '󰆼 ',
        TypeParameter = ' ',
        Variable = '󰀫 ',
      },
    },

    -- ===========================================================================
    -- Mode Configurations
    -- ===========================================================================
    modes = {
      -- Symbols mode (for <leader>cs)
      symbols = {
        desc = 'Document Symbols',
        mode = 'lsp_document_symbols',
        win = {
          type = 'split',
          position = 'right',
          size = 0.35,
        },
        focus = false,
        filter = {
          -- Remove Package since lua_ls uses it for control flow structures
          ['not'] = { ft = 'lua', kind = 'Package' },
          any = {
            -- All symbol kinds for help/markdown files
            ft = { 'help', 'markdown' },
            -- Default set of symbol kinds
            kind = {
              'Class',
              'Constructor',
              'Enum',
              'Field',
              'Function',
              'Interface',
              'Method',
              'Module',
              'Namespace',
              'Package',
              'Property',
              'Struct',
              'Trait',
            },
          },
        },
      },

      -- LSP references mode (for gr keymap)
      lsp_references = {
        desc = 'LSP References',
        mode = 'lsp_references',
        focus = true,
        win = {
          type = 'split',
          position = 'bottom',
          size = 0.3,
        },
        params = {
          include_declaration = true,
        },
      },

      -- LSP definitions/implementations/type definitions
      lsp = {
        desc = 'LSP Definitions / References / ...',
        mode = 'lsp',
        win = {
          type = 'split',
          position = 'right',
          size = 0.4,
        },
        focus = false,
      },

      -- Diagnostics for current buffer
      diagnostics_buffer = {
        mode = 'diagnostics',
        filter = { buf = 0 },
      },
    },
  },
  keys = {
    -- ===========================================================================
    -- Diagnostics (LazyVim <leader>x prefix)
    -- ===========================================================================
    {
      '<leader>xx',
      '<cmd>Trouble diagnostics toggle<cr>',
      desc = 'Diagnostics (Trouble)',
    },
    {
      '<leader>xX',
      '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
      desc = 'Buffer Diagnostics (Trouble)',
    },

    -- ===========================================================================
    -- LSP Integration
    -- ===========================================================================
    {
      '<leader>cs',
      '<cmd>Trouble symbols toggle<cr>',
      desc = 'Symbols (Trouble)',
    },
    {
      '<leader>cS',
      '<cmd>Trouble lsp toggle<cr>',
      desc = 'LSP References/Definitions (Trouble)',
    },

    -- ===========================================================================
    -- Quickfix/Location List
    -- ===========================================================================
    {
      '<leader>xL',
      '<cmd>Trouble loclist toggle<cr>',
      desc = 'Location List (Trouble)',
    },
    {
      '<leader>xQ',
      '<cmd>Trouble qflist toggle<cr>',
      desc = 'Quickfix List (Trouble)',
    },

    -- ===========================================================================
    -- Navigation within Trouble
    -- ===========================================================================
    {
      '[q',
      function()
        if require('trouble').is_open() then
          require('trouble').prev { skip_groups = true, jump = true }
        else
          local ok, err = pcall(vim.cmd.cprev)
          if not ok then
            vim.notify(err, vim.log.levels.ERROR)
          end
        end
      end,
      desc = 'Previous Trouble/Quickfix Item',
    },
    {
      ']q',
      function()
        if require('trouble').is_open() then
          require('trouble').next { skip_groups = true, jump = true }
        else
          local ok, err = pcall(vim.cmd.cnext)
          if not ok then
            vim.notify(err, vim.log.levels.ERROR)
          end
        end
      end,
      desc = 'Next Trouble/Quickfix Item',
    },
  },
}
