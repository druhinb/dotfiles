local tooling = require 'tooling'

-- Per-buffer stack of the nodes `<C-space>` has selected, so `<BS>` can walk back down.
local selections = {}

local function in_visual()
  return vim.fn.mode():match '^[vV\22]' ~= nil
end

local function select_node(node)
  local start_row, start_col, end_row, end_col = node:range()
  -- a node ending at column 0 really ends at the last character of the line above
  if end_col == 0 and end_row > start_row then
    end_row = end_row - 1
    end_col = #(vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1] or '')
  end
  vim.fn.setpos("'<", { 0, start_row + 1, start_col + 1, 0 })
  vim.fn.setpos("'>", { 0, end_row + 1, math.max(end_col, 1), 0 })
  vim.cmd 'normal! gv'
end

local function node_for_selection()
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok or not parser then
    return nil
  end
  local from, to = vim.fn.getpos 'v', vim.fn.getpos '.'
  if from[2] > to[2] or (from[2] == to[2] and from[3] > to[3]) then
    from, to = to, from
  end
  return parser:named_node_for_range { from[2] - 1, from[3] - 1, to[2] - 1, to[3] }
end

local function same_range(a, b)
  local a1, a2, a3, a4 = a:range()
  local b1, b2, b3, b4 = b:range()
  return a1 == b1 and a2 == b2 and a3 == b3 and a4 == b4
end

local function grow_selection()
  local buf = vim.api.nvim_get_current_buf()
  local nodes = in_visual() and selections[buf] or nil

  if not nodes or #nodes == 0 then
    local node = in_visual() and node_for_selection() or vim.treesitter.get_node()
    if not node then
      return
    end
    selections[buf] = { node }
    return select_node(node)
  end

  local node = nodes[#nodes]
  local parent = node:parent()
  while parent and same_range(parent, node) do
    parent = parent:parent()
  end
  if not parent then
    return
  end
  nodes[#nodes + 1] = parent
  select_node(parent)
end

local function shrink_selection()
  local nodes = selections[vim.api.nvim_get_current_buf()]
  if not nodes or #nodes < 2 then
    return
  end
  table.remove(nodes)
  select_node(nodes[#nodes])
end

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    cmd = 'ToolingInstallTreesitter',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = {
      -- ships the textobjects queries that mini.ai's gen_spec.treesitter reads;
      -- nvim-treesitter's main branch no longer bundles them
      { 'nvim-treesitter/nvim-treesitter-textobjects', branch = 'main' },
    },
    config = function()
      require('nvim-treesitter').setup()

      vim.api.nvim_create_user_command('ToolingInstallTreesitter', function()
        vim.g.tooling_treesitter_install_ok = false
        local ok, installed = require('nvim-treesitter').install(tooling.treesitter, { summary = true }):pwait(1800000)
        if not ok or not installed then
          error 'Tree-sitter parser installation failed'
        end
        vim.g.tooling_treesitter_install_ok = true
      end, { desc = 'Install configured Tree-sitter parsers' })

      local function apply_folds(buf)
        if not vim.b[buf].treesitter_active then
          return
        end
        for _, win in ipairs(vim.fn.win_findbuf(buf)) do
          vim.wo[win].foldmethod = 'expr'
          vim.wo[win].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        end
      end

      local function start(buf)
        if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype == '' then
          return
        end
        -- snacks.bigfile rewrites the filetype to one with no parser, so this
        -- fails there and the buffer keeps manual folds and the Vim indent script
        if not pcall(vim.treesitter.start, buf) then
          return
        end
        vim.b[buf].treesitter_active = true
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        apply_folds(buf)
      end

      local group = vim.api.nvim_create_augroup('treesitter-highlight', { clear = true })
      vim.api.nvim_create_autocmd('FileType', {
        desc = 'Start Tree-sitter highlight, folds and indent for buffer',
        group = group,
        pattern = '*',
        callback = function(args)
          start(args.buf)
        end,
      })
      vim.api.nvim_create_autocmd('BufWinEnter', {
        desc = 'Apply Tree-sitter folds to a new window on the buffer',
        group = group,
        callback = function(args)
          apply_folds(args.buf)
        end,
      })
      vim.api.nvim_create_autocmd('BufUnload', {
        desc = 'Drop the incremental selection stack for the buffer',
        group = group,
        callback = function(args)
          selections[args.buf] = nil
        end,
      })
      start(vim.api.nvim_get_current_buf())

      vim.keymap.set({ 'n', 'x' }, '<C-space>', grow_selection, { desc = 'Grow selection to parent node' })
      vim.keymap.set('x', '<bs>', shrink_selection, { desc = 'Shrink selection to child node' })

      local ok, move = pcall(require, 'nvim-treesitter-textobjects.move')
      if ok then
        local jumps = {
          [']f'] = { move.goto_next_start, '@function.outer', 'Next Function' },
          ['[f'] = { move.goto_previous_start, '@function.outer', 'Prev Function' },
          [']F'] = { move.goto_next_end, '@function.outer', 'Next Function End' },
          ['[F'] = { move.goto_previous_end, '@function.outer', 'Prev Function End' },
        }
        for key, jump in pairs(jumps) do
          vim.keymap.set({ 'n', 'x', 'o' }, key, function()
            jump[1](jump[2], 'textobjects')
          end, { desc = jump[3] })
        end
      end
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
