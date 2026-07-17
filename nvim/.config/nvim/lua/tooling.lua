local M = {}

-- Native LSP server name -> Mason package name.
-- Bundle-owned servers remain listed here so bootstrap installs the same tools
-- that the filetype-specific language specs expect.
M.lsp = {
  asm_lsp = 'asm-lsp',
  basedpyright = 'basedpyright',
  bashls = 'bash-language-server',
  clangd = 'clangd',
  cssls = 'css-lsp',
  docker_compose_language_service = 'docker-compose-language-service',
  dockerls = 'dockerfile-language-server',
  emmet_language_server = 'emmet-language-server',
  gopls = 'gopls',
  html = 'html-lsp',
  jdtls = 'jdtls',
  jsonls = 'json-lsp',
  ltex = 'ltex-ls',
  lua_ls = 'lua-language-server',
  marksman = 'marksman',
  roslyn = 'roslyn-language-server',
  ruff = 'ruff',
  rust_analyzer = 'rust-analyzer',
  sqlls = 'sqlls',
  svelte = 'svelte-language-server',
  tailwindcss = 'tailwindcss-language-server',
  taplo = 'taplo',
  vtsls = 'vtsls',
  yamlls = 'yaml-language-server',
}

M.formatters = {
  'clang-format',
  'csharpier',
  'gofumpt',
  'goimports',
  'google-java-format',
  'prettierd',
  'shfmt',
  'stylua',
}

M.formatters_by_ft = {
  lua = { 'stylua' },
  c = { 'clang-format' },
  cpp = { 'clang-format' },
  python = { 'ruff_organize_imports', 'ruff_format' },
  javascript = { 'prettierd', 'prettier', stop_after_first = true },
  typescript = { 'prettierd', 'prettier', stop_after_first = true },
  javascriptreact = { 'prettierd', 'prettier', stop_after_first = true },
  typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
  html = { 'prettierd', 'prettier', stop_after_first = true },
  css = { 'prettierd', 'prettier', stop_after_first = true },
  scss = { 'prettierd', 'prettier', stop_after_first = true },
  less = { 'prettierd', 'prettier', stop_after_first = true },
  cs = { 'csharpier' },
  rust = { 'rustfmt', lsp_format = 'fallback' },
  java = { 'google-java-format' },
  json = { 'prettierd', 'prettier', stop_after_first = true },
  jsonc = { 'prettierd', 'prettier', stop_after_first = true },
  yaml = { 'prettierd', 'prettier', stop_after_first = true },
  markdown = { 'prettierd', 'prettier', stop_after_first = true },
  markdown_inline = { 'prettierd', 'prettier', stop_after_first = true },
  go = { 'goimports', 'gofumpt' },
  sh = { 'shfmt' },
  bash = { 'shfmt' },
  zsh = { 'shfmt' },
  toml = { 'taplo' },
  sql = { 'sqlfluff' },
  mysql = { 'sqlfluff' },
  plsql = { 'sqlfluff' },
}

M.linters = {
  'cpplint',
  'eslint_d',
  'golangci-lint',
  'hadolint',
  'markdownlint',
  'shellcheck',
  'sqlfluff',
  'yamllint',
}

M.linters_by_ft = {
  c = { 'cpplint' },
  cpp = { 'cpplint' },
  javascript = { 'eslint_d' },
  typescript = { 'eslint_d' },
  javascriptreact = { 'eslint_d' },
  typescriptreact = { 'eslint_d' },
  go = { 'golangcilint' },
  sh = { 'shellcheck' },
  bash = { 'shellcheck' },
  zsh = { 'shellcheck' },
  markdown = { 'markdownlint' },
  yaml = { 'yamllint' },
  dockerfile = { 'hadolint' },
  sql = { 'sqlfluff' },
  mysql = { 'sqlfluff' },
  plsql = { 'sqlfluff' },
}

