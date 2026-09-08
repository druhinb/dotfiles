-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.o.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
-- Schedule the setting after `UiEnter` because it can increase startup-time.
-- Remove this option if you want your OS clipboard to remain independent.
-- See `:help 'clipboard'`
local is_ssh = require('env').is_ssh

vim.schedule(function()
  if is_ssh then
    -- Use native OSC 52 if available (Neovim >= 0.10)
    local ok, osc52 = pcall(require, 'vim.ui.clipboard.osc52')
    if ok then
      vim.g.clipboard = {
        name = 'OSC 52',
        copy = {
          ['+'] = osc52.copy '+',
          ['*'] = osc52.copy '*',
        },
        -- paste queries the terminal and blocks waiting for stdin, which causes Neovim to hang
        -- indefinitely if the terminal blocks clipboard reads for security.
        -- We fall back to Neovim's internal register instead, completely avoiding network query hangs!
        paste = {
          ['+'] = function()
            return vim.fn.getreg('"', 1, true), vim.fn.getregtype '"'
          end,
          ['*'] = function()
            return vim.fn.getreg('"', 1, true), vim.fn.getregtype '"'
          end,
        },
      }
    else
      -- Fallback basic OSC 52 copy implementation for older Neovim versions
      local function osc52_copy(str)
        local base64 = vim.fn.base64_encode(str)
        local osc = string.format('\x1b]52;c;%s\x07', base64)
        vim.fn.chansend(vim.v.stderr, osc)
      end
      vim.g.clipboard = {
        name = 'OSC 52 Fallback',
        copy = {
          ['+'] = function(lines)
            osc52_copy(table.concat(lines, '\n'))
          end,
          ['*'] = function(lines)
            osc52_copy(table.concat(lines, '\n'))
          end,
        },
        paste = {
          ['+'] = function()
            return vim.fn.getreg('"', 1, true), vim.fn.getregtype '"'
          end,
          ['*'] = function()
            return vim.fn.getreg('"', 1, true), vim.fn.getregtype '"'
          end,
        },
      }
    end
  end
  vim.o.clipboard = 'unnamedplus'
end)

-- Enable break indent
vim.o.breakindent = true

-- Set internal shell to zsh if available
if vim.fn.executable '/bin/zsh' == 1 then
  vim.o.shell = '/bin/zsh'
end

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300
vim.o.ttimeout = true
vim.o.ttimeoutlen = 50 -- Fast keycode timeout for instant Escape key response over SSH

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--it
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-options-guide`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- Set tab settings to 4 spaces (user preference)
vim.opt.smartindent = true
vim.opt.autoindent = true

-- 'showmatch' parks the cursor on the match for 'matchtime' tenths of a second (500ms here)
-- every time a bracket is typed. The bundled matchparen plugin highlights the pair without moving.
vim.opt.showmatch = false

-- Keep the view when jumping back through the jumplist
vim.o.jumpoptions = 'view'

-- Scroll and wrap
vim.o.smoothscroll = true
vim.o.linebreak = true
vim.o.sidescrolloff = 8

-- Let visual block selections extend past end of line
vim.o.virtualedit = 'block'

vim.o.undolevels = 10000

-- Drop 'o' so pressing o/O below a comment does not continue the comment leader.
-- The ftplugins add it back per filetype, so this has to run after them.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('kickstart-formatoptions', { clear = true }),
  pattern = '*',
  callback = function()
    vim.opt_local.formatoptions:remove 'o'
  end,
})

-- persistence.nvim restores plugin state from 'globals'; 'skiprtp' keeps the
-- session from pinning a stale runtimepath
vim.opt.sessionoptions:append { 'globals', 'skiprtp' }

-- W: no "written" message, c: no ins-completion messages, C: no scanning messages
vim.opt.shortmess:append 'WcC'

vim.o.pumheight = 12
vim.o.splitkeep = 'screen'
vim.o.laststatus = 3

-- Tree-sitter drives 'foldexpr'; kickstart/plugins/treesitter.lua turns folding on
-- per window once a parser has attached, so parserless buffers keep manual folds.
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldtext = ''

local swap_dir = vim.fn.stdpath 'cache' .. '/swap'
vim.fn.mkdir(swap_dir, 'p')
vim.opt.directory = swap_dir
-- vim: ts=2 sts=2 sw=2 et
