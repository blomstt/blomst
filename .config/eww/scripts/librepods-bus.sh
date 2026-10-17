#!/bin/bash
# Prints LibrePods' connection on the session bus (the one with a tray menu), or nothing when
# it isn't running. Works for both LibrePods apps: the packaged Qt one and the Rust one.
for c in $(busctl --user list 2>/dev/null | awk '$3 ~ /^librepods/ { print $1 }'); do
  if busctl --user tree "$c" 2>/dev/null | grep -q MenuBar; then echo "$c"; exit 0; fi
done
