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
vim.keymap.set('n', '<leader>w', '<cmd>w<CR>', { desc = 'Save buffer' })
vim.keymap.set('n', '<leader>q', '<cmd>q<CR>', { desc = 'Quit buffer' })
vim.keymap.set('n', '<leader>x', '<cmd>close<CR>', { desc = 'Close split' })

-- Move lines up and down
vim.keymap.set('n', '<M-j>', '<cmd>m .+1<CR>==', { desc = 'Move line down' })
vim.keymap.set('n', '<M-k>', '<cmd>m .-2<CR>==', { desc = 'Move line up' })

-- Navigate through buffers
vim.keymap.set('n', '<leader>p', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<leader>n', '<cmd>bnext<CR>', { desc = 'Next buffer' })

-- Git Blame
vim.keymap.set('n', '<leader>gb', '<cmd>Gitsigns blame_line<CR>', { desc = 'Toggle Git Blame' })

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
