#!/bin/bash
# Blomst installer: sets up this Hyprland rice on a fresh Arch Linux install.
# Adapted from the Zenities installer by hayyaoe (https://github.com/hayyaoe/zenities).
#
# Read before running. It installs packages, backs up existing configs to *.bak,
# links these dotfiles into your home folder with stow, switches the shell to zsh,
# turns on NetworkManager and Bluetooth, and offers to reboot.
# Clone the repo to ~/blomst first; the paths below expect it there.

exec > >(tee -a install-log.txt) 2>&1

# Wrapper Configuration
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
SPIN='|/-\'

run_network() {
    local task_name=$1
    shift
    local cmd="$@"
    local attempt=1
    local max_attempts=5

    echo -e "${BLUE}================================================================${NC}"
    echo -e "${CYAN}  TASK: $task_name${NC}"
    echo -e "${BLUE}================================================================${NC}"

    while true; do
        eval "$cmd" >> install-log.txt 2>&1 &
        local pid=$!

        while kill -0 $pid 2>/dev/null; do
            for i in {0..3}; do
                printf "\r${GREEN}  [%c] Attempt $attempt: Working...${NC}" "${SPIN:$i:1}"
                sleep 0.1
            done
        done

        wait $pid
        if [ $? -eq 0 ]; then
            printf "\r${GREEN}  [OK] Task completed!                          ${NC}\n\n"
            break
        elif [ $attempt -ge $max_attempts ]; then
            printf "\r${RED}  [!] FATAL ERROR: Task '$task_name' failed after $max_attempts attempts!${NC}\n"
            echo -e "${RED} Check 'install-log.txt' for details.${NC}"
            exit 1
        else
            printf "\r${RED}  [!] Attempt $attempt failed. Retrying...      ${NC}"
            ((attempt++))
            sleep 10
        fi
    done
}

run_loader() {
    local task_name=$1
    shift
    local cmd="$@"

    echo -e "${BLUE}================================================================${NC}"
    echo -e "${CYAN}  TASK: $task_name${NC}"
    echo -e "${BLUE}================================================================${NC}"

    eval "$cmd" >> install-log.txt 2>&1 &
    local pid=$!

    while kill -0 $pid 2>/dev/null; do
        for i in {0..3}; do
            printf "\r${GREEN}  [%c] Processing...${NC}" "${SPIN:$i:1}"
            sleep 0.1
        done
    done

    wait $pid
    local status=$?

    if [ $status -eq 0 ]; then
        printf "\r${GREEN}  [OK] Task completed successfully!                    ${NC}\n\n"
    else
        printf "\r${RED}  [!] FATAL ERROR: Task '$task_name' failed!           ${NC}\n"
        echo -e "${RED} Check 'install-log.txt' for details.${NC}"
        exit 1
    fi
}

