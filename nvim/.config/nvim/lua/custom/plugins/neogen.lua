return {
  'danymat/neogen',
  dependencies = 'nvim-treesitter/nvim-treesitter',
  config = true, -- Enables default setup
  -- Uncomment the below to customize languages if defaults aren't enough:
  -- opts = { snippet_engine = "luasnip" },
  keys = {
    {
      '<leader>nf',
      function()
        require('neogen').generate()
      end,
      desc = '[N]eogen [F]unction (Generate Docs)',
    },
  },
}
