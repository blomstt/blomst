#!/bin/bash
# Volume and brightness keys: change the value, then show it in the on-screen pop-up for a moment.
# Usage: osd.sh volume up|down|mute   osd.sh mic mute   osd.sh brightness up|down
EWW="eww -c $HOME/.config/eww"
STEP=5
kind=$1; action=$2

case "$kind" in
  volume)
    case "$action" in
      up) pamixer -u; pamixer -i $STEP --allow-boost=false ;;
      down) pamixer -d $STEP ;;
      mute) pamixer -t ;;
    esac
    value=$(pamixer --get-volume)
    if [ "$(pamixer --get-mute)" = "true" ]; then icon="󰝟"; label="Muted"
    elif [ "$value" -gt 50 ]; then icon="󰕾"; label="$value%"
    elif [ "$value" -gt 0 ]; then icon="󰖀"; label="$value%"
    else icon="󰕿"; label="$value%"; fi ;;
  mic)
    pamixer --default-source -t
    value=$(pamixer --default-source --get-volume)
    if [ "$(pamixer --default-source --get-mute)" = "true" ]; then icon="󰍭"; label="Microphone off"
    else icon="󰍬"; label="Microphone on"; fi ;;
  brightness)
    STATE="${XDG_RUNTIME_DIR:-/tmp}/eww-brightness"
    value=$(cat "$STATE.cache" 2>/dev/null || echo 50)
    case "$action" in
      up) value=$(( value + STEP > 100 ? 100 : value + STEP )) ;;
      down) value=$(( value - STEP < 0 ? 0 : value - STEP )) ;;
    esac
    "$HOME/.config/eww/scripts/set-brightness.sh" "$value"   # DDC, in the background
    icon="󰃠"; label="$value%" ;;
  *) exit 1 ;;
esac

$EWW update osd-icon="$icon" osd-value="$value" osd-label="$label"
$EWW active-windows | grep -q '^osd:' || $EWW open osd

# Close a moment after the last key press (each press restarts the wait)
stamp="${XDG_RUNTIME_DIR:-/tmp}/eww-osd-stamp"
date +%s%N > "$stamp"
mine=$(cat "$stamp")
( sleep 1.4; [ "$(cat "$stamp" 2>/dev/null)" = "$mine" ] && $EWW close osd ) >/dev/null 2>&1 &
