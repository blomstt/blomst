#!/bin/bash
# Prints the last known brightness instantly, then refreshes it in the
# background so the slow DDC read never blocks eww or fights the slider.
STATE="${XDG_RUNTIME_DIR:-/tmp}/eww-brightness"
cat "$STATE.cache" 2>/dev/null || echo 50
setsid -f bash -c '
  exec 9>"$0.lock"
  flock -n 9 || exit 0
  v=$(ddcutil --bus 5 getvcp 10 2>/dev/null | grep -oP "current value =\s*\K[0-9]+" | head -1)
  [ -n "$v" ] && echo "$v" > "$0.cache"
' "$STATE" >/dev/null 2>&1
