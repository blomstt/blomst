#!/bin/sh
# Audio visualizer for the side-bar: runs cava and prints {"on": .., "b": [8 levels, 0-100]} for
# every frame while sound is playing. After a moment of silence it prints "on": false once and then
# stays quiet, so eww is not redrawn 30 times a second for nothing.
OFF='{"on":false,"b":[0,0,0,0,0,0,0,0]}'
command -v cava >/dev/null 2>&1 || { echo "$OFF"; exit 0; }
# Switched off on the Bar page of the settings window (the bar reloads, and this re-runs, on a change)
grep -q '(defvar show-visualizer false)' "$HOME/.config/eww/settings.yuck" 2>/dev/null && { echo "$OFF"; exit 0; }

CONF="${XDG_CACHE_HOME:-$HOME/.cache}/eww/cava.conf"
mkdir -p "$(dirname "$CONF")"
cat > "$CONF" <<'EOF'
[general]
bars = 8
framerate = 30
autosens = 1

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10

[smoothing]
noise_reduction = 77
EOF

# cava exits by itself (broken pipe) when eww stops this script
cava -p "$CONF" 2>/dev/null | exec python3 -u -c '
import json, sys
SILENT_FRAMES = 45    # 1.5 s at 30 fps
quiet, on = SILENT_FRAMES, None    # start hidden until there is sound
for line in sys.stdin:
    try:
        b = [min(100, int(v)) for v in line.strip().rstrip(";").split(";")][:8]
    except ValueError:
        continue
    b += [0] * (8 - len(b))
    quiet = quiet + 1 if max(b) <= 2 else 0
    if quiet >= SILENT_FRAMES:
        if on is not False:
            on = False
            print(json.dumps({"on": False, "b": [0] * 8}))
        continue
    on = True
    print(json.dumps({"on": True, "b": b}))
'
