return {

  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'

      -- Global toggle for cpplint
      vim.g.cpplint_enabled = true
      vim.keymap.set('n', '<leader>tl', function()
        vim.g.cpplint_enabled = not vim.g.cpplint_enabled
        print('cpplint ' .. (vim.g.cpplint_enabled and 'enabled' or 'disabled'))
        if vim.g.cpplint_enabled then
          lint.try_lint()
        else
          vim.diagnostic.reset(nil, 0)
        end
      end, { desc = 'Toggle cpplint' })

      local function is_linter_runnable(linter)
        if vim.fn.executable(linter) ~= 1 then
          return false
        end
        -- Special check for python/node linters on SSH/remote environments where
        -- the binary might exist (e.g. copied or in mason) but the interpreter is missing.
        if linter == 'cpplint' then
          return vim.fn.executable('python3') == 1 or vim.fn.executable('python') == 1
        elseif linter == 'eslint_d' then
          return vim.fn.executable('node') == 1
        end
        return true
      end

      local configured_linters = {
        c = { 'cpplint' },
        cpp = { 'cpplint' },
        javascript = { 'eslint_d' },
        typescript = { 'eslint_d' },
        javascriptreact = { 'eslint_d' },
        typescriptreact = { 'eslint_d' },
      }

      lint.linters_by_ft = {}
      for ft, ft_linters in pairs(configured_linters) do
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

      -- To allow other plugins to add linters to require('lint').linters_by_ft,
      -- instead set linters_by_ft like this:
      -- lint.linters_by_ft = lint.linters_by_ft or {}
      -- lint.linters_by_ft['markdown'] = { 'markdownlint' }
      --
      -- However, note that this will enable a set of default linters,
      -- which will cause errors unless these tools are available:
      -- {
      --   clojure = { "clj-kondo" },
      --   dockerfile = { "hadolint" },
      --   inko = { "inko" },
      --   janet = { "janet" },
      --   json = { "jsonlint" },
      --   markdown = { "vale" },
      --   rst = { "vale" },
      --   ruby = { "ruby" },
      --   terraform = { "tflint" },
      --   text = { "vale" }
      -- }
      --
      -- You can disable the default linters by setting their filetypes to nil:
      -- lint.linters_by_ft['clojure'] = nil
      -- lint.linters_by_ft['dockerfile'] = nil
      -- lint.linters_by_ft['inko'] = nil
      -- lint.linters_by_ft['janet'] = nil
      -- lint.linters_by_ft['json'] = nil
      -- lint.linters_by_ft['markdown'] = nil
      -- lint.linters_by_ft['rst'] = nil
      -- lint.linters_by_ft['ruby'] = nil
      -- lint.linters_by_ft['terraform'] = nil
      -- lint.linters_by_ft['text'] = nil

      -- Create autocommand which carries out the actual linting
      -- on the specified events.
      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          -- Only run the linter in buffers that you can modify in order to
          -- avoid superfluous noise, notably within the handy LSP pop-ups that
          -- describe the hovered symbol using Markdown.
          if vim.bo.modifiable then
            local linters = lint.get_running()
            if #linters == 0 or vim.g.cpplint_enabled then
              lint.try_lint()
            end
          end
        end,
      })
    end,
  },
}
