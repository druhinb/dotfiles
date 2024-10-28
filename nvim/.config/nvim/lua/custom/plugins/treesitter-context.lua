return {
  'nvim-treesitter/nvim-treesitter-context',
  event = 'BufReadPre',
  config = function()
    require('treesitter-context').setup {
      enable = true,
      max_lines = 3, -- How many lines to show at the top
      trim_scope = 'outer',
      patterns = {
        -- Match all languages
        default = {
          'class',
          'function',
          'method',
          'for', -- Show for loops
          'while', -- Show while loops
          'if', -- Show if statements
          'switch',
          'case',
        },
      },
    }
  end,
}
