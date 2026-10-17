#!/bin/bash
# Turns the AirPods' hi-res microphone on or off by clicking "Hi-Res Microphone" in LibrePods'
# tray menu (LibrePods built from PR #655), then shows the new state in the bar straight away.
# Runs detached so eww's 200ms command limit can't cut it short.
if [ -z "$AIRPODS_DETACHED" ]; then
    AIRPODS_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

dir=$(dirname "$(readlink -f "$0")")
conn=$("$dir/librepods-bus.sh")
[ -n "$conn" ] || exit 0
before=$("$dir/get-airpods.sh" | jq -c .hires)
id=$(busctl --user --json=short call "$conn" /MenuBar com.canonical.dbusmenu GetLayout iias -- 0 -1 0 \
    | jq -r '.. | arrays | select(length == 3 and (.[1] | type) == "object" and .[1].label?.data == "Hi-Res Microphone") | .[0]' | head -1)
[ -n "$id" ] || exit 0
busctl --user call "$conn" /MenuBar com.canonical.dbusmenu Event isvu "$id" clicked s "" 0
for _ in 1 2 3 4 5 6; do
    sleep 0.3
    state=$("$dir/get-airpods.sh")
    [ "$(jq -c .hires <<< "$state")" != "$before" ] && break
done
eww update airpods="$state"
