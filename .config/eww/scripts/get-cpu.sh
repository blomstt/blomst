#!/bin/bash
# CPU usage (%) since the previous call, from /proc/stat. Cheap enough to run every second.
STATE="${XDG_RUNTIME_DIR:-/tmp}/eww-cpu"
read -r _ u n s i w q sq st _ < /proc/stat
idle=$((i + w)); total=$((u + n + s + i + w + q + sq + st))
if read -r pi pt 2>/dev/null < "$STATE" && [ "$total" -gt "$pt" ]; then
  echo $(( (100 * ((total - pt) - (idle - pi)) + (total - pt) / 2) / (total - pt) ))
else
  echo 0
fi
echo "$idle $total" > "$STATE"
