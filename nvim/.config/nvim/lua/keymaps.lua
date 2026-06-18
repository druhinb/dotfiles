-- ============================================================================
-- Global Keymaps - LazyVim Style
-- General editor keymaps (not plugin-specific)
-- Plugin-specific keymaps should be in their respective plugin specs
-- ============================================================================

local map = vim.keymap.set

-- ════════════════════════════════════════════════════════════════════════════
-- General Editor
-- ════════════════════════════════════════════════════════════════════════════

-- Clear search highlights with <Esc>
map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear highlights' })

-- Better escape from terminal
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
map('t', '<C-/>', '<cmd>close<cr>', { desc = 'Hide Terminal' })

-- Instantly pass Escape to remote/interactive terminal buffers (remote-nvim, SSH, standard terminal)
-- without capturing or waiting for exit terminal key sequences locally.
vim.api.nvim_create_autocmd('TermOpen', {
  group = vim.api.nvim_create_augroup('remote-terminal-escape', { clear = true }),
  pattern = 'term://*',
  callback = function(event)
    local bufname = vim.api.nvim_buf_get_name(event.buf)
    -- Keep toggleterm's local window-closing escape behavior, but for all other terminal
    -- buffers (ssh, remote-nvim, etc.), route Esc instantly to prevent local capture delays.
    if not bufname:find('toggleterm') then
      vim.keymap.set('t', '<Esc>', '<Esc>', { buffer = event.buf, nowait = true })
    end
  end,
})

