return {
  'chrisgrieser/nvim-rip-substitute',
  cmd = 'RipSubstitute',
  keys = {
    {
      '<leader>rf',
      function()
        require('rip-substitute').sub()
      end,
      mode = { 'n', 'x' },
      desc = '[R]eplace in [F]ile (rip-substitute)',
    },
  },
}
