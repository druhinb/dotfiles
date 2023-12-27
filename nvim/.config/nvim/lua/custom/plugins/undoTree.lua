return {
  'mbbill/undotree',
  config = function()
    -- Toggle the Undo Tree window
    vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle, { desc = 'Toggle [U]ndo Tree' })
  end,
}
