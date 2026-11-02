require("variables")
require("keybindings")
require("hardware")
require("beautification")
require("autostart")
local ok, hs = pcall(require, "hyprshell_colors")
if ok and hs and hs.apply then hs.apply() end
