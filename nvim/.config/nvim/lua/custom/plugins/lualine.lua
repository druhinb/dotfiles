return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local function git_sync_status()
        local handle = io.popen 'git rev-list --count --left-right @{u}...HEAD 2>/dev/null'
        if not handle then
          return ''
        end
        local result = handle:read '*a'
        handle:close()

        if not result or result == '' then
          return ''
        end

        local behind, ahead = result:match '(%d+)%s+(%d+)'
        if not behind then
          return ''
        end

        local status = {}
        if tonumber(ahead) > 0 then
          table.insert(status, '⇡' .. ahead)
        end
        if tonumber(behind) > 0 then
          table.insert(status, '⇣' .. behind)
        end

        return table.concat(status, ' ')
      end

      require('lualine').setup {
        options = {
          theme = 'kanagawa',
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
          globalstatus = true,
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', git_sync_status, 'diff', 'diagnostics' },
          lualine_c = {
            {
              'filename',
              path = 1, -- 1: Relative path
            },
          },
          lualine_x = {
            'encoding',
            'fileformat',
            'filetype',
          },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
        tabline = {
          lualine_z = { 'tabs' },
        },
      }
    end,
  },
}
