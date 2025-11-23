return {
  'nvim-treesitter/nvim-treesitter-context',
  event = 'BufReadPre',
  config = function()
    require('treesitter-context').setup {
      enable = true,
      max_lines = 3,
    }
  end,
}
