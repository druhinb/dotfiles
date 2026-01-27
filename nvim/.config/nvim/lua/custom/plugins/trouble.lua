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
      size = { width = 0.4 },
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
          position = 'right',
          size = { width = 0.35 },
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
          position = 'bottom',
          size = { height = 0.3 },
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
          position = 'right',
          size = { width = 0.4 },
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

    -- ===========================================================================
    -- Legacy keymaps (for compatibility)
    -- ===========================================================================
    {
      '<leader>dL',
      '<cmd>Trouble diagnostics toggle<cr>',
      desc = 'Project Diagnostics (Trouble)',
    },
    {
      '<leader>dl',
      '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
      desc = 'Buffer Diagnostics (Trouble)',
    },
    {
      '<leader>cl',
      '<cmd>Trouble lsp toggle focus=false win.position=right<cr>',
      desc = 'LSP Definitions/References (Trouble)',
    },
  },
  -- ===========================================================================
  -- Override LSP handlers to use Trouble
  -- ===========================================================================
  init = function()
    -- Override the default LSP references handler to open in Trouble
    -- This makes `gr` (when using vim.lsp.buf.references) use Trouble
    local original_references = vim.lsp.handlers['textDocument/references']
    vim.lsp.handlers['textDocument/references'] = function(err, result, ctx, config)
      if not result or vim.tbl_isempty(result) then
        vim.notify('No references found', vim.log.levels.INFO)
        return
      end
      -- Open references in Trouble instead of quickfix
      require('trouble').open { mode = 'lsp_references', focus = true }
    end
  end,
}
