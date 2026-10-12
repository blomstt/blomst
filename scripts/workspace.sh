#!/bin/bash
# Per-monitor workspaces.
#   workspace.sh go   <1-5>   show workspace N of the monitor the cursor is on
#   workspace.sh move <1-5>   send the focused window to workspace N of that monitor
# Main monitor (DP-3) owns workspaces 1-5, second monitor (HDMI-A-1) owns 6-10,
# so "2" on the second monitor really means workspace 7.
SECOND="HDMI-A-1"
n=$2
mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
[ "$mon" = "$SECOND" ] && n=$((n + 5))
case "$1" in
  go)   hyprctl dispatch workspace "$n" ;;
  move) hyprctl dispatch movetoworkspace "$n" ;;
esac
