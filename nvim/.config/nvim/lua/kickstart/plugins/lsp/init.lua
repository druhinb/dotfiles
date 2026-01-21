-- =============================================================================
-- LSP Server Configurations Loader (Legacy/Optional)
-- =============================================================================
-- NOTE: The main LSP configuration is now in lspconfig.lua with a centralized
-- servers table following LazyVim architecture. This module is kept for
-- backward compatibility if you prefer a modular approach.
--
-- To use this module instead of the centralized table:
-- 1. Comment out the `servers` table in lspconfig.lua
-- 2. Uncomment `local servers = require('kickstart.plugins.lsp').get_servers()`
-- =============================================================================

local M = {}

-- List of language configuration modules to load
local language_modules = {
  'c',
  'python',
  'typescript',
  'web',
  'rust',
  'lua',
  'markdown',
  'shell',
  'go',
  'docker',
  'config',
  'sql',
}

-- Load all server configurations from language modules
function M.get_servers()
  local servers = {}
  for _, lang in ipairs(language_modules) do
    local ok, lang_servers = pcall(require, 'kickstart.plugins.lsp.' .. lang)
    if ok then
      for server_name, config in pairs(lang_servers) do
        servers[server_name] = config
      end
    else
      vim.notify('Failed to load LSP config for language: ' .. lang, vim.log.levels.WARN)
    end
  end
  return servers
end

return M
