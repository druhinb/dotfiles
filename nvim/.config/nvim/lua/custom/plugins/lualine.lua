local colors = {
  bg = '#181818',
  fg = '#CCCCCC',
  blue = '#0078d4',
  green = '#98c379',
  purple = '#c678dd',
  red = '#e06c75',
  yellow = '#e5c07b',
  grey = '#3E3E3E',
}

local onedark_modern = {
  normal = {
    a = { fg = colors.fg, bg = colors.blue, gui = 'bold' },
    b = { fg = colors.fg, bg = colors.grey },
    c = { fg = colors.fg, bg = colors.bg },
  },
  insert = {
    a = { fg = '#1F1F1F', bg = colors.green, gui = 'bold' },
    b = { fg = colors.fg, bg = colors.grey },
    c = { fg = colors.fg, bg = colors.bg },
  },
  visual = {
    a = { fg = '#1F1F1F', bg = colors.purple, gui = 'bold' },
    b = { fg = colors.fg, bg = colors.grey },
    c = { fg = colors.fg, bg = colors.bg },
  },
  replace = {
    a = { fg = '#1F1F1F', bg = colors.red, gui = 'bold' },
    b = { fg = colors.fg, bg = colors.grey },
    c = { fg = colors.fg, bg = colors.bg },
  },
  command = {
    a = { fg = '#1F1F1F', bg = colors.yellow, gui = 'bold' },
    b = { fg = colors.fg, bg = colors.grey },
    c = { fg = colors.fg, bg = colors.bg },
  },
  inactive = {
    a = { fg = colors.fg, bg = colors.bg },
    b = { fg = colors.fg, bg = colors.bg },
    c = { fg = colors.fg, bg = colors.bg },
  },
}

local bright_colors = {
  added = '#a5e075',
  modified = '#f0a45d',
  removed = '#ff616e',
}

return {
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local navic = require 'nvim-navic'

      -- 1. SETUP NAVIC
      -- We disable the built-in depth limit because we will handle filtering manually
      navic.setup {
        depth_limit = 0,
        icons = {
          File = ' ',
          Module = ' ',
          Namespace = ' ',
          Package = ' ',
          Class = ' ',
          Method = ' ',
          Property = ' ',
          Field = ' ',
          Constructor = ' ',
          Enum = ' ',
          Interface = ' ',
          Function = '󰊕 ',
          Variable = ' ',
          Constant = ' ',
          String = ' ',
          Number = ' ',
          Boolean = ' ',
          Array = ' ',
          Object = ' ',
          Key = ' ',
          Null = ' ',
          EnumMember = ' ',
          Struct = ' ',
          Event = ' ',
          Operator = ' ',
          TypeParameter = ' ',
        },
      }

      -- 2. CUSTOM NAVIC COMPONENT
      -- This function filters out "noise" (variables, indexes) and returns a clean path
      local function custom_navic()
        if not navic.is_available() then
          return ''
        end

        -- Get the raw data (table of symbols)
        local data = navic.get_data()
        local result = {}

        -- List of symbol types we WANT to see.
        -- We exclude: Variable, Constant, String, Number, Boolean, Array, Object, Key, Null
        local allow_list = {
          ['File'] = true,
          ['Module'] = true,
          ['Namespace'] = true,
          ['Package'] = true,
          ['Class'] = true,
          ['Method'] = true,
          ['Property'] = true,
          ['Constructor'] = true,
          ['Field'] = true,
          ['Interface'] = true,
          ['Function'] = true,
          ['Struct'] = true,
          ['Event'] = true,
          ['Enum'] = true,
        }

        for _, loc in ipairs(data) do
          -- Only add the symbol if it's in our allow list
          if allow_list[loc.type] then
            table.insert(result, loc.icon .. loc.name)
          end
        end

        -- If we are too deep (more than 3 relevant items), collapse the middle
        -- e.g. Class > ... > Method
        if #result > 3 then
          return table.concat({ result[1], '...', result[#result] }, ' > ')
        end

        return table.concat(result, ' > ')
      end

      -- Your Git Function
      local is_ssh = vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil
      local function git_sync_status()
        if is_ssh then
          return ''
        end
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
          theme = onedark_modern,
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
          globalstatus = true,
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = {
            'branch',
            {
              'diff',
              colored = true,
              diff_color = {
                added = { fg = bright_colors.added, gui = 'bold' },
                modified = { fg = bright_colors.modified, gui = 'bold' },
                removed = { fg = bright_colors.removed, gui = 'bold' },
              },
              symbols = { added = '+', modified = '~', removed = '-' },
            },
          },
          lualine_c = {
            {
              'filename',
              file_status = true,
              newfile_status = false,
              path = 1,

              fmt = function(str)
                local path_separator = package.config:sub(1, 1)
                local parts = vim.split(str, path_separator)

                if #parts > 4 then
                  return '...' .. path_separator .. table.concat({ unpack(parts, #parts - 2, #parts) }, path_separator)
                end

                return str
              end,
            },
            {
              custom_navic,
              cond = function()
                return navic.is_available()
              end,
              color = { fg = '#e5c07b', gui = 'italic' },
            },
          },
          lualine_x = {
            {
              git_sync_status,
              color = { fg = '#61afef', gui = 'bold' },
            },
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
