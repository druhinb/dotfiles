local is_ssh = vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil

return {
  'sphamba/smear-cursor.nvim',
  enabled = not is_ssh,
  event = 'VeryLazy',
  opts = {
    -- Physics: High damping prevents the "bounce"
    stiffness = 0.55,
    trailing_stiffness = 0.3,
    damping = 0.8, -- Higher damping stops the overshooting

    -- Smoothness: Lower threshold for sub-pixel stops
    distance_stop_animating = 0.1, -- Finish the move fully to avoid stutters

    -- Mode Control
    smear_insert_mode = false, -- No animation while typing

    -- Technical
    matrix_pixel_threshold = 0.3, -- Lower values can help smoothness on high-DPI
  },
} -- Faster Smear
--  opts = {                                -- Default  Range
--   stiffness = 0.8,                      -- 0.6      [0, 1]
--   trailing_stiffness = 0.6,             -- 0.45     [0, 1]
--   stiffness_insert_mode = 0.7,          -- 0.5      [0, 1]
--   trailing_stiffness_insert_mode = 0.7, -- 0.5      [0, 1]
--   damping = 0.95,                       -- 0.85     [0, 1]
--   damping_insert_mode = 0.95,           -- 0.9      [0, 1]
--   distance_stop_animating = 0.5,        -- 0.1      > 0
-- },
