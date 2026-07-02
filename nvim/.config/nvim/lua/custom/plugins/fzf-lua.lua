local enabled = require('search').has_fzf()

return {
  'ibhagwan/fzf-lua',
  enabled = enabled,
  cmd = 'FzfLua',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  keys = {
    {
      '<leader><space>',
      function()
        require('fzf-lua').files()
      end,
      desc = 'Find files',
    },
    {
      '<leader>ff',
      function()
        require('fzf-lua').files()
      end,
      desc = 'Find files',
    },
    {
      '<leader>fF',
      function()
        require('fzf-lua').files { cwd = vim.fn.expand '%:p:h' }
      end,
      desc = 'Find files in buffer directory',
    },
    {
      '<leader>fr',
      function()
        require('fzf-lua').oldfiles()
      end,
      desc = 'Recent files',
    },
    {
      '<leader>fR',
      function()
        require('fzf-lua').oldfiles { cwd = vim.uv.cwd() }
      end,
      desc = 'Recent files in cwd',
    },
    {
      '<leader>fb',
      function()
        require('fzf-lua').buffers()
      end,
      desc = 'Buffers',
    },
    {
      '<leader>fg',
      function()
        require('fzf-lua').git_files()
      end,
      desc = 'Git files',
    },
    {
      '<leader>sg',
      function()
        require('fzf-lua').live_grep()
      end,
      desc = 'Grep files',
    },
    {
      '<leader>sG',
      function()
        require('fzf-lua').live_grep { cwd = vim.fn.expand '%:p:h' }
      end,
      desc = 'Grep buffer directory',
    },
    {
      '<leader>sw',
      function()
        require('fzf-lua').grep_cword()
      end,
      desc = 'Grep word',
    },
    {
      '<leader>sW',
      function()
        require('fzf-lua').grep_cword { cwd = vim.fn.expand '%:p:h' }
      end,
      desc = 'Grep word in buffer directory',
    },
    {
      '<leader>sw',
      function()
        require('fzf-lua').grep_visual()
      end,
      mode = 'x',
      desc = 'Grep selection',
    },
    {
      '<leader>sW',
      function()
        require('fzf-lua').grep_visual { cwd = vim.fn.expand '%:p:h' }
      end,
      mode = 'x',
      desc = 'Grep selection in buffer directory',
    },
    {
      '<leader>sb',
      function()
        require('fzf-lua').lgrep_curbuf()
      end,
      desc = 'Buffer lines',
    },
    {
      '<leader>/',
      function()
        require('fzf-lua').lgrep_curbuf()
      end,
      desc = 'Search buffer',
    },
    {
      '<leader>ss',
      function()
        require('fzf-lua').builtin()
      end,
      desc = 'Search pickers',
    },
    {
      '<leader>sr',
      function()
        require('fzf-lua').resume()
      end,
      desc = 'Resume search',
    },
    {
      '<leader>s"',
      function()
        require('fzf-lua').registers()
      end,
      desc = 'Registers',
    },
    {
      '<leader>sa',
      function()
        require('fzf-lua').autocmds()
      end,
      desc = 'Autocommands',
    },
    {
      '<leader>sc',
      function()
        require('fzf-lua').command_history()
      end,
      desc = 'Command history',
    },
    {
      '<leader>sC',
      function()
        require('fzf-lua').commands()
      end,
      desc = 'Commands',
    },
    {
      '<leader>sd',
      function()
        require('fzf-lua').diagnostics_document()
      end,
      desc = 'Buffer diagnostics',
    },
    {
      '<leader>sD',
      function()
        require('fzf-lua').diagnostics_workspace()
      end,
      desc = 'Workspace diagnostics',
    },
    {
      '<leader>sh',
      function()
        require('fzf-lua').help_tags()
      end,
      desc = 'Help pages',
    },
    {
      '<leader>sk',
      function()
        require('fzf-lua').keymaps()
      end,
      desc = 'Keymaps',
    },
    {
      '<leader>sl',
      function()
        require('fzf-lua').loclist()
      end,
      desc = 'Location list',
    },
    {
      '<leader>sm',
      function()
        require('fzf-lua').marks()
      end,
      desc = 'Marks',
    },
    {
      '<leader>sq',
      function()
        require('fzf-lua').quickfix()
      end,
      desc = 'Quickfix list',
    },
    {
      '<leader>st',
      function()
        require('fzf-lua').colorschemes()
      end,
      desc = 'Colorschemes',
    },
    {
      '<leader>gfc',
      function()
        require('fzf-lua').git_commits()
      end,
      desc = 'Find Git commits',
    },
    {
      '<leader>gfC',
      function()
        require('fzf-lua').git_bcommits()
      end,
      desc = 'Find buffer commits',
    },
    {
      '<leader>gfS',
      function()
        require('fzf-lua').git_stash()
      end,
      desc = 'Find Git stash',
    },
  },
  opts = {
    'fzf-native',
    global_resume = true,
    global_resume_query = true,
    winopts = {
      height = 0.85,
      width = 0.80,
      border = 'rounded',
      preview = { layout = 'flex', flip_columns = 120 },
    },
    keymap = {
      builtin = {
        ['<C-d>'] = 'preview-page-down',
        ['<C-u>'] = 'preview-page-up',
      },
      fzf = {
        ['ctrl-a'] = 'toggle-all',
        ['ctrl-q'] = 'select-all+accept',
      },
    },
    files = {
      fd_opts = '--color=never --type f --hidden --follow --exclude .git',
      rg_opts = '--color=never --files --hidden --follow -g "!.git"',
    },
    grep = {
      rg_opts = '--column --line-number --no-heading --color=always --smart-case --hidden -g "!.git" -e',
    },
  },
  config = function(_, opts)
    require('fzf-lua').setup(opts)
    require('fzf-lua').register_ui_select()
  end,
}
