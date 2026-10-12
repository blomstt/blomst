#!/bin/bash
# Notification options from Blomst Settings (Super + S)
eval "$(python3 -c '
import json, os
try: o = json.load(open(os.path.expanduser("~/.config/blomst-settings/notifications.json")))
except Exception: o = {}
print("IN_STACK=%s HIDE_POPUPS=%s" % (bool(o.get("in_stack", True)), bool(o.get("hide_with_stack", True))))
')"

WINDOW_NAME="device-control resource-monitor music-window custom-calendar"
[ "$IN_STACK" = "True" ] && WINDOW_NAME="$WINDOW_NAME notification-center"

all_open=true
for name in $WINDOW_NAME; do
  if ! eww active-windows | grep -qw "$name"; then
    all_open=false
    break
  fi
done

# Pop-ups overlap the stack, so hide them while it's open
# (new ones still land in the notification center)
if $all_open; then
  eww close $WINDOW_NAME notification-center 2>/dev/null
  eww open notifications
else
  [ "$HIDE_POPUPS" = "True" ] && eww close notifications
  eww open-many $WINDOW_NAME
fi