-- Disable Space in normal/visual (leader key)
map({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- ════════════════════════════════════════════════════════════════════════════
-- Better Movement
-- ════════════════════════════════════════════════════════════════════════════

-- Move with wrap support
map('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = 'Move down' })
map('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = 'Move up' })
map('x', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = 'Move down' })
map('x', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = 'Move up' })

-- Better half-page scrolling (centered)
map('n', '<C-d>', '<C-d>zz', { desc = 'Scroll down half page' })
map('n', '<C-u>', '<C-u>zz', { desc = 'Scroll up half page' })

-- Keep cursor centered during search
map('n', 'n', 'nzzzv', { desc = 'Next search result' })
map('n', 'N', 'Nzzzv', { desc = 'Prev search result' })

-- ════════════════════════════════════════════════════════════════════════════
-- Move Lines (Alt + j/k)
-- ════════════════════════════════════════════════════════════════════════════

map('n', '<A-j>', '<cmd>m .+1<cr>==', { desc = 'Move line down' })
map('n', '<A-k>', '<cmd>m .-2<cr>==', { desc = 'Move line up' })
map('i', '<A-j>', '<esc><cmd>m .+1<cr>==gi', { desc = 'Move line down' })
map('i', '<A-k>', '<esc><cmd>m .-2<cr>==gi', { desc = 'Move line up' })
map('v', '<A-j>', ":m '>+1<cr>gv=gv", { desc = 'Move selection down' })
map('v', '<A-k>', ":m '<-2<cr>gv=gv", { desc = 'Move selection up' })

-- ════════════════════════════════════════════════════════════════════════════
-- Better Indenting
-- ════════════════════════════════════════════════════════════════════════════

map('v', '<', '<gv', { desc = 'Indent left' })
map('v', '>', '>gv', { desc = 'Indent right' })

-- ════════════════════════════════════════════════════════════════════════════
-- Windows
-- ════════════════════════════════════════════════════════════════════════════

-- Split windows (like tmux)
map('n', '<leader>|', '<cmd>vsplit<cr>', { desc = 'Split vertical' })
map('n', '<leader>-', '<cmd>split<cr>', { desc = 'Split horizontal' })
map('n', '<leader>wd', '<cmd>close<cr>', { desc = 'Close window' })

-- Navigate windows with Ctrl+hjkl
map('n', '<C-h>', '<C-w>h', { desc = 'Go to left window', remap = true })
map('n', '<C-j>', '<C-w>j', { desc = 'Go to lower window', remap = true })
map('n', '<C-k>', '<C-w>k', { desc = 'Go to upper window', remap = true })
map('n', '<C-l>', '<C-w>l', { desc = 'Go to right window', remap = true })

-- Smart window resize (relative to direction)
local function smart_resize(direction)
  local current_win = vim.api.nvim_get_current_win()
  local count = vim.v.count
  local default_step = 4
  local step = count > 0 and (count * default_step) or default_step

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
    if has_neighbor 'l' then
      vim.cmd('vertical resize -' .. step)
    else
      vim.cmd('vertical resize +' .. step)
    end
  elseif direction == 'l' then
    if has_neighbor 'l' then
      vim.cmd('vertical resize +' .. step)
    else
      vim.cmd('vertical resize -' .. step)
    end
  elseif direction == 'j' then
    if has_neighbor 'j' then
      vim.cmd('resize +' .. step)
    else
      vim.cmd('resize -' .. step)
    end
  elseif direction == 'k' then
    if has_neighbor 'j' then
      vim.cmd('resize -' .. step)
    else
      vim.cmd('resize +' .. step)
    end
  end
end

map('n', '<leader>h', function() smart_resize 'h' end, { desc = 'Resize left' })
map('n', '<leader>j', function() smart_resize 'j' end, { desc = 'Resize down' })
map('n', '<leader>k', function() smart_resize 'k' end, { desc = 'Resize up' })
map('n', '<leader>l', function() smart_resize 'l' end, { desc = 'Resize right' })

-- ════════════════════════════════════════════════════════════════════════════
-- Buffers
-- ════════════════════════════════════════════════════════════════════════════

-- Navigate through buffers (non-cyclic)
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

map('n', '<S-h>', function() buffer_navigate 'prev' end, { desc = 'Prev buffer' })
map('n', '<S-l>', function() buffer_navigate 'next' end, { desc = 'Next buffer' })
map('n', '[b', function() buffer_navigate 'prev' end, { desc = 'Prev buffer' })
map('n', ']b', function() buffer_navigate 'next' end, { desc = 'Next buffer' })

-- Buffer operations
map('n', '<leader>bb', '<cmd>e #<cr>', { desc = 'Switch to other buffer' })
map('n', '<leader>bd', '<cmd>bdelete<cr>', { desc = 'Delete buffer' })
map('n', '<leader>bD', '<cmd>bdelete!<cr>', { desc = 'Delete buffer (force)' })
map('n', '<leader>bn', '<cmd>bnext<cr>', { desc = 'Next buffer' })
map('n', '<leader>bp', '<cmd>bprevious<cr>', { desc = 'Prev buffer' })

-- ════════════════════════════════════════════════════════════════════════════
-- Save & Quit
-- ════════════════════════════════════════════════════════════════════════════

map('n', '<leader>ww', '<cmd>w<cr>', { desc = 'Save' })
map('n', '<leader>wa', '<cmd>wa<cr>', { desc = 'Save all' })
map('n', '<leader>wq', '<cmd>wq<cr>', { desc = 'Save and quit' })
map('n', '<leader>qq', '<cmd>qa<cr>', { desc = 'Quit all' })
map('n', '<leader>qQ', '<cmd>qa!<cr>', { desc = 'Quit all (force)' })

-- Quick save with Ctrl+s
map({ 'i', 'x', 'n', 's' }, '<C-s>', '<cmd>w<cr><esc>', { desc = 'Save file' })

-- ════════════════════════════════════════════════════════════════════════════
-- Tabs
-- ════════════════════════════════════════════════════════════════════════════

map('n', '<leader>tn', '<cmd>tabnew<cr>', { desc = 'New tab' })
map('n', '<leader>tc', '<cmd>tabclose<cr>', { desc = 'Close tab' })
map('n', '<leader>to', '<cmd>tabonly<cr>', { desc = 'Close other tabs' })
map('n', '[t', '<cmd>tabprevious<cr>', { desc = 'Prev tab' })
map('n', ']t', '<cmd>tabnext<cr>', { desc = 'Next tab' })
map('n', '[T', '<cmd>tabfirst<cr>', { desc = 'First tab' })
map('n', ']T', '<cmd>tablast<cr>', { desc = 'Last tab' })

-- Jump to tab by number
for i = 1, 9 do
  map('n', '<leader>t' .. i, i .. 'gt', { desc = 'Tab ' .. i })
end
map('n', '<leader>t0', '<cmd>tablast<cr>', { desc = 'Last tab' })

-- ════════════════════════════════════════════════════════════════════════════
-- Quickfix & Location List
-- ════════════════════════════════════════════════════════════════════════════

map('n', '[q', '<cmd>cprevious<cr>', { desc = 'Prev quickfix' })
map('n', ']q', '<cmd>cnext<cr>', { desc = 'Next quickfix' })
map('n', '[Q', '<cmd>cfirst<cr>', { desc = 'First quickfix' })
map('n', ']Q', '<cmd>clast<cr>', { desc = 'Last quickfix' })
map('n', '<leader>xq', '<cmd>copen<cr>', { desc = 'Quickfix list' })

map('n', '[l', '<cmd>lprevious<cr>', { desc = 'Prev location' })
map('n', ']l', '<cmd>lnext<cr>', { desc = 'Next location' })
map('n', '[L', '<cmd>lfirst<cr>', { desc = 'First location' })
map('n', ']L', '<cmd>llast<cr>', { desc = 'Last location' })
map('n', '<leader>xl', '<cmd>lopen<cr>', { desc = 'Location list' })

-- ════════════════════════════════════════════════════════════════════════════
-- Diagnostics
-- ════════════════════════════════════════════════════════════════════════════

local diagnostic_goto = function(next, severity)
  local go = next and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
  severity = severity and vim.diagnostic.severity[severity] or nil
  return function()
    go { severity = severity }
  end
end

map('n', ']d', diagnostic_goto(true), { desc = 'Next diagnostic' })
map('n', '[d', diagnostic_goto(false), { desc = 'Prev diagnostic' })
map('n', ']e', diagnostic_goto(true, 'ERROR'), { desc = 'Next error' })
map('n', '[e', diagnostic_goto(false, 'ERROR'), { desc = 'Prev error' })
map('n', ']w', diagnostic_goto(true, 'WARN'), { desc = 'Next warning' })
map('n', '[w', diagnostic_goto(false, 'WARN'), { desc = 'Prev warning' })
map('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Line diagnostics' })

-- ════════════════════════════════════════════════════════════════════════════
-- UI Toggles
-- ════════════════════════════════════════════════════════════════════════════

-- Toggle options
map('n', '<leader>uw', '<cmd>set wrap!<cr>', { desc = 'Toggle wrap' })
map('n', '<leader>us', '<cmd>set spell!<cr>', { desc = 'Toggle spell' })
map('n', '<leader>un', '<cmd>set number!<cr>', { desc = 'Toggle line numbers' })
map('n', '<leader>ur', '<cmd>set relativenumber!<cr>', { desc = 'Toggle relative numbers' })
map('n', '<leader>ul', '<cmd>set list!<cr>', { desc = 'Toggle list chars' })
map('n', '<leader>uc', '<cmd>set cursorline!<cr>', { desc = 'Toggle cursorline' })
map('n', '<leader>uC', '<cmd>set cursorcolumn!<cr>', { desc = 'Toggle cursorcolumn' })

-- Toggle diagnostics
local diagnostics_active = true
map('n', '<leader>ud', function()
  diagnostics_active = not diagnostics_active
  if diagnostics_active then
    vim.diagnostic.enable()
  else
    vim.diagnostic.disable()
  end
end, { desc = 'Toggle diagnostics' })

-- Toggle inlay hints (if available)
if vim.lsp.inlay_hint then
  map('n', '<leader>uh', function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
  end, { desc = 'Toggle inlay hints' })
end

-- ════════════════════════════════════════════════════════════════════════════
-- Miscellaneous
-- ════════════════════════════════════════════════════════════════════════════

-- Better paste in visual mode (don't yank replaced text)
map('x', 'p', '"_dP', { desc = 'Paste (no yank)' })

-- Add blank lines
map('n', ']<space>', 'o<Esc>k', { desc = 'Add blank line below' })
map('n', '[<space>', 'O<Esc>j', { desc = 'Add blank line above' })

-- Select all
map('n', '<C-a>', 'gg<S-v>G', { desc = 'Select all' })

-- Lazy plugin manager
map('n', '<leader>L', '<cmd>Lazy<cr>', { desc = 'Lazy' })

-- Section navigation (built-in)
map('n', '[[', '[[', { desc = 'Prev section start' })
map('n', ']]', ']]', { desc = 'Next section start' })

-- ════════════════════════════════════════════════════════════════════════════
-- Autocommands
-- ════════════════════════════════════════════════════════════════════════════

-- Highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Resize splits when window is resized
vim.api.nvim_create_autocmd('VimResized', {
  desc = 'Resize splits on window resize',
  group = vim.api.nvim_create_augroup('resize-splits', { clear = true }),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
  end,
})

-- Go to last location when opening a buffer
vim.api.nvim_create_autocmd('BufReadPost', {
  desc = 'Go to last location when opening a buffer',
  group = vim.api.nvim_create_augroup('last-location', { clear = true }),
  callback = function(event)
    local exclude = { 'gitcommit' }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
      return
    end
    vim.b[buf].lazyvim_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close some filetypes with <q>
vim.api.nvim_create_autocmd('FileType', {
  desc = 'Close with q',
  group = vim.api.nvim_create_augroup('close-with-q', { clear = true }),
  pattern = {
    'help',
    'lspinfo',
    'man',
    'notify',
    'qf',
    'query',
    'spectre_panel',
    'startuptime',
    'tsplayground',
    'checkhealth',
    'neotest-output',
    'neotest-summary',
    'neotest-output-panel',
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    map('n', 'q', '<cmd>close<cr>', { buffer = event.buf, silent = true })
  end,
})

-- Auto create dir when saving a file
vim.api.nvim_create_autocmd('BufWritePre', {
  desc = 'Auto create dir when saving a file',
  group = vim.api.nvim_create_augroup('auto-create-dir', { clear = true }),
  callback = function(event)
    if event.match:match '^%w%w+:[\\/][\\/]' then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
  end,
})

-- vim: ts=2 sts=2 sw=2 et

-- vim: ts=2 sts=2 sw=2 et
