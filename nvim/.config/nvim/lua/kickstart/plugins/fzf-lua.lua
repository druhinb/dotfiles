return {
  {
    'ibhagwan/fzf-lua',
    -- optional for icon support
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      -- calling `setup` is optional for customization
      local fzf = require 'fzf-lua'
      fzf.setup {
        'fzf-native',
        files = {
          previewer = 'builtin',
        },
        previewers = {
          builtin = {
            extensions = {
              ['png'] = { '/opt/homebrew/bin/chafa', '{file}' },
              ['jpg'] = { '/opt/homebrew/bin/chafa', '{file}' },
              ['jpeg'] = { '/opt/homebrew/bin/chafa', '{file}' },
              ['gif'] = { '/opt/homebrew/bin/chafa', '{file}' },
              ['webp'] = { '/opt/homebrew/bin/chafa', '{file}' },
              ['svg'] = { '/opt/homebrew/bin/chafa', '{file}' },
            },
          },
        },
      }

      -- Register fzf-lua as the UI select handler
      fzf.register_ui_select()

      -- Keymaps
      vim.keymap.set('n', '<leader>sh', fzf.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', fzf.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', fzf.files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', fzf.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', fzf.grep_cword, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', fzf.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', fzf.diagnostics_workspace, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', fzf.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', fzf.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', fzf.buffers, { desc = '[ ] Find existing buffers' })

      -- Slightly advanced example of overriding default behavior and theme
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        fzf.lgrep_curbuf()
      end, { desc = '[/] Fuzzily search in current buffer' })
    end,
  },
}
