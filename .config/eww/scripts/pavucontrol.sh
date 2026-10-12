#!/bin/sh
# Open the volume mixer, or jump to it if it is already open somewhere.
# Runs detached so eww's 200ms command limit cannot cut it short.
if [ -z "$MIXER_DETACHED" ]; then
    MIXER_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

if pgrep -x pavucontrol >/dev/null; then
    hyprctl dispatch focuswindow "class:^(org\.pulseaudio\.pavucontrol|pavucontrol)$"
else
    hyprctl dispatch exec "[float; size 525 260] pavucontrol"
fi
