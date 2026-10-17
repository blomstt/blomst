#!/bin/sh
# Screenshot you can draw on (Super + Ctrl + Print): pick an area, mark it up in satty,
# then save (Ctrl + S) or copy (Ctrl + C).
DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
if command -v satty >/dev/null 2>&1; then
    hyprshot -m region --raw | satty --filename - --copy-command wl-copy \
        --output-filename "$DIR/$(date +%Y-%m-%d_%H-%M-%S).png" --early-exit
else
    notify-send -a Screenshot "Drawing on screenshots needs satty" "sudo pacman -S satty"
    hyprshot -m region -o "$DIR"
fi
