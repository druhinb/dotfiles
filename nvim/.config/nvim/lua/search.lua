local M = {}

local is_ssh = vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil

function M.has_fzf()
  return not is_ssh and vim.fn.executable 'fzf' == 1
end

local function open_file(path)
  if path and path ~= '' then
    vim.cmd.edit(vim.fn.fnameescape(path))
  end
end

function M.files(opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.uv.cwd()
  local prefix = cwd == vim.uv.cwd() and '' or (cwd .. '/')
  open_file(vim.fn.input('Edit file: ', prefix, 'file'))
end

function M.oldfiles()
  local items = vim.tbl_filter(function(path)
    return vim.fn.filereadable(path) == 1
  end, vim.v.oldfiles)
  vim.ui.select(items, { prompt = 'Recent files' }, open_file)
end

function M.buffers()
  local items = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buflisted then
      table.insert(items, {
        bufnr = bufnr,
        label = vim.api.nvim_buf_get_name(bufnr) ~= '' and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':~:.') or '[No Name]',
      })
    end
  end
  vim.ui.select(items, {
    prompt = 'Buffers',
    format_item = function(item)
      return item.label
    end,
  }, function(item)
    if item then
      vim.api.nvim_set_current_buf(item.bufnr)
    end
  end)
end

local function quickfix(lines, title)
  vim.fn.setqflist({}, ' ', {
    title = title,
    lines = lines,
    efm = '%f:%l:%c:%m',
  })
  if #vim.fn.getqflist() > 0 then
    vim.cmd.copen()
  else
    vim.notify('No matches found', vim.log.levels.INFO)
  end
end

function M.grep(opts)
  opts = opts or {}
  if vim.fn.executable 'rg' == 0 then
    vim.notify('Live grep fallback requires ripgrep', vim.log.levels.WARN)
    return
  end
  local query = opts.query or vim.fn.input 'Grep: '
  if query == '' then
    return
  end
  local cwd = opts.cwd or vim.uv.cwd()
  local lines = vim.fn.systemlist { 'rg', '--vimgrep', '--smart-case', '--hidden', '--glob', '!.git', query, cwd }
  quickfix(lines, ('rg: %s'):format(query))
end

function M.grep_word(opts)
  opts = vim.tbl_extend('force', opts or {}, { query = vim.fn.expand '<cword>' })
  M.grep(opts)
end

function M.grep_visual(opts)
  local previous = vim.fn.getreg 'z'
  vim.cmd.normal { '"zy', bang = true }
  local selection = vim.fn.getreg 'z'
  vim.fn.setreg('z', previous)
  opts = vim.tbl_extend('force', opts or {}, { query = selection })
  M.grep(opts)
end

function M.buffer_lines()
  local query = vim.fn.input 'Buffer search: '
  if query == '' then
    return
  end
  local pattern = vim.fn.escape(query, '/\\')
  vim.cmd(('silent vimgrep /%s/gj %%'):format(pattern))
  if #vim.fn.getqflist() > 0 then
    vim.cmd.copen()
  else
    vim.notify('No matches found', vim.log.levels.INFO)
  end
end

function M.help()
  local tag = vim.fn.input('Help: ', '', 'help')
  if tag ~= '' then
    vim.cmd.help(tag)
  end
end

function M.keymaps()
  vim.cmd 'filter /./ map'
end

function M.document_diagnostics()
  vim.diagnostic.setqflist { bufnr = 0, open = true, title = 'Buffer diagnostics' }
end

function M.workspace_diagnostics()
  vim.diagnostic.setqflist { open = true, title = 'Workspace diagnostics' }
end

function M.quickfix()
  vim.cmd.copen()
end

function M.loclist()
  vim.cmd.lopen()
end

function M.lsp_references()
  vim.lsp.buf.references()
end

function M.lsp_document_symbols()
  vim.lsp.buf.document_symbol()
end

function M.lsp_workspace_symbols()
  local query = vim.fn.input 'Workspace symbol: '
  if query ~= '' then
    vim.lsp.buf.workspace_symbol(query)
  end
end

function M.setup_fallback_keymaps()
  local map = vim.keymap.set
  map('n', '<leader><space>', M.files, { desc = 'Find files (native)' })
  map('n', '<leader>ff', M.files, { desc = 'Find files (native)' })
  map('n', '<leader>fF', function()
    M.files { cwd = vim.fn.expand '%:p:h' }
  end, { desc = 'Find files in buffer directory' })
  map('n', '<leader>fr', M.oldfiles, { desc = 'Recent files' })
  map('n', '<leader>fb', M.buffers, { desc = 'Buffers' })
  map('n', '<leader>fg', function()
    M.files { cwd = vim.fs.root(0, '.git') or vim.uv.cwd() }
  end, { desc = 'Find Git files' })
  map('n', '<leader>sg', M.grep, { desc = 'Grep files' })
  map('n', '<leader>sG', function()
    M.grep { cwd = vim.fn.expand '%:p:h' }
  end, { desc = 'Grep buffer directory' })
  map('n', '<leader>sw', M.grep_word, { desc = 'Grep word' })
  map('n', '<leader>sW', function()
    M.grep_word { cwd = vim.fn.expand '%:p:h' }
  end, { desc = 'Grep word in buffer directory' })
  map('x', '<leader>sw', M.grep_visual, { desc = 'Grep selection' })
  map('n', '<leader>sb', M.buffer_lines, { desc = 'Buffer lines' })
  map('n', '<leader>/', M.buffer_lines, { desc = 'Search buffer' })
  map('n', '<leader>sh', M.help, { desc = 'Help pages' })
  map('n', '<leader>sk', M.keymaps, { desc = 'Keymaps' })
  map('n', '<leader>sd', M.document_diagnostics, { desc = 'Buffer diagnostics' })
  map('n', '<leader>sD', M.workspace_diagnostics, { desc = 'Workspace diagnostics' })
  map('n', '<leader>sq', M.quickfix, { desc = 'Quickfix list' })
  map('n', '<leader>sl', M.loclist, { desc = 'Location list' })
end

return M
