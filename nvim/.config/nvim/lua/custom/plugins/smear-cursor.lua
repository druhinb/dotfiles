local is_ssh = vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil

return {
  'sphamba/smear-cursor.nvim',
  enabled = not is_ssh,
  event = 'VeryLazy',
  opts = {
    -- stiffness/damping below the 0.6/0.45/0.85 defaults stretch the settle time on every
    -- cursor jump, including the one-column move out of insert mode. These overshoot it.
    stiffness = 0.85,
    trailing_stiffness = 0.75,
    damping = 0.9,

    -- stop a whole cell early; converging to 0.1 spends most of the animation on
    -- sub-cell motion that never renders differently
    distance_stop_animating = 1.0,

    smear_insert_mode = false,

    matrix_pixel_threshold = 0.3,
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
