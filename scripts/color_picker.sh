#!/bin/sh
# Colour picker (Super + Shift + C): click anywhere, the colour's hex code is copied.
command -v hyprpicker >/dev/null 2>&1 || { notify-send -a "Colour picker" "The colour picker needs hyprpicker" "sudo pacman -S hyprpicker"; exit 0; }
colour=$(hyprpicker -a -n -f hex) && [ -n "$colour" ] && notify-send -a "Colour picker" "Copied $colour" "Paste it anywhere"
