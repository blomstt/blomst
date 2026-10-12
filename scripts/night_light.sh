#!/bin/sh
# Restore the night light at login. Blomst Settings writes the options.
OPTIONS="$HOME/.config/blomst-settings/night-light.json"
command -v hyprsunset >/dev/null 2>&1 || exit 0
[ -f "$OPTIONS" ] || exit 0

eval "$(python3 -c '
import json, sys
try: o = json.load(open(sys.argv[1]))
except Exception: o = {}
print("ENABLED=%s TEMP=%d" % (bool(o.get("enabled")), int(o.get("temperature", 4500))))
' "$OPTIONS")"

[ "$ENABLED" = "True" ] && exec hyprsunset -t "$TEMP"
