#!/bin/bash
# CPU temperature as an integer (Intel: Package/Core 0, AMD: Tctl/Tdie)
t=$(sensors 2>/dev/null | awk '/^(Package id 0|Tctl|Tdie|Core 0):/ { for (k = 1; k <= NF; k++) if ($k ~ /^\+[0-9]/) { gsub(/[^0-9.]/, "", $k); printf "%d\n", $k; exit } }')
echo "${t:-0}"
