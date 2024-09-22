return {
  'mbbill/undotree',
  config = function()
    -- Toggle the Undo Tree window
    vim.keymap.set('n', '<leader>uu', vim.cmd.UndotreeToggle, { desc = 'Toggle Undo Tree' })
  end,
}
