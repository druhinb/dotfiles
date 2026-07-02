local is_ssh = vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil

return {
  'lewis6991/satellite.nvim',
  enabled = not is_ssh,
  event = 'VeryLazy',
  config = function()
    require('satellite').setup {
      current_only = false,
      winblend = 50, -- Transparency for the bar
      zindex = 40,
      handlers = {
        cursor = {
          enable = true,
          -- You can change the symbol for the cursor position
          symbols = { '⎵' },
        },
        search = {
          enable = true,
        },
        diagnostic = {
          enable = true,
          signs = { '-', '=', '≡' }, -- Symbols for different severities
          min_severity = vim.diagnostic.severity.HINT,
        },
        gitsigns = {
          enable = true, -- Shows git diffs in the scrollbar
          signs = {
            add = '│',
            change = '│',
            delete = '-',
          },
        },
        marks = {
          enable = true,
          show_builtins = false, -- Only show your custom marks
        },
      },
    }
  end,
}
