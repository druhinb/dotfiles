--- Format only the lines that changed relative to a git base.
---
--- Whole-buffer formatting rewrites untouched code, which turns a two-line edit
--- into a large diff. This runs the buffer's formatter chain once, then applies
--- only the formatter hunks that overlap lines the working tree changed.
local M = {}

M.config = {
  base = 'HEAD',
  timeout_ms = 1500,
  git_timeout_ms = 500,
  merge_gap = 2,
}

local function resolve_buf(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function normalize(text)
  text = text:gsub('\r\n', '\n')
  if text ~= '' and not text:match '\n$' then
    text = text .. '\n'
  end
  return text
end

local function buf_text(bufnr)
  return normalize(table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, true), '\n'))
end

local function diff_indices(before, after)
  return vim.text.diff(before, after, { result_type = 'indices', algorithm = 'histogram' })
end

--- `git show` from the file's own directory, so no toplevel or relpath is needed.
--- Nil means the file has no base: untracked, renamed, outside a repo, or git timed out.
local function base_text(bufnr, base)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then
    return nil
  end
  local ok, result = pcall(function()
    local cmd = { 'git', '-C', vim.fs.dirname(name), 'show', base .. ':./' .. vim.fs.basename(name) }
    return vim.system(cmd, { text = true }):wait(M.config.git_timeout_ms)
  end)
  if not ok or result.code ~= 0 then
    return nil
  end
  return normalize(result.stdout)
end

--- Lines of `bufnr` that differ from `base`, as 1-based inclusive `{first, last}` pairs.
--- Nil means the whole buffer is new. An empty list means nothing changed.
---@return table[]|nil
function M.changed_ranges(bufnr, base)
  bufnr = resolve_buf(bufnr)
  local before = base_text(bufnr, base or M.config.base)
  if not before then
    return nil
  end
  local ranges = {}
  for _, hunk in ipairs(diff_indices(before, buf_text(bufnr))) do
    local _, _, first, count = unpack(hunk)
    if count > 0 then
      local previous = ranges[#ranges]
      if previous and first - previous[2] - 1 <= M.config.merge_gap then
        previous[2] = math.max(previous[2], first + count - 1)
      else
        ranges[#ranges + 1] = { first, first + count - 1 }
      end
    end
  end
  return ranges
end

local function overlapping(ranges, first, last)
  for _, range in ipairs(ranges) do
    if first <= range[2] and range[1] <= last then
      return range
    end
  end
end

--- Apply the formatter's hunks that overlap `ranges`, bottom-up so earlier edits
--- do not shift later line numbers. One synchronous pass, so one undo step.
local function apply_overlapping(bufnr, original, formatted, ranges)
  local before, after = normalize(table.concat(original, '\n')), normalize(table.concat(formatted, '\n'))
  -- black and friends emit nothing for excluded files; conform guards the same way
  if after:match '^%s*$' and not before:match '^%s*$' then
    return false
  end

  local edits = {}
  for _, hunk in ipairs(diff_indices(before, after)) do
    local first_a, count_a, first_b, count_b = unpack(hunk)
    local is_insert = count_a == 0
    local last_a = first_a + count_a
    if not is_insert and count_b > 0 then
      last_a = last_a - 1
    elseif is_insert then
      last_a = first_a + 1
    end
    local range = overlapping(ranges, first_a, last_a)
    if range then
      -- a formatter can split one rewrite into a delete and a separate insert at
      -- the same spot; reach one line past those so the partner is applied too.
      -- A replace hunk is self-contained, and extending past it would reformat
      -- the untouched line below.
      if is_insert or count_b == 0 then
        range[2] = math.max(range[2], last_a + 1)
      end
      local from = is_insert and first_a or first_a - 1
      edits[#edits + 1] = { from, from + count_a, vim.list_slice(formatted, first_b, first_b + count_b - 1) }
    end
  end

  for i = #edits, 1, -1 do
    vim.api.nvim_buf_set_lines(bufnr, edits[i][1], edits[i][2], true, edits[i][3])
  end
  return #edits > 0
end

--- Applying a subset of a formatter's hunks can split a change that spans more
--- than the changed lines, such as a call parenthesis opened inside the range and
--- closed below it. Nil means the buffer has no parser and cannot be checked.
---@return boolean|nil
local function has_syntax_error(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil
  end
  local parsed, trees = pcall(parser.parse, parser, true)
  if not parsed or not trees then
    return nil
  end
  for _, tree in ipairs(trees) do
    if tree:root():has_error() then
      return true
    end
  end
  return false
end

--- Filetypes with no CLI formatter go through textDocument/rangeFormatting, one
--- request per range. Returns false when no client offers it.
local function format_ranges_via_lsp(bufnr, ranges, opts)
  for i = #ranges, 1, -1 do
    local first, last = ranges[i][1], ranges[i][2]
    local last_line = vim.api.nvim_buf_get_lines(bufnr, last - 1, last, false)[1] or ''
    local attempted = require('conform').format {
      bufnr = bufnr,
      async = false,
      timeout_ms = opts.timeout_ms,
      lsp_format = 'fallback',
      quiet = opts.quiet,
      range = { start = { first, 0 }, ['end'] = { last, #last_line } },
    }
    if not attempted then
      return false
    end
  end
  return true
end

---@param opts? { base?: string, timeout_ms?: integer, quiet?: boolean }
function M.format_hunks(bufnr, opts)
  opts = opts or {}
  bufnr = resolve_buf(bufnr)
  local conform = require 'conform'
  local run = { timeout_ms = opts.timeout_ms or M.config.timeout_ms, quiet = opts.quiet ~= false }

  local function format_whole_buffer()
    return conform.format {
      bufnr = bufnr,
      async = false,
      timeout_ms = run.timeout_ms,
      lsp_format = 'fallback',
      quiet = run.quiet,
    }
  end

  local ranges = M.changed_ranges(bufnr, opts.base or M.config.base)
  if ranges == nil then
    return format_whole_buffer()
  elseif #ranges == 0 then
    return false
  end

  local formatters = conform.list_formatters_to_run(bufnr)
  if vim.tbl_isempty(formatters) then
    return format_ranges_via_lsp(bufnr, ranges, run) or format_whole_buffer()
  end

  local names = vim.tbl_map(function(formatter)
    return formatter.name
  end, formatters)
  local original = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  local was_parseable = has_syntax_error(bufnr) == false
  local _, formatted = conform.format_lines(names, original, {
    bufnr = bufnr,
    timeout_ms = run.timeout_ms,
    quiet = run.quiet,
  })
  if not formatted then
    return false
  end

  local applied = apply_overlapping(bufnr, original, formatted, ranges)
  if applied and was_parseable and has_syntax_error(bufnr) then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, original)
    vim.notify('Formatting this hunk alone would break syntax; run :Format for the whole buffer', vim.log.levels.WARN)
    return false
  end
  return applied
end

function M.setup_autocmd()
  vim.api.nvim_create_autocmd('BufWritePre', {
    group = vim.api.nvim_create_augroup('FormatHunksOnSave', { clear = true }),
    callback = function(args)
      if vim.bo[args.buf].buftype ~= '' then
        return
      end
      if vim.g.autoformat_enabled == false or vim.b[args.buf].autoformat_enabled == false then
        return
      end
      M.format_hunks(args.buf)
    end,
  })
end

return M
-- vim: ts=2 sts=2 sw=2 et
