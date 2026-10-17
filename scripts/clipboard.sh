#!/bin/sh
# Clipboard history (Super + C): pick an earlier copy with rofi and put it back on the clipboard.
command -v cliphist >/dev/null 2>&1 || { notify-send -a Clipboard "Clipboard history needs cliphist" "sudo pacman -S cliphist"; exit 0; }
cliphist list | rofi -dmenu -p "󰅌" -display-columns 2 | cliphist decode | wl-copy
