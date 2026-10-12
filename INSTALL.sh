#!/bin/bash
# Blomst installer: sets up this Hyprland rice on a fresh Arch Linux install.
# Adapted from the Zenities installer by hayyaoe (https://github.com/hayyaoe/zenities).
#
# Read before running. It installs packages, backs up existing configs to *.bak,
# links these dotfiles into your home folder with stow, switches the shell to zsh,
# turns on NetworkManager and Bluetooth, and reboots.

exec > >(tee -a install-log.txt) 2>&1

# Helper Function
run_sudo() {
  echo "$PASSWORD" | sudo -S $@
}

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
  DOTFILES_CONFIG="$HOME/blomst/.config"
  BACKUP_SUFFIX=".bak"

  echo "Backing up configuration directories in $CONFIG_DIR based on dotfiles in $DOTFILES_CONFIG"
  # Change to the .config folder
  cd "$CONFIG_DIR" || { echo "Could not access $CONFIG_DIR"; exit 1; }

  # Loop over every directory in the dotfiles repo
  for dir in "$DOTFILES_CONFIG"/*/; do
    folder_name=$(basename "$dir")
    if [ -d "$CONFIG_DIR/$folder_name" ]; then
      echo "Backing up directory: $folder_name"
      mv "$CONFIG_DIR/$folder_name" "$CONFIG_DIR/${folder_name}${BACKUP_SUFFIX}"
    else
      echo "Directory $folder_name not found in $CONFIG_DIR; skipping backup"
    fi
  done

  FILES=(.zshrc .zshenv .tmux.conf .p10k.zsh wallpapers scripts screenshots)

  for file in "${FILES[@]}"; do
    if [ -f "$HOME/$file" ]; then
      echo "Backing up file: $file"
      mv "$HOME/$file" "$HOME/${file}${BACKUP_SUFFIX}"
    else
      echo "File $file not found; skipping backup"
    fi
  done
}

apply_dotfiles() {
  cd "$HOME/blomst" || { echo "Could not access $HOME/blomst"; exit 1; }
  stow .

  cd $HOME
}

install_yay() {
    if command -v yay >/dev/null; then
        echo "Yay is already installed. Skipping..."
        return 0
    fi

    run_network "Cloning Yay (Yet Another Yogurt)" "cd $HOME && rm -rf yay; git clone https://aur.archlinux.org/yay.git"

    run_loader "Building Yay" "cd $HOME/yay && echo '$PASSWORD' | sudo -S -v && makepkg -s --noconfirm"

    run_loader "Installing Yay Package" "cd $HOME/yay && echo '$PASSWORD' | sudo -S pacman -U --noconfirm *.pkg.tar.zst"

    run_loader "Cleaning up Yay build folder" "rm -rf $HOME/yay"
}

install_eww() {
    if command -v eww >/dev/null; then
        echo "Eww is already installed. Skipping build..."
        return 0
    fi

    run_network "Cloning Eww Repository" "cd $HOME && [ -d eww ] && rm -rf eww; git clone https://github.com/elkowar/eww"

    run_loader "Compiling Eww (Cargo Build)" "cd $HOME/eww && cargo build --release --no-default-features --features=wayland"

    run_loader "Installing Eww Binary to /usr/local/bin" "cd $HOME/eww/target/release && chmod +x ./eww && echo '$PASSWORD' | sudo -S cp ./eww /usr/local/bin/"

    run_loader "Cleaning up Eww source" "cd $HOME && rm -rf eww"
}

setup_scripts() {
    run_loader "Executing Hyprland Setup" "bash $HOME/scripts/hypr_setup.sh"

    run_loader "Executing Zsh Configuration" "bash $HOME/scripts/zsh_setup.sh"

    run_loader "Normalizing Wallpapers" "bash $HOME/scripts/normalize_wallpaper.sh"
}

setup_network() {
    # Only turns NetworkManager on (the wifi menu uses it). DNS and other network settings are left alone.
    run_loader "Enabling NetworkManager" "echo '$PASSWORD' | sudo -S systemctl enable --now NetworkManager"
}

setup_bluetooth() {
    run_loader "Enabling & Starting Bluetooth Service" "echo '$PASSWORD' | sudo -S systemctl enable --now bluetooth.service"

    run_loader "Configuring Bluetooth Audio modules" "echo '$PASSWORD' | sudo -S pactl load-module module-bluetooth-discover 2>/dev/null || true"
}

setup_shell() {
    if ! grep -q "/usr/bin/zsh" /etc/shells; then
        run_loader "Adding Zsh to Valid Shells" "echo '/usr/bin/zsh' | echo '$PASSWORD' | sudo -S tee -a /etc/shells"
    fi

    run_loader "Changing Default Shell to Zsh" "echo '$PASSWORD' | sudo -S chsh -s /usr/bin/zsh $USER"
}

# Password Initialization for Sudo
clear
echo "    ┓ ┓"
echo "    ┣┓┃┏┓┏┳┓┏╋"
echo "    ┗┛┗┗┛┛┗┗┛┗"
echo -e "${NC}"

while true; do
    echo -n "  Input sudo password: "
    read -s PASSWORD
    echo ""

    if echo "$PASSWORD" | sudo -S -k -v > /dev/null 2>&1; then
        echo -e "${GREEN}  [OK] Password confirmed. Installation started...${NC}\n"
        break
    else
        echo -e "${RED}  [ERROR] Wrong password! Please try again.${NC}"
    fi
done


# Install necessary packages via pacman
run_network "Syncing mirror & Installing base packages" "run_sudo pacman -Syu --needed --noconfirm base-devel rustup github-cli stow pamixer brightnessctl playerctl rofi-wayland hyprlock hypridle hyprpaper yazi neovim bottom networkmanager rustup zsh imagemagick acpi pavucontrol lua51 lua51-luarocks xdg-desktop-portal-hyprland xdg-desktop-portal-gtk gtk4 gtk3 qt6ct kvantum noto-fonts go matugen pyside6 qt6-wayland ddcutil lm_sensors curl python"

# Install Rust toolchain
run_network "Setting up Rust Toolchain" "rustup default stable"

# Backup Existing Config
run_loader "Backing up existing Configurations" "backup_configs"

# Apply Blomst dotfiles
run_loader  "Applying blomst dotfiles via Stow" "apply_dotfiles"

# Install yay (AUR helper)
install_yay

# Install additional packages via yay
run_network "Installing AUR Packages" "echo '$PASSWORD' | yay -S --needed --noconfirm --sudoloop fastfetch ttf-iosevka otf-hermit-nerd gvfs dbus libdbusmenu-glib libdbusmenu-gtk3 gtk-layer-shell zoxide eza fzf jq socat tmux nvm btop hyprshot bluez bluez-utils bluez-obex bluetuith python-gobject zsh-theme-powerlevel10k-git"

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
echo -e "\n${GREEN}Installation complete. The system will now reboot. ${NC}"
sleep 3 
run_sudo reboot

