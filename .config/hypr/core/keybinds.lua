-- Keybinds
-- Blomst Settings lists these on its Keybinds page: under the comment above them, with their desc.

local apps = require("user.apps")
local mainMod = "SUPER" -- Sets "Windows" key as main modifier
local osd = "~/.config/eww/scripts/osd.sh"

-- Close Active Apps
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { desc = "Close window" })

-- Window Keybinds
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), { desc = "Float or tile window" })
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen(), { desc = "Fullscreen" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { desc = "Switch split direction" })

-- Open App Launcher
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(apps.menu), { desc = apps.menu })

-- Terminal Emulator
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(apps.terminal), { desc = apps.terminal })
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(apps.terminal, { float = true, size = { 700, 600 } }), { desc = apps.terminal .. " (floating)" })

-- Open Yazi
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("sh ~/scripts/open_yazi.sh"), { desc = "Yazi" })
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("sh ~/scripts/open_yazi.sh", { float = true, size = { 525, 260 } }), { desc = "Yazi (floating)" })

-- Open Power Menu
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("sh ~/scripts/power_management.sh"), { desc = "Power menu" })

-- Open Browser
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(apps.browser), { desc = apps.browser })

-- EWW Stuff
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("sh ~/scripts/select_wallpaper.sh"), { desc = "Pick a wallpaper" })
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("sh ~/scripts/launch_widgets.sh"), { desc = "Show or hide the widgets" })
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("sh ~/scripts/launch.sh"), { desc = "Restart the side bar" })

-- Settings window
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("python ~/blomst/settings/main.py"), { desc = "Blomst Settings" })

-- Task manager
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("python ~/blomst/settings/main.py --tasks"), { desc = "Task manager" })

-- Reload Hyprpaper
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("sh ~/scripts/hyprpaper_reload.sh"), { desc = "Reload the wallpaper" })

-- Screen Shot
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m output -o ~/Pictures/Screenshots"), { desc = "Screenshot of the screen" })
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots"), { desc = "Screenshot of a region" })
-- Screenshot you can draw on
hl.bind(mainMod .. " + CTRL + PRINT", hl.dsp.exec_cmd("~/scripts/screenshot_edit.sh"), { desc = "Screenshot to draw on" })

-- Clipboard history
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("~/scripts/clipboard.sh"), { desc = "Clipboard history" })

-- Colour picker
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("~/scripts/color_picker.sh"), { desc = "Colour picker" })

-- Window focus
hl.bind("ALT + h", hl.dsp.focus({ direction = "left" }), { desc = "Focus left" })
hl.bind("ALT + i", hl.dsp.focus({ direction = "right" }), { desc = "Focus right" })
hl.bind("ALT + k", hl.dsp.focus({ direction = "up" }), { desc = "Focus up" })
hl.bind("ALT + j", hl.dsp.focus({ direction = "down" }), { desc = "Focus down" })

-- Move Window
hl.bind("ALT + SHIFT + h", hl.dsp.window.move({ direction = "left" }), { desc = "Move window left" })
hl.bind("ALT + SHIFT + i", hl.dsp.window.move({ direction = "right" }), { desc = "Move window right" })
hl.bind("ALT + SHIFT + k", hl.dsp.window.move({ direction = "up" }), { desc = "Move window up" })
hl.bind("ALT + SHIFT + j", hl.dsp.window.move({ direction = "down" }), { desc = "Move window down" })

-- Resize Window
hl.bind(mainMod .. " + ALT + h", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { desc = "Resize window -40 0" })
hl.bind(mainMod .. " + ALT + i", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { desc = "Resize window 40 0" })
hl.bind(mainMod .. " + ALT + k", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { desc = "Resize window 0 -40" })
hl.bind(mainMod .. " + ALT + j", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { desc = "Resize window 0 40" })

-- Move Floating Window
hl.bind(mainMod .. " + CTRL + h", hl.dsp.window.move({ x = -40, y = 0, relative = true }), { repeating = true, desc = "Move floating window -40 0" })
hl.bind(mainMod .. " + CTRL + i", hl.dsp.window.move({ x = 40, y = 0, relative = true }), { repeating = true, desc = "Move floating window 40 0" })
hl.bind(mainMod .. " + CTRL + k", hl.dsp.window.move({ x = 0, y = -40, relative = true }), { repeating = true, desc = "Move floating window 0 -40" })
hl.bind(mainMod .. " + CTRL + j", hl.dsp.window.move({ x = 0, y = 40, relative = true }), { repeating = true, desc = "Move floating window 0 40" })

-- Volume and Media Control
-- (each shows the on-screen pop-up; holding a key repeats)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(osd .. " volume up"), { repeating = true, desc = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(osd .. " volume down"), { repeating = true, desc = "Volume down" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(osd .. " mic mute"), { desc = "Mute microphone" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(osd .. " volume mute"), { desc = "Mute" })

-- Brightness Control
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(osd .. " brightness up"), { repeating = true, desc = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(osd .. " brightness down"), { repeating = true, desc = "Brightness down" })

-- Switch workspaces with mainMod + [0-9]
-- 1-5 are per monitor (see ~/scripts/workspace.sh); 6-0 always mean the second monitor's 1-5
hl.bind(mainMod .. " + 1", hl.dsp.exec_cmd("~/scripts/workspace.sh go 1"), { desc = "Go to workspace 1" })
hl.bind(mainMod .. " + 2", hl.dsp.exec_cmd("~/scripts/workspace.sh go 2"), { desc = "Go to workspace 2" })
hl.bind(mainMod .. " + 3", hl.dsp.exec_cmd("~/scripts/workspace.sh go 3"), { desc = "Go to workspace 3" })
hl.bind(mainMod .. " + 4", hl.dsp.exec_cmd("~/scripts/workspace.sh go 4"), { desc = "Go to workspace 4" })
hl.bind(mainMod .. " + 5", hl.dsp.exec_cmd("~/scripts/workspace.sh go 5"), { desc = "Go to workspace 5" })
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }), { desc = "Go to workspace 6" })
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }), { desc = "Go to workspace 7" })
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }), { desc = "Go to workspace 8" })
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }), { desc = "Go to workspace 9" })
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }), { desc = "Go to workspace 10" })

-- Move active window to a workspace with mainMod + SHIFT + [0-9]
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.exec_cmd("~/scripts/workspace.sh move 1"), { desc = "Send window to workspace 1" })
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.exec_cmd("~/scripts/workspace.sh move 2"), { desc = "Send window to workspace 2" })
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.exec_cmd("~/scripts/workspace.sh move 3"), { desc = "Send window to workspace 3" })
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.exec_cmd("~/scripts/workspace.sh move 4"), { desc = "Send window to workspace 4" })
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.exec_cmd("~/scripts/workspace.sh move 5"), { desc = "Send window to workspace 5" })
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6, follow = true }), { desc = "Send window to workspace 6" })
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7, follow = true }), { desc = "Send window to workspace 7" })
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8, follow = true }), { desc = "Send window to workspace 8" })
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9, follow = true }), { desc = "Send window to workspace 9" })
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10, follow = true }), { desc = "Send window to workspace 10" })

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { desc = "Go to the next workspace" })
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { desc = "Go to the previous workspace" })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, desc = "Drag to move window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, desc = "Drag to resize window" })
