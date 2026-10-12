#!/bin/bash
# Follows the current track and prints a local file path for its cover art.
# Some players hand out web links, which eww can't display, so they get downloaded first.
PLAYERS="%any"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/eww-covers"
mkdir -p "$CACHE"
playerctl --player="$PLAYERS" --follow metadata --format '{{mpris:artUrl}}' 2>/dev/null |
while read -r url; do
  case "$url" in
    http*)
      f="$CACHE/$(printf %s "$url" | md5sum | cut -c1-16).jpg"
      if [ ! -s "$f" ]; then
        find "$CACHE" -type f -mmin +60 -delete 2>/dev/null
        curl -sL -m 8 -o "$f" "$url" || rm -f "$f"
      fi
      [ -s "$f" ] && echo "$f" || echo ""
      ;;
    file://*) echo "${url#file://}" ;;
    *) echo "$url" ;;
  esac
done
