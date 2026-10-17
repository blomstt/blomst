#!/bin/sh
# Starts the wallpaper at login: awww/swww when installed (animated changes), else hyprpaper,
# plus the video when the wallpaper is a video one.
CONF="$HOME/.config/hypr/service/hyprpaper.conf"
WP=$(sed -n 's/^\s*path\s*=\s*//p' "$CONF" | head -1 | sed "s|\$HOME|$HOME|")
# swww was renamed awww; use whichever is installed
if command -v awww-daemon >/dev/null 2>&1; then WW=awww; elif command -v swww-daemon >/dev/null 2>&1; then WW=swww; fi
if [ -n "$WW" ]; then
    "$WW-daemon" &
    sleep 0.5
    [ -f "$WP" ] && "$WW" img "$WP" --transition-type none
else
    hyprpaper -c "$CONF" &
    sleep 0.5
fi
# A video wallpaper plays on top of its still picture (see video_wallpaper.sh)
[ -f "$WP" ] && "$HOME/scripts/video_wallpaper.sh" "$WP"
wait
