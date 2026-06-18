-- Hardtime: train vim motions via hints and blockers
-- https://github.com/m4xshen/hardtime.nvim

local is_ssh = vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil

return {
  'm4xshen/hardtime.nvim',
  lazy = false,
  enabled = not is_ssh,
  dependencies = { 'MunifTanjim/nui.nvim' },
  opts = {},
}
