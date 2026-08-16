return {
  'echasnovski/mini.indentscope',
  version = false, -- wait till new 0.7.0 release to put it back on semver
  event = { 'BufReadPost', 'BufNewFile' },
  opts = function()
    return {
      options = { try_as_border = true },
      -- the default animation waits 20ms per scope line before drawing it, and the scope
      -- is redrawn on every ModeChanged/CursorMoved: 400ms for a 20-line scope, 1s for 50.
      draw = { animation = require('mini.indentscope').gen_animation.none() },
    }
  end,
  init = function()
    vim.api.nvim_create_autocmd('FileType', {
      pattern = {
        'help',
        'alpha',
        'dashboard',
        'neo-tree',
        'Trouble',
        'trouble',
        'lazy',
        'mason',
        'notify',
        'toggleterm',
        'lazyterm',
      },
      callback = function()
        vim.b.miniindentscope_disable = true
      end,
    })
  end,
}
