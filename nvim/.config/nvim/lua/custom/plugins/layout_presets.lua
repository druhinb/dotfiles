local function get_valid_buffers()
  local buffers = {}
  local current_win = vim.api.nvim_get_current_win()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  
  -- Get buffers from all windows in current tab
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    -- Only include normal buffers
    if vim.bo[buf].buftype == '' then
      table.insert(buffers, buf)
    end
  end
  return buffers
end

local function apply_layout(type)
  local buffers = get_valid_buffers()
  local count = #buffers
  if count < 2 then
    vim.notify("Need at least 2 buffers for a layout", vim.log.levels.WARN)
    return
  end

  -- Save current buffer to restore focus later if possible
  local current_buf = vim.api.nvim_get_current_buf()

  -- Close all other windows
  vim.cmd('only')
  
  -- Reset the first window to the first buffer
  vim.api.nvim_win_set_buf(0, buffers[1])

  if type == 'columns' then
    -- | | |
    for i = 2, count do
      vim.cmd('vsplit')
      vim.api.nvim_win_set_buf(0, buffers[i])
    end
    vim.cmd('wincmd =') -- Equalize

  elseif type == 'rows' then
    -- _ _ _
    for i = 2, count do
      vim.cmd('split')
      vim.api.nvim_win_set_buf(0, buffers[i])
    end
    vim.cmd('wincmd =')

  elseif type == 'main_left' then
    -- | =
    -- First window is already set to buffers[1]
    vim.cmd('vsplit') -- Create right split
    local right_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(right_win, buffers[2])
    
    -- Split the rest in the right column
    for i = 3, count do
      vim.cmd('split')
      vim.api.nvim_win_set_buf(0, buffers[i])
    end
    vim.cmd('wincmd =')

  elseif type == 'main_top' then
    -- T shape
    vim.cmd('split') -- Create bottom split
    local bottom_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(bottom_win, buffers[2])
    
    -- Split the rest in the bottom row
    for i = 3, count do
      vim.cmd('vsplit')
      vim.api.nvim_win_set_buf(0, buffers[i])
    end
    vim.cmd('wincmd =')
    
  elseif type == 'grid' then
    -- 2x2 or similar
    if count == 4 then
      -- Win 1 (Top Left)
      vim.cmd('vsplit') -- Right (Top Right)
      vim.api.nvim_win_set_buf(0, buffers[2])
      
      vim.cmd('split') -- Bottom Right
      vim.api.nvim_win_set_buf(0, buffers[4])
      
      vim.cmd('wincmd h') -- Go Left
      vim.cmd('split') -- Bottom Left
      vim.api.nvim_win_set_buf(0, buffers[3])
    else
       -- Fallback to columns for non-4
       apply_layout('columns')
       return
    end
    vim.cmd('wincmd =')
  end

  -- Try to restore focus to the buffer we were on
  local win_ids = vim.api.nvim_tabpage_list_wins(0)
  for _, win in ipairs(win_ids) do
    if vim.api.nvim_win_get_buf(win) == current_buf then
      vim.api.nvim_set_current_win(win)
      break
    end
  end
end

-- Keymaps
vim.keymap.set('n', '<leader>Lc', function() apply_layout('columns') end, { desc = 'Layout: Columns' })
vim.keymap.set('n', '<leader>Lr', function() apply_layout('rows') end, { desc = 'Layout: Rows' })
vim.keymap.set('n', '<leader>Lm', function() apply_layout('main_left') end, { desc = 'Layout: Main Left' })
vim.keymap.set('n', '<leader>Lt', function() apply_layout('main_top') end, { desc = 'Layout: Main Top' })
vim.keymap.set('n', '<leader>Lg', function() apply_layout('grid') end, { desc = 'Layout: Grid (4)' })

return {}