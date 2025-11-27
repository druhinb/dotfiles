-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

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
--  Resize window relative to the direction of the key sent.
--  e.g. <leader>l will move the window separator to the right.
local function smart_resize(direction)
  local current_win = vim.api.nvim_get_current_win()
  local count = vim.v.count
  local default_step = 4
  local step = count > 0 and (count * default_step) or default_step

  -- Helper to check if there is a window in a direction
  local function has_neighbor(dir)
    vim.cmd('wincmd ' .. dir)
    local new_win = vim.api.nvim_get_current_win()
    if new_win ~= current_win then
      vim.api.nvim_set_current_win(current_win)
      return true
    end
    return false
  end

  if direction == 'h' then
    -- Left: Shrink if right neighbor exists, else grow
    if has_neighbor 'l' then
      vim.cmd('vertical resize -' .. step)
    else
      vim.cmd('vertical resize +' .. step)
    end
  elseif direction == 'l' then
    -- Right: Grow if right neighbor exists, else shrink
    if has_neighbor 'l' then
      vim.cmd('vertical resize +' .. step)
    else
      vim.cmd('vertical resize -' .. step)
    end
  elseif direction == 'j' then
    -- Down: Grow if neighbor below, else shrink
    if has_neighbor 'j' then
      vim.cmd('resize +' .. step)
    else
      vim.cmd('resize -' .. step)
    end
  elseif direction == 'k' then
    -- Up: Shrink if neighbor below, else grow
    if has_neighbor 'j' then
      vim.cmd('resize -' .. step)
    else
      vim.cmd('resize +' .. step)
    end
  end
end

vim.keymap.set('n', '<leader>h', function()
  smart_resize 'h'
end, { desc = 'Resize window left' })
vim.keymap.set('n', '<leader>j', function()
  smart_resize 'j'
end, { desc = 'Resize window down' })
vim.keymap.set('n', '<leader>k', function()
  smart_resize 'k'
end, { desc = 'Resize window up' })
vim.keymap.set('n', '<leader>l', function()
  smart_resize 'l'
end, { desc = 'Resize window right' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- User defined keymaps
vim.keymap.set('n', '<leader>ww', '<cmd>w<CR>', { desc = 'Save buffer' })
-- Removed conflicting <leader>q and <leader>x mappings to allow plugins to use them.
-- Replaced with <leader>= for closing split (Window Close) to avoid conflicts with <leader>c... chains
vim.keymap.set('n', '<leader>=', '<cmd>close<CR>', { desc = '[W]indow [C]lose split' })

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
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Prev [D]iagnostic' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Next [D]iagnostic' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show [E]rror messages' })

-- Map [[ and ]]
vim.keymap.set('n', '[[', '[[', { desc = 'Prev section start' })
vim.keymap.set('n', ']]', ']]', { desc = 'Next section start' })

-- Quickfix/Location list navigation
vim.keymap.set('n', '[q', '<cmd>cprevious<CR>', { desc = 'Prev [Q]uickfix item' })
vim.keymap.set('n', ']q', '<cmd>cnext<CR>', { desc = 'Next [Q]uickfix item' })
vim.keymap.set('n', '[Q', '<cmd>cfirst<CR>', { desc = 'First [Q]uickfix item' })
vim.keymap.set('n', ']Q', '<cmd>clast<CR>', { desc = 'Last [Q]uickfix item' })

vim.keymap.set('n', '[l', '<cmd>lprevious<CR>', { desc = 'Prev [L]ocation list item' })
vim.keymap.set('n', ']l', '<cmd>lnext<CR>', { desc = 'Next [L]ocation list item' })
vim.keymap.set('n', '[L', '<cmd>lfirst<CR>', { desc = 'First [L]ocation list item' })
vim.keymap.set('n', ']L', '<cmd>llast<CR>', { desc = 'Last [L]ocation list item' })

-- Tab navigation with descriptions
vim.keymap.set('n', '[t', '<cmd>tabprevious<CR>', { desc = 'Prev [T]ab' })
vim.keymap.set('n', ']t', '<cmd>tabnext<CR>', { desc = 'Next [T]ab' })
vim.keymap.set('n', '[T', '<cmd>tabfirst<CR>', { desc = 'First [T]ab' })
vim.keymap.set('n', ']T', '<cmd>tablast<CR>', { desc = 'Last [T]ab' })

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

-- Tab management
vim.keymap.set('n', '<leader>tn', '<cmd>tabnew<CR>', { desc = '[T]ab [N]ew' })
vim.keymap.set('n', '<leader>tc', '<cmd>tabclose<CR>', { desc = '[T]ab [C]lose' })
vim.keymap.set('n', '<leader>t1', '1gt', { desc = '[T]ab [1]' })
vim.keymap.set('n', '<leader>t2', '2gt', { desc = '[T]ab [2]' })
vim.keymap.set('n', '<leader>t3', '3gt', { desc = '[T]ab [3]' })
vim.keymap.set('n', '<leader>t4', '4gt', { desc = '[T]ab [4]' })
vim.keymap.set('n', '<leader>t5', '5gt', { desc = '[T]ab [5]' })
vim.keymap.set('n', '<leader>t6', '6gt', { desc = '[T]ab [6]' })
vim.keymap.set('n', '<leader>t7', '7gt', { desc = '[T]ab [7]' })
vim.keymap.set('n', '<leader>t8', '8gt', { desc = '[T]ab [8]' })
vim.keymap.set('n', '<leader>t9', '9gt', { desc = '[T]ab [9]' })
vim.keymap.set('n', '<leader>t0', '<cmd>tablast<CR>', { desc = '[T]ab Last [0]' })

-- vim: ts=2 sts=2 sw=2 et
