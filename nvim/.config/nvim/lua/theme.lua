-- persists the active colorscheme and restores it at startup. keyed off the
-- ColorScheme event, so bare :colorscheme and picker previews persist too.

local M = {}

M.default = 'gruvbox-material'

local state_file = vim.fs.joinpath(vim.fn.stdpath 'state', 'colorscheme')
local persisted

local function read_state()
  local ok, lines = pcall(vim.fn.readfile, state_file)
  if ok and lines[1] and lines[1] ~= '' then
    return lines[1]
  end
end

local function persist(name)
  if name and name ~= persisted then
    persisted = name
    pcall(vim.fn.writefile, { name }, state_file)
  end
end

-- modus reports colors_name "modus" for both its light and dark variants and
-- never touches `background`, so plugins reading that option draw a dark
-- palette on the light theme.
local function sync_background()
  local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
  if not normal.bg then
    return
  end
  local r = math.floor(normal.bg / 65536) % 256
  local g = math.floor(normal.bg / 256) % 256
  local b = normal.bg % 256
  local want = (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5 and 'light' or 'dark'
  if vim.o.background ~= want then
    vim.o.background = want
  end
end

function M.list()
  return vim.fn.getcompletion('', 'color')
end

function M.apply(name)
  local ok = pcall(vim.cmd.colorscheme, name)
  if not ok then
    vim.notify(('colorscheme %q is not installed'):format(name), vim.log.levels.WARN)
  end
  return ok
end

function M.pick()
  local search = require 'search'
  if search.has_fzf() then
    require('fzf-lua').colorschemes()
  elseif search.has_telescope() then
    require('telescope.builtin').colorscheme { enable_preview = true }
  else
    vim.ui.select(M.list(), { prompt = 'Colorscheme' }, function(choice)
      if choice then
        M.apply(choice)
      end
    end)
  end
end

function M.setup()
  persisted = read_state()

  -- setting `background` re-sources the colorscheme, and the nested event
  -- reports the plugin's own colors_name; persisting that breaks the round trip
  local syncing = false
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('theme-persist', { clear = true }),
    callback = function(args)
      if syncing then
        return
      end
      syncing = true
      sync_background()
      syncing = false
      persist(args.match)
    end,
  })

  local target = persisted or M.default
  if not M.apply(target) and target ~= M.default then
    M.apply(M.default)
  end

  vim.api.nvim_create_user_command('Theme', function(opts)
    if opts.args == '' then
      M.pick()
    else
      M.apply(opts.args)
    end
  end, { nargs = '?', complete = 'color', desc = 'Switch colorscheme' })
end

return M

-- vim: ts=2 sts=2 sw=2 et
