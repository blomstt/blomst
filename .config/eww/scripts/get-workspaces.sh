#!/bin/bash
# Emits the workspace list for eww, sorted, each with "visible": true when it is
# the one currently shown on its monitor.
emit() {
  jq -c -n --argjson w "$(hyprctl workspaces -j)" --argjson m "$(hyprctl monitors -j)" '
    ($m | map(.activeWorkspace.id)) as $shown
    | $w | map(select(.id > 0)) | sort_by(.id)
    | map(. + {visible: (.id as $i | ($shown | index($i)) != null)})'
}
emit
socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r line; do
  emit
done
