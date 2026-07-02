local tooling = require 'tooling'

return {

  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPost', 'BufNewFile' },
    cmd = { 'Lint', 'LintToggle' },
    keys = {
      { '<leader>uL', '<cmd>LintToggle<cr>', desc = 'Toggle linting' },
    },
    config = function()
      local lint = require 'lint'

      vim.g.lint_enabled = vim.g.lint_enabled ~= false
      vim.api.nvim_create_user_command('Lint', function()
        lint.try_lint()
      end, { desc = 'Lint current buffer' })
      vim.api.nvim_create_user_command('LintToggle', function()
        vim.g.lint_enabled = not vim.g.lint_enabled
        vim.notify(('Linting %s'):format(vim.g.lint_enabled and 'enabled' or 'disabled'))
        if vim.g.lint_enabled then
          lint.try_lint()
        else
          for _, names in pairs(lint.linters_by_ft) do
            for _, name in ipairs(names) do
              vim.diagnostic.reset(lint.get_namespace(name), 0)
            end
          end
        end
      end, { desc = 'Toggle automatic linting' })

      local function is_linter_runnable(linter)
        local definition = lint.linters[linter]
        local command = type(definition) == 'table' and definition.cmd or linter
        if type(command) == 'function' then
          command = command()
        end
        if type(command) ~= 'string' or vim.fn.executable(command) ~= 1 then
          return false
        end
        if linter == 'cpplint' then
          return vim.fn.executable 'python3' == 1 or vim.fn.executable 'python' == 1
        elseif linter == 'eslint_d' then
          return vim.fn.executable 'node' == 1
        end
        return true
      end

      lint.linters_by_ft = {}
      for ft, ft_linters in pairs(tooling.linters_by_ft) do
        local active_linters = {}
        for _, linter in ipairs(ft_linters) do
          if is_linter_runnable(linter) then
            table.insert(active_linters, linter)
          end
        end
        if #active_linters > 0 then
          lint.linters_by_ft[ft] = active_linters
        end
      end

      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          if vim.g.lint_enabled and vim.bo.modifiable then
            lint.try_lint()
          end
        end,
      })
    end,
  },
}
