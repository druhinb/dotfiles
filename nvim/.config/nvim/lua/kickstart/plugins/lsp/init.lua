-- LSP Server Configurations
-- This module loads all LSP server configurations from language-specific files
-- Each file returns a table of server configurations for that language

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
    'java',
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
