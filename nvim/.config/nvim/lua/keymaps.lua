-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>dl', vim.diagnostic.setloclist, { desc = 'Open diagnostic [L]ist' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Split windows like tmux
vim.keymap.set('n', '<leader>|', '<cmd>vsplit<CR>', { desc = 'Vertical Split' })
vim.keymap.set('n', '<leader>-', '<cmd>split<CR>', { desc = 'Horizontal Split' })

-- Better half-page scrolling
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Scroll down 1/2 page' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Scroll down 1/2 page' })

-- Resize windows
vim.keymap.set('n', '<leader>j', '<cmd>resize -5<CR>', { desc = 'Resize window down' })
vim.keymap.set('n', '<leader>k', '<cmd>resize +5<CR>', { desc = 'Resize window up' })
vim.keymap.set('n', '<leader>l', '<cmd>vertical resize +5<CR>', { desc = 'Resize window right' })
vim.keymap.set('n', '<leader>h', '<cmd>vertical resize -5<CR>', { desc = 'Resize window left' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- User defined keymaps
vim.keymap.set('n', '<leader>ww', '<cmd>w<CR>', { desc = 'Save buffer' })
-- Removed conflicting <leader>q and <leader>x mappings to allow plugins to use them.
-- Replaced with <leader>wc for closing split (Window Close)
vim.keymap.set('n', '<leader>c', '<cmd>close<CR>', { desc = '[W]indow [C]lose split' })

-- Move lines up and down
vim.keymap.set('n', '<M-j>', '<cmd>m .+1<CR>==', { desc = 'Move line down' })
vim.keymap.set('n', '<M-k>', '<cmd>m .-2<CR>==', { desc = 'Move line up' })

-- Navigate through buffers (Non-cyclic)
local function buffer_navigate(direction)
  local buffers = vim.tbl_filter(function(b)
    return vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted
  end, vim.api.nvim_list_bufs())

  local current = vim.api.nvim_get_current_buf()
  for i, buf in ipairs(buffers) do
    if buf == current then
      if direction == 'next' then
        if i < #buffers then
          vim.api.nvim_set_current_buf(buffers[i + 1])
        end
      elseif direction == 'prev' then
        if i > 1 then
          vim.api.nvim_set_current_buf(buffers[i - 1])
        end
      end
      return
    end
  end
end

vim.keymap.set('n', '<S-h>', function()
  buffer_navigate 'prev'
end, { desc = 'Previous buffer' })
vim.keymap.set('n', '<S-l>', function()
  buffer_navigate 'next'
end, { desc = 'Next buffer' })

-- Git Blame
vim.keymap.set('n', '<leader>tb', '<cmd>Gitsigns blame_line<CR>', { desc = '[T]oggle Git [B]lame' })

vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous [D]iagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next [D]iagnostic message' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })

-- Map [[ and ]]
vim.keymap.set('n', '[[', '[[', { desc = 'Previous Section' })
vim.keymap.set('n', ']]', ']]', { desc = 'Next Section' })

-- Better indenting
vim.keymap.set('v', '<', '<gv')
vim.keymap.set('v', '>', '>gv')

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- vim: ts=2 sts=2 sw=2 et
