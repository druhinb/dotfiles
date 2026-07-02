return {
  {
    'echasnovski/mini.files',
    version = '*',
    enabled = function()
      return vim.fn.executable 'yazi' == 0
    end,
    opts = {
      windows = {
        preview = true,
        width_focus = 30,
        width_preview = 30,
      },
      options = {
        use_as_default_explorer = true,
      },
    },
    keys = {
      {
        '<leader>_',
        function()
          local bufname = vim.api.nvim_buf_get_name(0)
          local path = vim.fn.filereadable(bufname) == 1 and bufname or vim.fn.getcwd()
          require('mini.files').open(path)
        end,
        desc = 'Open mini.files at the current file',
      },
      {
        '<leader>cw',
        function()
          require('mini.files').open(vim.fn.getcwd())
        end,
        desc = "Open mini.files in nvim's working directory",
      },
    },
    config = function(_, opts)
      require('mini.files').setup(opts)

      -- Add a nice mapping in mini.files to close with ESC or q as well
      local files_augroup = vim.api.nvim_create_augroup('mini-files-custom', { clear = true })
      vim.api.nvim_create_autocmd('User', {
        group = files_augroup,
        pattern = 'MiniFilesBufferCreate',
        callback = function(args)
          local buf_id = args.data.buf_id
          vim.keymap.set('n', 'q', require('mini.files').close, { buffer = buf_id, desc = 'Close mini.files' })
          vim.keymap.set('n', '<Esc>', require('mini.files').close, { buffer = buf_id, desc = 'Close mini.files' })
        end,
      })
    end,
  },
}
