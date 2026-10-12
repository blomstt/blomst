#!/bin/bash

NORMALIZE="$HOME/scripts/normalize_wallpaper.sh"
WINDOW_NAME="wallpaper"

if eww active-windows | grep -q "$WINDOW_NAME"; then
  eww close "$WINDOW_NAME"
else

  if [ -f "$NORMALIZE" ]; then
      bash "$NORMALIZE"
  fi

  # Tell eww about pictures added since it last looked (it only re-checks every 10 minutes)
  eww update wallpapers="$(~/.config/eww/scripts/get-wallpapers.sh)"

  eww open "$WINDOW_NAME"
fi

