#!/bin/bash
# Toggle hypridle. Runs detached so eww's 200ms command limit can't interrupt it,
# and updates the icon straight away instead of waiting for the next poll.
if [[ -z "$IDLE_DETACHED" ]]; then
  IDLE_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
  exit 0
fi

if pgrep -x hypridle >/dev/null; then
    pkill -x hypridle
    eww -c ~/.config/eww update idle=true      # true = idle disabled (stay awake)
else
    setsid -f hypridle >/dev/null 2>&1
    eww -c ~/.config/eww update idle=false
fi
