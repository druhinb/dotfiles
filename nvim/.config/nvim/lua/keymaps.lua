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

-- TIP: Disable arrow keys in normal mode
vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
-- vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
-- vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
-- vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
-- vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Split windows like tmux
vim.keymap.set('n', '|', '<cmd>vsplit<CR>', { desc = 'Vertical Split' })
vim.keymap.set('n', '-', '<cmd>split<CR>', { desc = 'Horizontal Split' })

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

-- Switch to the last buffer (alternate file)
vim.keymap.set('n', '<leader>p', '<C-^>', { desc = 'Switch to [P]revious buffer' })

-- Diffview
vim.keymap.set('n', '<leader>dv', '<cmd>DiffviewOpen<CR>', { desc = 'Open Diffview' })
vim.keymap.set('n', '<leader>dc', '<cmd>DiffviewClose<CR>', { desc = 'Close Diffview' })
vim.keymap.set('n', '<leader>dfh', '<cmd>DiffviewFileHistory %<CR>', { desc = 'Diffview File History' })

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
