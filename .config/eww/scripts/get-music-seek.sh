#!/bin/bash
# Current track position as a percentage
P="%any"
POS=$(playerctl --player="$P" position 2>/dev/null)
LEN=$(playerctl --player="$P" metadata --format '{{mpris:length}}' 2>/dev/null)
awk -v p="$POS" -v l="$LEN" 'BEGIN { if (l > 0) printf "%.2f\n", p / (l / 1000000) * 100; else print 0 }'