# Installation Functions
backup_configs() {
  CONFIG_DIR="$HOME/.config"
  DOTFILES="$HOME/blomst"
  DOTFILES_CONFIG="$DOTFILES/.config"
  # A timestamp keeps a second run from moving the new backup inside the old one
  BACKUP_SUFFIX=".bak-$(date +%Y%m%d-%H%M%S)"
  # UNINSTALL.sh reads this list so it only restores backups made here
  MANIFEST="$HOME/.local/state/blomst/backups"
  mkdir -p "$(dirname "$MANIFEST")"

  backup() {
    local path=$1
    # Skip anything missing, and links that already point into the repo from an earlier run
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
      echo "$path not found; skipping backup"
    elif [ -L "$path" ] && [[ $(readlink -f "$path") == "$DOTFILES"/* ]]; then
      echo "$path is already linked to blomst; skipping backup"
    else
      echo "Backing up: $path"
      mv "$path" "${path}${BACKUP_SUFFIX}"
      printf '%s\t%s\n' "$path" "${path}${BACKUP_SUFFIX}" >> "$MANIFEST"
    fi
  }

  echo "Backing up configuration directories in $CONFIG_DIR based on dotfiles in $DOTFILES_CONFIG"
  for dir in "$DOTFILES_CONFIG"/*/; do
    backup "$CONFIG_DIR/$(basename "$dir")"
  done

  # wallpapers, scripts and screenshots are folders, so this checks with -e rather than -f
  FILES=(.zshrc .zshenv .tmux.conf .p10k.zsh wallpapers scripts screenshots)
  for file in "${FILES[@]}"; do
    backup "$HOME/$file"
  done
}

apply_dotfiles() {
  cd "$HOME/blomst" || { echo "Could not access $HOME/blomst"; exit 1; }
  stow .

  cd "$HOME" || exit 1
}

install_yay() {
    if command -v yay >/dev/null; then
        echo "Yay is already installed. Skipping..."
        return 0
    fi

    run_network "Cloning Yay (Yet Another Yogurt)" "cd $HOME && rm -rf yay; git clone https://aur.archlinux.org/yay.git"

    run_loader "Building Yay" "cd $HOME/yay && makepkg -s --noconfirm"

    run_loader "Installing Yay Package" "cd $HOME/yay && sudo pacman -U --noconfirm *.pkg.tar.zst"

    run_loader "Cleaning up Yay build folder" "rm -rf $HOME/yay"
}

install_eww() {
    if command -v eww >/dev/null; then
        echo "Eww is already installed. Skipping build..."
        return 0
    fi

    run_network "Cloning Eww Repository" "cd $HOME && [ -d eww ] && rm -rf eww; git clone https://github.com/elkowar/eww"

    run_loader "Compiling Eww (Cargo Build)" "cd $HOME/eww && cargo build --release --no-default-features --features=wayland"

    run_loader "Installing Eww Binary to /usr/local/bin" "cd $HOME/eww/target/release && chmod +x ./eww && sudo cp ./eww /usr/local/bin/"

    run_loader "Cleaning up Eww source" "cd $HOME && rm -rf eww"
}

setup_scripts() {
    run_loader "Executing Hyprland Setup" "bash $HOME/scripts/hypr_setup.sh"

    run_loader "Executing Zsh Configuration" "bash $HOME/scripts/zsh_setup.sh"

    run_loader "Normalizing Wallpapers" "bash $HOME/scripts/normalize_wallpaper.sh"
}

setup_network() {
    # Only turns NetworkManager on (the wifi menu uses it). DNS and other network settings are left alone.
    run_loader "Enabling NetworkManager" "sudo systemctl enable --now NetworkManager"
}

setup_bluetooth() {
    run_loader "Enabling & Starting Bluetooth Service" "sudo systemctl enable --now bluetooth.service"
}

setup_shell() {
    # Arch's zsh package normally adds itself to /etc/shells already
    if ! grep -qx "/usr/bin/zsh" /etc/shells; then
        run_loader "Adding Zsh to Valid Shells" "echo /usr/bin/zsh | sudo tee -a /etc/shells"
    fi

    run_loader "Changing Default Shell to Zsh" "sudo chsh -s /usr/bin/zsh $USER"
}

# Sudo setup: ask once, then keep the sudo timestamp fresh in the background.
# The password itself is never stored in a variable.
clear
echo "    ┓ ┓"
echo "    ┣┓┃┏┓┏┳┓┏╋"
echo "    ┗┛┗┗┛┛┗┗┛┗"
echo -e "${NC}"

until sudo -v; do
    echo -e "${RED}  [ERROR] Could not get sudo access. Please try again.${NC}"
done
echo -e "${GREEN}  [OK] Sudo access confirmed. Installation started...${NC}\n"

while true; do
    sudo -n true
    sleep 50
    kill -0 "$$" || exit
done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT


# Install necessary packages via pacman
run_network "Syncing mirror & Installing base packages" "sudo pacman -Syu --needed --noconfirm base-devel rustup github-cli stow pamixer brightnessctl playerctl rofi-wayland hyprlock hypridle hyprpaper yazi neovim bottom networkmanager rustup zsh imagemagick acpi pavucontrol lua51 lua51-luarocks xdg-desktop-portal-hyprland xdg-desktop-portal-gtk gtk4 gtk3 qt6ct kvantum noto-fonts go matugen pyside6 qt6-wayland ddcutil lm_sensors curl python python-psutil"

# Install Rust toolchain
run_network "Setting up Rust Toolchain" "rustup default stable"

# Backup Existing Config
run_loader "Backing up existing Configurations" "backup_configs"

# Apply Blomst dotfiles
run_loader  "Applying blomst dotfiles via Stow" "apply_dotfiles"

# Install yay (AUR helper)
install_yay

# Install additional packages via yay
run_network "Installing AUR Packages" "yay -S --needed --noconfirm --sudoloop fastfetch ttf-iosevka otf-hermit-nerd gvfs dbus libdbusmenu-glib libdbusmenu-gtk3 gtk-layer-shell zoxide eza fzf jq socat tmux nvm btop hyprshot bluez bluez-utils bluez-obex bluetuith python-gobject zsh-theme-powerlevel10k-git"

# Eww installation
install_eww

# Run Configuration Scripts
setup_scripts

# Network Manager setup
setup_network

# Bluetooth Setup
setup_bluetooth

# Change shell to zsh
setup_shell

#Run Wallpaper and Color Initialization
run_loader "Initializing Wallpaper & Colors" "bash $HOME/.config/eww/scripts/change-wallpaper.sh 15 -g" 

# Reboot the system
echo -e "\n${GREEN}Installation complete. A reboot is needed for everything to take effect.${NC}"
read -rp "  Reboot now? [y/N] " answer
if [[ $answer == [yY]* ]]; then
    sudo reboot
fi

