#!/bin/sh
# Opens yazi in its own kitty window. It gets its own window class ("yazi") so its
# floating size is remembered separately from ordinary terminals.
SIZES="${XDG_CONFIG_HOME:-$HOME/.config}/blomst-settings/float-sizes.json"
W=900; H=600
if [ -f "$SIZES" ] && command -v jq >/dev/null 2>&1; then
    SAVED=$(jq -r 'to_entries[] | select(.key | startswith("yazi|")) | .value | (if type == "array" then . else .size end) | "\(.[0]) \(.[1])"' "$SIZES" 2>/dev/null | head -n 1)
    [ -n "$SAVED" ] && W=${SAVED% *} && H=${SAVED#* }
fi
exec kitty --class yazi -o remember_window_size=no -o initial_window_width="$W" -o initial_window_height="$H" -e yazi
