return {
  'stevearc/dressing.nvim',
  event = 'VeryLazy',
  opts = {
    input = {
      border = 'rounded',
      win_options = {
        winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder',
      },
    },
    select = {
      backend = { 'fzf_lua', 'builtin' },
      builtin = {
        border = 'rounded',
        win_options = {
          winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder',
        },
      },
    },
  },
}
