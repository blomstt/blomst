#!/bin/sh
# Prints the focused window's title, then a new line every time focus or the title changes.
hyprctl activewindow -j | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('title','') if isinstance(d,dict) else '')" 2>/dev/null || echo ""
SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
socat -U - UNIX-CONNECT:"$SOCKET" | while IFS= read -r line; do
    case "$line" in
        "activewindow>>"*) title=${line#activewindow>>}; echo "${title#*,}" ;;
    esac
done
