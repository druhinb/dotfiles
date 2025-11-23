return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true }, -- Handle big files properly
    quickfile = { enabled = true }, -- Faster file opening
    statuscolumn = { enabled = true }, -- Better status column (git signs, folds)
    words = { enabled = true }, -- Auto-highlight word references (like vim-illuminate)
    
    -- "Tools" - Useful tools to have on hand
    lazygit = { enabled = false }, -- Best lazygit integration
    scratch = { enabled = true }, -- Scratch buffers
    terminal = { enabled = false }, -- Simple terminal toggle
    zen = { enabled = false }, -- Zen mode
    
    dashboard = { enabled = false }, 
    indent = { enabled = false }, 
    notifier = { enabled = false },
    picker = { enabled = false }, 
    input = { enabled = false },
    scope = { enabled = false },
    scroll = { enabled = false },
  },
  keys = {
    
    { '<leader>.', function() Snacks.scratch() end, desc = 'Toggle Scratch Buffer' },
    { '<leader>S', function() Snacks.scratch.select() end, desc = 'Select Scratch Buffer' },
    
    { '<leader>bd', function() Snacks.bufdelete() end, desc = 'Delete Buffer' },
    
    { ']]', function() Snacks.words.jump(vim.v.count1) end, desc = 'Next Reference', mode = { 'n', 't' } },
    { '[[', function() Snacks.words.jump(-vim.v.count1) end, desc = 'Prev Reference', mode = { 'n', 't' } },
  },
}
