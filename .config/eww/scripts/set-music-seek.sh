#!/bin/zsh

# Detach so eww's 200ms command limit cannot kill the seek half-way
if [[ -z "$SEEK_DETACHED" ]]; then
  SEEK_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
  exit 0
fi


LENGTH_MICROSECONDS=$(playerctl --player=%any metadata --format "{{mpris:length}}")

# Calculate the real value in seconds based on the percentage input
REALVALUE=$(python3 -c "
import sys
length_microseconds = float(sys.argv[1])
percentage = float(sys.argv[2])
length_seconds = length_microseconds / 1000000
real_value = (percentage / 100) * length_seconds
print(real_value)
" "$LENGTH_MICROSECONDS" "$1")

# Set the player position to the calculated value
playerctl --player=%any position "$REALVALUE"
