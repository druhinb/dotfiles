return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup {
        options = {
          theme = 'everforest',
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
        },
        tabline = {
          lualine_a = {
            {
              'filename',
              path = 1, -- 1: Relative path, 2: Absolute path, 3: Absolute path, with tilde as the home directory
            },
          },
          lualine_z = { 'tabs' },
        },
      }
    end,
  },
}
