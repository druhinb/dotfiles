return {
  'johmsalas/text-case.nvim',
  keys = { 'ga' },
  config = function()
    require('textcase').setup {
      default_keymappings_enabled = false,
    }

    local tc = require 'textcase'

    -- Map keys manually to be operators
    local keys = {
      s = 'to_snake_case',
      c = 'to_camel_case',
      p = 'to_pascal_case',
      n = 'to_constant_case',
      d = 'to_dash_case',
      u = 'to_upper_case',
      l = 'to_lower_case',
      t = 'to_title_case',
      ['/'] = 'to_path_case',
    }

    for key, method in pairs(keys) do
      -- Operator mapping (e.g., gas + iw)
      vim.keymap.set('n', 'ga' .. key, function()
        tc.operator(method)
      end, { desc = 'Text Case Operator: ' .. method })

      -- Line mapping (e.g., gass)
      vim.keymap.set('n', 'ga' .. key .. key, function()
        tc.line(method)
      end, { desc = 'Text Case Line: ' .. method })

      -- Visual mode mapping
      vim.keymap.set('x', 'ga' .. key, function()
        tc.visual(method)
      end, { desc = 'Text Case Visual: ' .. method })
    end

    local methods = {
      ['Snake Case (snake_case)'] = 'gas',
      ['Pascal Case (PascalCase)'] = 'gap',
      ['Camel Case (camelCase)'] = 'gac',
      ['Constant Case (CONSTANT_CASE)'] = 'gan',
      ['Dash Case (dash-case)'] = 'gad',
      ['Title Case (Title Case)'] = 'gat',
      ['Path Case (path/case)'] = 'ga/',
    }

    local options = {}
    for k, _ in pairs(methods) do
      table.insert(options, k)
    end
    table.sort(options)

    vim.keymap.set('n', 'ga.', function()
      vim.ui.select(options, {
        prompt = 'Text Case> ',
      }, function(selected)
        if selected then
          local keys = methods[selected]
          if keys then
            -- Execute the operator on the current word (iw)
            local keys_to_feed = vim.api.nvim_replace_termcodes(keys .. 'iw', true, false, true)
            vim.api.nvim_feedkeys(keys_to_feed, 'm', false)
          end
        end
      end)
    end, { desc = 'Text Case Menu' })
  end,
}
