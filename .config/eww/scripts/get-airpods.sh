#!/bin/bash
# AirPods battery and noise control for the side bar, as JSON:
# {"show", "name", "left", "right", "case", "mode": anc|transparency|adaptive|off, "low", "hires", "has_hires"}
# Read from LibrePods, which speaks Apple's protocol to the AirPods: its tray icon's tooltip has
# the battery ("Left: 83%, Right: 82%" from the Qt app, "L: 83% R: 82% C: -" from the Rust one)
# and its menu's radio items the mode. show is false while LibrePods isn't running or
# no AirPods are connected. A level of -1 means unknown (LibrePods reports the case as 0% while
# it's closed or away). low is true when either earbud is at 20% or less. hires is whether the
# hi-res microphone is on; has_hires is false with a LibrePods that doesn't have one (the packaged
# Qt app).

hidden() { echo '{"show":false,"name":"","left":-1,"right":-1,"case":-1,"mode":"","low":false,"hires":false,"has_hires":false}'; exit 0; }

name=$(timeout 2 bluetoothctl devices Connected 2>/dev/null | grep -i 'airpods' | head -1 | cut -d' ' -f3-)
[[ -n "$name" ]] || hidden

conn=$("$(dirname "$(readlink -f "$0")")/librepods-bus.sh")
[[ -n "$conn" ]] || hidden

tooltip=$(busctl --user --json=short get-property "$conn" /StatusNotifierItem org.kde.StatusNotifierItem ToolTip 2>/dev/null | jq -r '"\(.data[2] // "") \(.data[3] // "")"')
menu=$(busctl --user --json=short call "$conn" /MenuBar com.canonical.dbusmenu GetLayout iias -- 0 -1 0 2>/dev/null)
mode=$(jq -r '[.. | objects | select(."toggle-type"?.data == "radio" and ."toggle-state".data == 1) | .label.data] | first // ""' <<< "$menu")
hires=$(jq -c '[.. | objects | select(.label?.data == "Hi-Res Microphone") | ."toggle-state".data == 1] | first' <<< "$menu")
hires=${hires:-null}

level() { grep -oP "\\b($1): \K[0-9]+(?=%)" <<< "$tooltip" | head -1 | grep . || echo -1; }
left=$(level 'Left|L') right=$(level 'Right|R') case=$(level 'Case|C')
(( case == 0 )) && case=-1

case "$mode" in
  "Noise Cancellation") mode=anc ;;
  Transparency) mode=transparency ;;
  Adaptive) mode=adaptive ;;
  Off) mode=off ;;
  *) mode="" ;;
esac

jq -nc --arg name "$name" --argjson left "$left" --argjson right "$right" --argjson case "$case" --arg mode "$mode" \
  --argjson hires "$hires" \
  '{show: true, name: $name, left: $left, right: $right, case: $case, mode: $mode,
    low: ([$left, $right] | map(select(. >= 0)) | any(. <= 20)), hires: ($hires == true), has_hires: ($hires != null)}'
