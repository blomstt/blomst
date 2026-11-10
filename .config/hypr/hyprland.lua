
--       • •
--  ┓┏┓┏┓┓╋┓┏┓┏
--  ┗┗ ┛┗┗┗┗┗ ┛
--

-- Each require() runs in its own scope, so an error in one file does not stop the others.
-- Colours (user/colors.lua) and apps (user/apps.lua) are loaded by the files that use them.

-- Environment Variables
require("user.env")

-- Hardware
require("user.monitors")
require("user.inputs")

-- Design & Logic
require("core.appearence")
require("core.animations")
require("core.keybinds")
require("core.rules")
require("core.settings")

-- Applications (core/execs.lua also starts the user/execs.lua list)
require("core.execs")
require("user.app-rules")
require("user.float-sizes")
