-- Git-Conflict: An easier way to manage merge conflicts
-- https://github.com/akinsho/git-conflict.nvim

return {
  'akinsho/git-conflict.nvim',
  version = '*',
  config = function()
    require('git-conflict').setup {
      default_mappings = true,
      default_commands = true,
      disable_diagnostics = true,
      list_opener = 'copen',
      highlights = {
        incoming = 'DiffText',
        current = 'DiffAdd',
      },
    }
  end,
}
