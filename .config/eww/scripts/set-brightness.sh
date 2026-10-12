#!/bin/bash
# Called by the eww brightness sliders. Returns instantly; one background
# worker applies the newest value to both monitors over DDC.
V=${1%.*}
[[ "$V" =~ ^[0-9]+$ ]] || exit 0
STATE="${XDG_RUNTIME_DIR:-/tmp}/eww-brightness"
echo "$V" > "$STATE.want"
echo "$V" > "$STATE.cache"
setsid -f bash -c '
  exec 9>"$0.lock"
  flock -n 9 || exit 0          # a worker is already running; it will pick up the new value
  last=""
  while :; do
    v=$(cat "$0.want")
    [ "$v" = "$last" ] && break
    ddcutil --bus 5 --noverify setvcp 10 "$v"
    ddcutil --bus 9 --noverify setvcp 10 "$v"
    last=$v
  done
' "$STATE" >/dev/null 2>&1
