#!/bin/sh
# Wireless headset battery for the side-bar, read with headsetcontrol (Audeze Maxwell and many others).
# Prints {"show": .., "level": .., "charging": ..}; show is false when headsetcontrol is missing,
# no supported headset is plugged in, or the headset is switched off.
command -v headsetcontrol >/dev/null 2>&1 || { echo '{"show":false,"level":0,"charging":false}'; exit 0; }
headsetcontrol -b -o json 2>/dev/null | python3 -c '
import json, sys
try:
    b = json.load(sys.stdin)["devices"][0]["battery"]
    status, level = b.get("status", ""), int(b.get("level", -1))
except Exception:
    status, level = "", -1
show = status in ("BATTERY_AVAILABLE", "BATTERY_CHARGING") and level >= 0
print(json.dumps({"show": show, "level": max(level, 0), "charging": status == "BATTERY_CHARGING"}))
' 2>/dev/null || echo '{"show":false,"level":0,"charging":false}'
