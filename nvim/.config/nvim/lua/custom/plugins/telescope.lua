-- Fallback picker for hosts where the `fzf` binary isn't installed (fzf-lua
-- covers everywhere else; see lua/search.lua for the detection logic).
local enabled = not require('search').has_fzf()

local function grep_visual(opts)
  local previous = vim.fn.getreg 'z'
  vim.cmd.normal { '"zy', bang = true }
  local selection = vim.fn.getreg 'z'
  vim.fn.setreg('z', previous)
  require('telescope.builtin').grep_string(vim.tbl_extend('force', opts or {}, { search = selection }))
end

return {
  'nvim-telescope/telescope.nvim',
  enabled = enabled,
  cmd = 'Telescope',
  dependencies = { 'nvim-lua/plenary.nvim', 'nvim-tree/nvim-web-devicons' },
  keys = {
    {
      '<leader><space>',
      function()
        require('telescope.builtin').find_files()
      end,
      desc = 'Find files',
    },
    {
      '<leader>ff',
      function()
        require('telescope.builtin').find_files()
      end,
      desc = 'Find files',
    },
    {
      '<leader>fF',
      function()
        require('telescope.builtin').find_files { cwd = vim.fn.expand '%:p:h' }
      end,
      desc = 'Find files in buffer directory',
    },
    {
      '<leader>fr',
      function()
        require('telescope.builtin').oldfiles()
      end,
      desc = 'Recent files',
    },
    {
      '<leader>fR',
      function()
        require('telescope.builtin').oldfiles { cwd_only = true }
      end,
      desc = 'Recent files in cwd',
    },
    {
      '<leader>fb',
      function()
        require('telescope.builtin').buffers()
      end,
      desc = 'Buffers',
    },
    {
      '<leader>fg',
      function()
        require('telescope.builtin').git_files()
      end,
      desc = 'Git files',
    },
    {
      '<leader>sg',
      function()
        require('telescope.builtin').live_grep()
      end,
      desc = 'Grep files',
    },
    {
      '<leader>sG',
      function()
        require('telescope.builtin').live_grep { cwd = vim.fn.expand '%:p:h' }
      end,
      desc = 'Grep buffer directory',
    },
    {
      '<leader>sw',
      function()
        require('telescope.builtin').grep_string()
      end,
      desc = 'Grep word',
    },
    {
      '<leader>sW',
      function()
        require('telescope.builtin').grep_string { cwd = vim.fn.expand '%:p:h' }
      end,
      desc = 'Grep word in buffer directory',
    },
    {
      '<leader>sw',
      grep_visual,
      mode = 'x',
      desc = 'Grep selection',
    },
    {
      '<leader>sW',
      function()
        grep_visual { cwd = vim.fn.expand '%:p:h' }
      end,
      mode = 'x',
      desc = 'Grep selection in buffer directory',
    },
    {
      '<leader>sb',
      function()
        require('telescope.builtin').current_buffer_fuzzy_find()
      end,
      desc = 'Buffer lines',
    },
    {
      '<leader>/',
      function()
        require('telescope.builtin').current_buffer_fuzzy_find()
      end,
      desc = 'Search buffer',
    },
    {
      '<leader>ss',
      function()
        require('telescope.builtin').builtin()
      end,
      desc = 'Search pickers',
    },
    {
      '<leader>sr',
      function()
        require('telescope.builtin').resume()
      end,
      desc = 'Resume search',
    },
    {
      '<leader>s"',
      function()
        require('telescope.builtin').registers()
      end,
      desc = 'Registers',
    },
    {
      '<leader>sa',
      function()
        require('telescope.builtin').autocommands()
      end,
      desc = 'Autocommands',
    },
    {
      '<leader>sc',
      function()
        require('telescope.builtin').command_history()
      end,
      desc = 'Command history',
    },
    {
      '<leader>sC',
      function()
        require('telescope.builtin').commands()
      end,
      desc = 'Commands',
    },
    {
      '<leader>sd',
      function()
        require('telescope.builtin').diagnostics { bufnr = 0 }
      end,
      desc = 'Buffer diagnostics',
    },
    {
      '<leader>sD',
      function()
        require('telescope.builtin').diagnostics()
      end,
      desc = 'Workspace diagnostics',
    },
    {
      '<leader>sh',
      function()
        require('telescope.builtin').help_tags()
      end,
      desc = 'Help pages',
    },
    {
      '<leader>sk',
      function()
        require('telescope.builtin').keymaps()
      end,
      desc = 'Keymaps',
    },
    {
      '<leader>sl',
      function()
        require('telescope.builtin').loclist()
      end,
      desc = 'Location list',
    },
    {
      '<leader>sm',
      function()
        require('telescope.builtin').marks()
      end,
      desc = 'Marks',
    },
    {
      '<leader>sq',
      function()
        require('telescope.builtin').quickfix()
      end,
      desc = 'Quickfix list',
    },
    {
      '<leader>st',
      function()
        require('telescope.builtin').colorscheme()
      end,
      desc = 'Colorschemes',
    },
    {
      '<leader>gfc',
      function()
        require('telescope.builtin').git_commits()
      end,
      desc = 'Find Git commits',
    },
    {
      '<leader>gfC',
      function()
        require('telescope.builtin').git_bcommits()
      end,
      desc = 'Find buffer commits',
    },
    {
      '<leader>gfS',
      function()
        require('telescope.builtin').git_stash()
      end,
      desc = 'Find Git stash',
    },
  },
  opts = {
    defaults = {
      winblend = 0,
      layout_strategy = 'flex',
      sorting_strategy = 'ascending',
    },
  },
  config = function(_, opts)
    require('telescope').setup(opts)
  end,
}
