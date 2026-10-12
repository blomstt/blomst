#!/bin/bash
# Blomst uninstaller: unlinks these dotfiles and restores the backups the installer saved.
# Adapted from the Zenities uninstaller by hayyaoe. It does not delete ~/blomst.

# Remove symlinked dotfiles installed by stow
cd "$HOME/blomst" || { echo "Could not access $HOME/blomst"; exit 1; }
stow -D .

# Restore only the backups INSTALL.sh made, listed in its manifest as "original<TAB>backup"
MANIFEST="$HOME/.local/state/blomst/backups"

if [ -f "$MANIFEST" ]; then
  echo "Restoring backups listed in $MANIFEST"
  while IFS=$'\t' read -r original backup; do
    if [ ! -e "$backup" ] && [ ! -L "$backup" ]; then
      echo "Backup $backup not found; nothing to restore."
    elif [ -e "$original" ] || [ -L "$original" ]; then
      echo "Warning: $original exists; skipping restoration of $backup to avoid overwriting."
    else
      echo "Restoring backup: $backup -> $original"
      mv "$backup" "$original"
    fi
  done < "$MANIFEST"
  mv "$MANIFEST" "$MANIFEST.restored-$(date +%Y%m%d-%H%M%S)"
else
  echo "No backup list at $MANIFEST; nothing to restore."
fi


# The dotfiles folder is kept on purpose: it holds the only copy of this setup.
cd "$HOME" || exit 1
echo "Left ~/blomst in place. Delete it yourself if you really want it gone."

# Clean up Eww
# if [ -d "$HOME/eww" ]; then
#     rm -rf $HOME/eww
#     sudo rm /usr/local/bin/eww
# fi

# Restore default shell to bash
chsh -s /bin/bash

# Optionally stop and disable NetworkManager (comment these lines if you want to keep NetworkManager)
# sudo systemctl disable NetworkManager
# sudo systemctl stop NetworkManager

# Reboot the system
echo "Uninstallation complete. A reboot is needed for everything to take effect."
read -rp "Reboot now? [y/N] " answer
if [[ $answer == [yY]* ]]; then
  sudo reboot
fi

