#!/bin/bash

# --- Helper Function: Run only if command exists ---
run_if_exists() {
    if command -v "$1" >/dev/null 2>&1; then
        "$@"
    else
        echo "Skip: Command $1 not found."
    fi
}

# --- Helper Function: Kill only if process is running ---
safe_kill() {
    if pgrep -x "$1" >/dev/null; then
        killall "$1"
    else
        echo "Skip: $1 is not running."
    fi
}

# Variables
SELECTED_WALLPAPER=$1
RELOAD_APPS=$2
WALLPAPER_DIR="$HOME/wallpapers"
WP_PATH="$WALLPAPER_DIR/$SELECTED_WALLPAPER.jpg"

if [ ! -f "$WP_PATH" ]; then
    echo "Error: Wallpaper not found: $SELECTED_WALLPAPER"
    exit 1
fi

# Folders some templates write into
mkdir -p "$HOME/.config/btop/themes" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/blomst-settings"

run_if_exists matugen --source-color-index 0 -m dark image "$WP_PATH"

# Optional per-machine extras (untracked): ~/.config/matugen/local.toml
if [ -f "$HOME/.config/matugen/local.toml" ]; then
    run_if_exists matugen -c "$HOME/.config/matugen/local.toml" --source-color-index 0 -m dark image "$WP_PATH"
fi

# Firefox follows the wallpaper through the Pywalfox extension (when installed)
PYWALFOX=$(command -v pywalfox || echo "$HOME/.local/bin/pywalfox")    # pipx puts it in ~/.local/bin
[ -x "$PYWALFOX" ] && "$PYWALFOX" update >/dev/null 2>&1 &

# Login screen follows the wallpaper too (no-op until /var/lib/blomst-sddm exists)
[ -x "$HOME/scripts/sddm_sync.sh" ] && "$HOME/scripts/sddm_sync.sh" "$WP_PATH"

# Push the new palette into Code - OSS
[ -f "$HOME/scripts/vscode_colors.py" ] && python3 "$HOME/scripts/vscode_colors.py"

if [[ "$RELOAD_APPS" == "--generate-only" || "$RELOAD_APPS" == "-g" ]]; then
    echo "Generate only. Skipping app reload."
    exit 0
fi

# A playing video wallpaper stops first, so the change animates from its still picture
[ -x "$HOME/scripts/video_wallpaper.sh" ] && "$HOME/scripts/video_wallpaper.sh" --stop

# awww (formerly swww) when it is running: animated change, the new wallpaper grows out from the middle
WW=""
for w in awww swww; do command -v "$w" >/dev/null 2>&1 && "$w" query >/dev/null 2>&1 && WW=$w && break; done
if [ -n "$WW" ]; then
    "$WW" img "$WP_PATH" --transition-type grow --transition-pos 0.5,0.5 \
        --transition-duration 1.2 --transition-fps 144 &
elif command -v hyprpaper >/dev/null 2>&1; then
    safe_kill hyprpaper
    hyprpaper -c "$HOME/.config/hypr/service/hyprpaper.conf" &
fi

# A video with the same name as the picture plays on top once the change has finished
[ -x "$HOME/scripts/video_wallpaper.sh" ] && (sleep 1.3; "$HOME/scripts/video_wallpaper.sh" "$WP_PATH") &

if pgrep -x "eww" >/dev/null; then
    killall eww
    sleep 1
    eww open-many side-bar notifications
else
    eww open-many side-bar notifications
fi

for SOCKET in /tmp/kitty-*; do
    if [ -S "$SOCKET" ]; then
        run_if_exists kitty @ --to "unix:$SOCKET" set-colors -a -c ~/.config/kitty/kitty-colors.conf
    fi
done

for sock in /tmp/nvim*; do
    if [ -S "$sock" ]; then
        run_if_exists nvim --server "$sock" --remote-send "<cmd>colorscheme lush-colors<CR>"
    fi
done
