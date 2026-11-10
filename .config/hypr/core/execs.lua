-- Auto Start Apps

-- Every time the config loads
-- Themes
hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"')
hl.exec_cmd('gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"')   -- same icons as the launcher and task manager

-- Once, at login
local once = {
    -- Themes
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",

    -- Hypr services
    "~/scripts/wallpaper_daemon.sh",   -- awww/swww when installed (animated changes), else hyprpaper
    "hypridle",

    -- Widgets
    "eww open-many side-bar notifications",

    -- AirPods battery, noise control and the hi-res mic for the side bar: LibrePods' Rust app built
    -- from PR #655 (~/Projects/librepods-hires-mic). Its log includes the AirPods' pairing keys, so
    -- it goes nowhere. The packaged one is `librepods --hide`; only one can run at a time
    "~/.local/bin/librepods-hires --start-minimized >/dev/null 2>&1",

    -- Audio
    -- "pipewire & pipewire-pulse & wireplumber",

    -- Remember the size of floating windows per app
    "~/scripts/float_sizes.py",

    -- Clipboard history for Super + C (when cliphist is installed)
    "command -v cliphist >/dev/null && wl-paste --watch cliphist store",
}

-- The user's own list, from Blomst Settings' Startup page
local user = require("user.execs")

hl.on("hyprland.start", function()
    for _, cmd in ipairs(once) do
        hl.exec_cmd(cmd)
    end
    for _, cmd in ipairs(user) do
        hl.exec_cmd(cmd)
    end
end)