M.dap = {
  'codelldb',
  'debugpy',
  'delve',
  'js-debug-adapter',
  'netcoredbg',
}

M.dap_adapters = {
  'codelldb',
  'coreclr',
  'delve',
  'js',
  'python',
}

M.test_tools = {
  'java-debug-adapter',
  'java-test',
}

M.runtime_tools = {
  'tree-sitter-cli',
}

-- These servers are configured by filetype-specific plugin bundles. Keeping
-- Mason's automatic enablement away from them prevents duplicate clients.
M.bundle_servers = {
  'clangd',
  'jdtls',
  'roslyn',
  -- mason-lspconfig maps roslyn-language-server to nvim-lspconfig's
  -- `roslyn_ls`; roslyn.nvim owns the separate `roslyn` config.
  'roslyn_ls',
  'tailwindcss',
  'vtsls',
}

M.treesitter = {
  'bash',
  'c',
  'c_sharp',
  'cpp',
  'css',
  'diff',
  'dockerfile',
  'doxygen',
  'go',
  'html',
  'java',
  'javascript',
  'json',
  'json5',
  'lua',
  'luadoc',
  'markdown',
  'markdown_inline',
  'python',
  'query',
  'rust',
  'scss',
  'sql',
  'svelte',
  'toml',
  'tsx',
  'typescript',
  'vim',
  'vimdoc',
  'yaml',
}

M.languages = {
  python = {
    lsp = { 'basedpyright', 'ruff' },
    format = { 'ruff' },
    dap = { 'debugpy' },
    test = { 'pytest' },
  },
  typescript = {
    lsp = { 'vtsls', 'tailwindcss', 'html', 'cssls', 'emmet_language_server' },
    format = { 'prettierd' },
    lint = { 'eslint_d' },
    dap = { 'js-debug-adapter' },
    test = { 'jest', 'vitest' },
  },
  cpp = {
    lsp = { 'clangd' },
    format = { 'clang-format' },
    lint = { 'cpplint' },
    dap = { 'codelldb' },
    workflow = { 'cmake' },
  },
  rust = {
    lsp = { 'rust_analyzer' },
    format = { 'rustfmt' },
    lint = { 'clippy' },
    dap = { 'codelldb' },
    test = { 'cargo test' },
  },
  go = {
    lsp = { 'gopls' },
    format = { 'goimports', 'gofumpt' },
    lint = { 'golangci-lint' },
    dap = { 'delve' },
    test = { 'go test' },
  },
  java = {
    lsp = { 'jdtls' },
    format = { 'google-java-format' },
    dap = { 'java-debug-adapter' },
    test = { 'java-test' },
  },
  csharp = {
    lsp = { 'roslyn' },
    format = { 'csharpier' },
    dap = { 'netcoredbg' },
    test = { 'dotnet test' },
  },
  config = {
    lsp = { 'lua_ls', 'bashls', 'jsonls', 'yamlls', 'taplo', 'dockerls', 'docker_compose_language_service', 'sqlls' },
    format = { 'stylua', 'shfmt', 'prettierd', 'taplo', 'sqlfluff' },
    lint = { 'shellcheck', 'markdownlint', 'yamllint', 'hadolint', 'sqlfluff' },
  },
}

function M.mason_package_installed(package)
  local package_dir = vim.fn.stdpath 'data' .. '/mason/packages/' .. package
  return vim.fn.filereadable(package_dir .. '/mason-receipt.json') == 1
end

function M.mason_packages()
  local packages = {}
  local seen = {}

  local function add(package)
    if not seen[package] then
      seen[package] = true
      table.insert(packages, package)
    end
  end

  for _, package in pairs(M.lsp) do
    add(package)
  end
  for _, category in ipairs { M.formatters, M.linters, M.dap, M.test_tools, M.runtime_tools } do
    for _, package in ipairs(category) do
      add(package)
    end
  end

  table.sort(packages)
  return packages
end

return M
