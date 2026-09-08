-- Hardtime: train vim motions via hints and blockers
-- https://github.com/m4xshen/hardtime.nvim

local is_ssh = require('env').is_ssh

return {
  'm4xshen/hardtime.nvim',
  event = 'VeryLazy',
  enabled = not is_ssh,
  dependencies = { 'MunifTanjim/nui.nvim' },
  opts = {},
}
