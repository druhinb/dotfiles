--[[
--
-- This file is not required for your own configuration,
-- but helps people determine if their system is setup correctly.
--
--]]

local tooling = require 'tooling'

local function check_version()
  local version = vim.version()
  if vim.version.ge(version, { 0, 11, 0 }) then
    vim.health.ok(('Neovim %s supports the native 0.11+ LSP API'):format(tostring(version)))
  else
    vim.health.error(('Neovim %s is unsupported; install Neovim 0.11 or newer'):format(tostring(version)))
  end
end

local function check_executables()
  for _, exe in ipairs { 'git', 'make', 'unzip', 'rg' } do
    if vim.fn.executable(exe) == 1 then
      vim.health.ok(("Found executable '%s'"):format(exe))
    else
      vim.health.warn(("Missing executable '%s'"):format(exe))
    end
  end
  if require('search').has_fzf() then
    vim.health.ok 'fzf-lua is available'
  else
    vim.health.info 'fzf is unavailable or this is an SSH session; native search fallbacks will be used'
  end
end

local function mason_installed(package)
  return tooling.mason_package_installed(package)
end

local function tool_installed(name)
  local package = tooling.lsp[name] or name
  local executable = name:match '^([^ ]+)'
  return mason_installed(package) or vim.fn.executable(executable) == 1
end

local function check_languages()
  for language, groups in pairs(tooling.languages) do
    local missing = {}
    for group, tools in pairs(groups) do
      for _, tool in ipairs(tools) do
        if not tool_installed(tool) then
          table.insert(missing, ('%s:%s'):format(group, tool))
        end
      end
    end
    if #missing == 0 then
      vim.health.ok(('%s tooling is available'):format(language))
    else
      table.sort(missing)
      vim.health.warn(('%s is missing %s'):format(language, table.concat(missing, ', ')))
    end
  end
end

local function check_treesitter()
  local missing = {}
  for _, parser in ipairs(tooling.treesitter) do
    if #vim.api.nvim_get_runtime_file('parser/' .. parser .. '.*', false) == 0 then
      table.insert(missing, parser)
    end
  end
  if #missing == 0 then
    vim.health.ok 'Tree-sitter parser coverage matches the language matrix'
  else
    vim.health.warn('Missing Tree-sitter parsers: ' .. table.concat(missing, ', '))
  end
end

return {
  check = function()
    vim.health.start 'kickstart.nvim language platform'

    local uv = vim.uv or vim.loop
    vim.health.info('System Information: ' .. vim.inspect(uv.os_uname()))

    check_version()
    check_executables()
    check_languages()
    check_treesitter()
    vim.health.info 'Bootstrap tools with :MasonToolsInstallSync and parsers with :ToolingInstallTreesitter'
  end,
}
