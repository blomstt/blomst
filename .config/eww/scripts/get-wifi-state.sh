#!/bin/bash
# The network's state for the device-control widget, as JSON:
# {"state": connected|weak|disconnected|off, "icon", "tooltip"}.
# Wi-Fi signal: 75%+ full bars, 55%+ three, 35%+ two, below that it counts as weak.

out() {
  jq -nc --arg state "$1" --arg icon "$2" --arg tooltip "$3" '{state: $state, icon: $icon, tooltip: $tooltip}'
}

devices=$(nmcli -t -f TYPE,STATE device 2>/dev/null)

if grep -q '^ethernet:connected$' <<< "$devices"; then
  name=$(nmcli -t -f TYPE,NAME connection show --active | awk -F: '$1 ~ /ethernet/ { sub(/^[^:]*:/, ""); print; exit }')
  out connected "󰈀" "Ethernet${name:+: $name}"
elif grep -q '^wifi:connected$' <<< "$devices"; then
  # --rescan no: read what NetworkManager already knows, never start a scan every few seconds
  line=$(nmcli -t -f IN-USE,SIGNAL,SSID device wifi list --rescan no 2>/dev/null | grep -m1 '^\*:')
  signal=$(cut -d: -f2 <<< "$line")
  ssid=$(cut -d: -f3- <<< "$line" | sed 's/\\:/:/g')
  signal=${signal:-0}
  tooltip="${ssid:-Wi-Fi} · ${signal}%"
  if (( signal >= 75 )); then
    out connected "󰤨" "$tooltip"
  elif (( signal >= 55 )); then
    out connected "󰤥" "$tooltip"
  elif (( signal >= 35 )); then
    out connected "󰤢" "$tooltip"
  elif (( signal >= 15 )); then
    out weak "󰤟" "$tooltip · weak signal"
  else
    out weak "󰤠" "$tooltip · very weak signal"
  fi
elif [[ "$(nmcli radio wifi 2>/dev/null)" == "disabled" ]]; then
  out off "󰖪" "Wi-Fi off"
else
  out disconnected "󰤮" "Not connected"
fi
