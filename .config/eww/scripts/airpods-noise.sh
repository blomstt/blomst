#!/bin/bash
# Turns the AirPods' noise cancellation on or off (off is Transparency: AirPods Pro only accept
# "Off" once it's enabled on an Apple device), then shows the new state in the bar straight away.
# Runs detached so eww's 200ms command limit can't cut it short.
if [ -z "$AIRPODS_DETACHED" ]; then
    AIRPODS_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

dir=$(dirname "$(readlink -f "$0")")
current=$("$dir/get-airpods.sh" | jq -r .mode)
[ "$current" = "anc" ] && want="Transparency" || want="Noise Cancellation"

# Click that mode in LibrePods' tray menu, which both LibrePods apps have (only the Qt one has
# librepods-ctl)
conn=$("$dir/librepods-bus.sh")
[ -n "$conn" ] || exit 0
id=$(busctl --user --json=short call "$conn" /MenuBar com.canonical.dbusmenu GetLayout iias -- 0 -1 0 \
    | jq -r --arg want "$want" '.. | arrays | select(length == 3 and (.[1] | type) == "object" and .[1].label?.data == $want) | .[0]' | head -1)
[ -n "$id" ] || exit 0
busctl --user call "$conn" /MenuBar com.canonical.dbusmenu Event isvu "$id" clicked s "" 0
# The AirPods confirm the change within a moment; read it back from LibrePods
for _ in 1 2 3 4 5 6; do
    sleep 0.3
    state=$("$dir/get-airpods.sh")
    [ "$(jq -r .mode <<< "$state")" != "$current" ] && break
done
eww update airpods="$state"
