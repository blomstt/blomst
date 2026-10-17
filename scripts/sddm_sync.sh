#!/bin/sh
# Keep the login screen (SDDM) in step with the desktop: copies the Blomst theme, the current
# wallpaper and its colours to /var/lib/blomst-sddm, which the login screen can read
# (it runs as its own user and cannot see inside your home folder).
# Called by update-color.sh. Does nothing until the one-time setup in the README is done.
DEST=/var/lib/blomst-sddm/theme
[ -d /var/lib/blomst-sddm ] && [ -w /var/lib/blomst-sddm ] || exit 0

# The wallpaper to show; by default the current one (from hyprpaper.conf)
WALLPAPER=${1:-$(sed -n 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//p' "$HOME/.config/hypr/service/hyprpaper.conf" | head -1 | sed "s|\$HOME|$HOME|")}
mkdir -p "$DEST"
cp -r "$HOME/blomst/sddm/blomst/." "$DEST/"
[ -f "$HOME/.cache/blomst-sddm/theme.conf.user" ] && cp "$HOME/.cache/blomst-sddm/theme.conf.user" "$DEST/theme.conf.user"
if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
    # 1920 wide is plenty under the blur and keeps the login screen quick to load
    if command -v magick >/dev/null 2>&1; then
        magick "$WALLPAPER" -resize '1920x>' -quality 90 "$DEST/background.jpg"
    else
        cp "$WALLPAPER" "$DEST/background.jpg"
    fi
fi
chmod -R a+rX /var/lib/blomst-sddm
