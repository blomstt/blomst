#!/bin/bash
# The default output's state for the device-control widget, as one line of JSON, printed
# again on every change: {"volume", "state": muted|high|medium|low, "icon", "tooltip"}.
# Muted (or at 0%) counts as muted. Listens to the sound server instead of polling.

emit() {
  sink=$(pactl get-default-sink 2>/dev/null) || return
  muted=$(pactl get-sink-mute "$sink" 2>/dev/null | awk '{print $2}')
  volume=$(pactl get-sink-volume "$sink" 2>/dev/null | awk '/Volume:/ { gsub(/%/, "", $5); print $5; exit }')
  volume=${volume:-0}

  if [[ "$muted" == "yes" ]] || (( volume == 0 )); then
    state=muted icon="󰝟" tooltip="Muted"
  elif (( volume > 50 )); then
    state=high icon="󰕾" tooltip="Volume ${volume}%"
  else
    state=medium icon="󰖀" tooltip="Volume ${volume}%"
  fi
  jq -nc --argjson volume "$volume" --arg state "$state" --arg icon "$icon" --arg tooltip "$tooltip" \
    '{volume: $volume, state: $state, icon: $icon, tooltip: $tooltip}'
}

emit
while true; do
  pactl subscribe 2>/dev/null | while read -r line; do
    case "$line" in
      *" on sink #"*|*" on server"*) emit ;;
    esac
  done
  # The sound server went away (restart); wait for it and start listening again
  sleep 1
  emit
done
