#!/bin/bash
# Bluetooth's state for the device-control widget, as JSON:
# {"state": connected|on|off, "icon", "tooltip"}. Connected means a device is connected
# right now, not just paired; the tooltip names them, with battery where the device reports it.

out() {
  jq -nc --arg state "$1" --arg icon "$2" --arg tooltip "$3" '{state: $state, icon: $icon, tooltip: $tooltip}'
}

powered=$(timeout 2 bluetoothctl show 2>/dev/null | awk '/Powered:/ { print $2; exit }')
if [[ "$powered" != "yes" ]]; then
  out off "󰂲" "Bluetooth off"
  exit 0
fi

names=()
while read -r _ mac name; do
  [[ -n "$mac" ]] || continue
  battery=$(timeout 2 bluetoothctl info "$mac" 2>/dev/null | awk -F'[()]' '/Battery Percentage/ { print $2; exit }')
  names+=("${name}${battery:+ · ${battery}%}")
done < <(timeout 2 bluetoothctl devices Connected 2>/dev/null | grep '^Device ')

if (( ${#names[@]} > 0 )); then
  out connected "󰂱" "$(printf '%s\n' "${names[@]}" | paste -sd ',' | sed 's/,/, /g')"
else
  out on "󰂯" "On, nothing connected"
fi
