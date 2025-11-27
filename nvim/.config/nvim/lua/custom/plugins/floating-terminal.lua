-- Floating terminal plugin
-- Opens a floating terminal window that can be easily toggled

return {
  'akinsho/toggleterm.nvim',
  version = '*',
  config = function()
    require('toggleterm').setup {
      size = 20,
      open_mapping = nil, -- We'll set custom mapping
      hide_numbers = true,
      shade_terminals = true,
      start_in_insert = true,
      insert_mappings = false,
      terminal_mappings = true,
      persist_size = true,
      persist_mode = true,
      direction = 'float',
      close_on_exit = true,
      shell = vim.o.shell,
      float_opts = {
        border = 'curved',
        winblend = 0,
        highlights = {
          border = 'Normal',
          background = 'Normal',
        },
      },
    }

    vim.api.nvim_create_user_command('FloatTerm', function()
      vim.cmd 'ToggleTerm direction=float'
    end, {})

    vim.keymap.set({ 'n', 'i', 't' }, '<C-t>', '<cmd>ToggleTerm direction=float<CR>', { desc = 'Toggle floating terminal', noremap = true, silent = true })

    -- Keymaps for easy closing
    -- In terminal mode, press <Esc><Esc> to close
    -- In normal mode within terminal, press 'q' to close
    function _G.set_terminal_keymaps()
      local opts = { buffer = 0 }
      vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n>:close<CR>]], opts)
      vim.keymap.set('n', 'q', '<cmd>close<CR>', opts)
      vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', opts)
    end

    vim.api.nvim_create_autocmd('TermOpen', {
      pattern = 'term://*toggleterm#*',
      callback = function()
        _G.set_terminal_keymaps()
      end,
    })
  end,
}
