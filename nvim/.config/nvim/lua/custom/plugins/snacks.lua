return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true }, -- Handle big files properly
    quickfile = { enabled = true }, -- Faster file opening
    statuscolumn = { enabled = true }, -- Better status column (git signs, folds)
    words = { enabled = false }, -- Native LSP document highlighting owns this.

    -- "Tools" - Useful tools to have on hand
    lazygit = { enabled = true }, -- Best lazygit integration
    scratch = { enabled = true }, -- Scratch buffers
    terminal = { enabled = false }, -- Simple terminal toggle
    zen = { enabled = false }, -- Zen mode

    dashboard = { enabled = false },
    indent = {
      enabled = true,
      indent = {
        enabled = true,
        char = '┊',
        only_scope = false,
      },
      -- mini.indentscope remains the stronger current-scope indicator.
      scope = { enabled = false },
      chunk = { enabled = false },
      animate = { enabled = false },
    },
    notifier = { enabled = false },
    picker = { enabled = false },
    input = { enabled = false },
    scope = { enabled = false },
    scroll = { enabled = false },
  },
  keys = {
    -- LazyGit
    {
      '<leader>gg',
      function()
        Snacks.lazygit()
      end,
      desc = 'Lazygit',
    },

    -- Scratch Buffer
    {
      '<leader>.',
      function()
        Snacks.scratch()
      end,
      desc = 'Toggle Scratch Buffer',
    },
    {
      '<leader>S',
      function()
        Snacks.scratch.select()
      end,
      desc = 'Select Scratch Buffer',
    },

    -- Better Buffer Delete (keeps layout intact)
    {
      '<leader>bd',
      function()
        Snacks.bufdelete()
      end,
      desc = 'Delete Buffer',
    },
    {
      '<leader>bD',
      function()
        Snacks.bufdelete { force = true }
      end,
      desc = 'Delete Buffer (force)',
    },
  },
}
