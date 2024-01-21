local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

config.color_scheme = "kanagawabones"

config.font = wezterm.font("JetBrainsMono Nerd Font Mono")
config.font_size = 19

config.enable_tab_bar = false

config.window_decorations = "RESIZE"

config.window_background_opacity = 0.98
config.macos_window_background_blur = 40

-- and finally, return the configuration to wezterm
return config
