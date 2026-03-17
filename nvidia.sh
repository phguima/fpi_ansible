# Function: prompt
# Description: Centralizes output logging with color coding using flags.
# Usage: prompt <flag> <message>
# Flags:
#   -d  : Default (White)        | -db : Default Bold
#   -i  : Info (Blue)            | -ib : Info Bold
#   -w  : Warning (Yellow)       | -wb : Warning Bold
#   -e  : Error (Red)            | -eb : Error Bold
#   -g  : Debug (Cyan)           | -gb : Debug Bold
#   -s  : Success (Green)        | -sb : Success Bold
function prompt() {
    local flag="$1"
    local message="$2"
    local C_RESET='\033[0m'

    case "$flag" in
        -d)  echo -e "\033[0;37m${message}${C_RESET}" ;;  # White
        -db) echo -e "\033[1;37m${message}${C_RESET}" ;;  # White Bold
        -i)  echo -e "\033[0;34m${message}${C_RESET}" ;;  # Blue
        -ib) echo -e "\033[1;34m${message}${C_RESET}" ;;  # Blue Bold
        -w)  echo -e "\033[0;33m${message}${C_RESET}" ;;  # Yellow
        -wb) echo -e "\033[1;33m${message}${C_RESET}" ;;  # Yellow Bold
        -e)  echo -e "\033[0;31m${message}${C_RESET}" ;;  # Red
        -eb) echo -e "\033[1;31m${message}${C_RESET}" ;;  # Red Bold
        -g)  echo -e "\033[0;36m${message}${C_RESET}" ;;  # Cyan (Debug)
        -gb) echo -e "\033[1;36m${message}${C_RESET}" ;;  # Cyan Bold
        -s)  echo -e "\033[0;32m${message}${C_RESET}" ;;  # Green (Success)
        -sb) echo -e "\033[1;32m${message}${C_RESET}" ;;  # Green Bold
        *)   echo -e "${message}" ;;                       # Fallback
    esac
}

# Function: pause
# Description: Pauses execution until user presses Enter.
function pause() {
    read -rp "Press [Enter] to continue..."
}

# Function: sudo_check
# Description: Silent check to verify if the sudo session is currently active.
# Returns: 0 if active, non-zero otherwise.
function sudo_check() {
    sudo -n true 2> /dev/null
}

# Function: ensure_sudo
# Description: Ensures sudo privileges are cached, prompting user if needed.
function ensure_sudo() {
    while ! sudo_check; do
        prompt -eb "Sudo credentials are required to proceed."
        
        # Ask the password to the users
        sudo -v
        
        if [ $? -ne 0 ]; then
             prompt -e "Authentication failed. Trying again (or CTRL+C to exit)..."
        fi
    done

    prompt -s "Checking for sudo: activated..."
}

# Function: smart_update
# Description: Checks for system updates and applies them only if available.
# Returns: 0 if up to date, 100 if updates were applied, other codes for errors.
function smart_update() {
    prompt -wb "Checking for updates..."
    
    # --refresh forces a metadata update
    # check-update doesn't install anything, just checks
    sudo dnf check-update --refresh > /dev/null
    local exit_code=$?

    return $exit_code
}

# Function: check_command
# Description: Checks if a command exists; exits with error if not found.
function check_command() {
    command -v "$1" &> /dev/null
}

# Function: check_package
# Description: Checks if a package is installed via RPM
function check_package() {
    rpm -q "$1" &> /dev/null
}

# Function: check_exactly_repository
# Description: Checks if a DNF repository with the exact name is enabled
function check_exactly_repository() {
    sudo dnf repolist | grep -Eq "^$1[[:space:]]"
}

# Function: check_is_nvidia_gpu
# Description: Check if the system has an NVIDIA GPU
function check_is_nvidia_gpu() {
    # grep -E "VGA|3D": Filter only VGA or 3D controllers
    # grep -iq "nvidia": Search for NVIDIA ignoring case, in quiet mode    
    if lspci | grep -E "VGA|3D|Display" | grep -iq "nvidia"; then
        return 0
    else
        return 1
    fi
}

# Function: ask_reboot
# Description: Prompt user to reboot the system
function ask_reboot() {
    local reboot_now
    read -p "Reboot now? (Y/n): " reboot_now

    reboot_now=${reboot_now:-Y}
    case $reboot_now in
        [Yy]* ) 
            prompt -wb "Rebooting system..."
            sudo reboot
            ;;
        [Nn]* ) 
            prompt -wb "Skipping reboot. Please remember to reboot later to changes take effect..."
            ;;
        * ) 
            prompt -wb "Invalid input. Skipping reboot. Please remember to reboot later before using the nVidia drivers..."
            ;;
    esac
}

# Function: enable_RPMFusion
# Description: Enables RPMFusion repositories
function enable_RPMFusion() {
    prompt -db ""
    prompt -db "Enabling RPM Fusion free and nonfree repositories..."

    if [[ -f /etc/yum.repos.d/rpmfusion-free.repo || -f /etc/yum.repos.d/rpmfusion-nonfree.repo ]]; then
        prompt -db "RPM Fusion repositories already enabled... skipping."
        return
    fi

    ensure_sudo
    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    prompt -i "Refreshing repository metadata..."
    sudo dnf makecache
    prompt -sb "RPM Fusion repositories enabled!"
}

# Function: nvidia_warning
# Description: Show nVidia installation warning and instructions
function nvidia_warning() {
    prompt -d ""
    prompt -wb ">>> IMPORTANT <<<"
    prompt -db "Please read the instructions below carefully before proceeding."
    prompt -d ""
    prompt -d "Installing nVidia drivers requires some manual procedures."
    prompt -d ""
    prompt -d "Some packages will be installed and a key for secure boot will be created"
    prompt -d "to be enrolled in the system on the next reboot."
    prompt -d ""
    prompt -w ">> A password must be created when prompted. <<"
    prompt -d ""
    prompt -d "The password does not need to be complex and should be easy to memorize as it will"
    prompt -d "be requested the next time the system is started."
    prompt -d ""
    prompt -d "After this, the script will ask if it should restart the system automatically (recommended)"
    prompt -d "or if you want to restart later."
    prompt -d ""
    prompt -d ">> It is important to remember this password cause the procedure can only be completed after"
    prompt -d "restarting the system and enrolling the kernel key in secure boot. <<"
    prompt -d ""
    prompt -d "When the system restarts, the secure boot key enrollment system will be displayed"
    prompt -d "on the screen. This procedure is part of the BIOS and must be performed for the drivers"
    prompt -d "to be successfully installed."
    prompt -d ""
    prompt -d ">> This screen will ask for the key that was created in the step before restarting the system. <<"
    prompt -d ""
    prompt -d "The steps are described below:"
    prompt -d ""
    prompt -w "1. Select \“Enroll MOK\“."
    prompt -w "2. Click on \“Continue\“."
    prompt -w "3. Select \“Yes\“ and enter the password generated in the previous step"
    prompt -w "4. Select \"OK\" and your computer will restart again"
    prompt -d ""
}

# Function: install_nvidia
# Description: Install nVidia proprietary drivers
function install_nvidia() {
    prompt -db ""
    prompt -db "Preparing to install nVidia proprietary drivers..."

    if ! check_is_nvidia_gpu; then
        prompt -eb "No nVidia GPU detected. Skipping nVidia driver installation."
        return
    fi

    # Print warning and instructions for nVidia installation
    nvidia_warning
    pause
    
    local target_first_packages=("akmods" "kmodtool" "openssl" "mokutil")
    local target_second_packages=("akmod-nvidia" "gcc" "kernel-devel" "kernel-headers" "xorg-x11-drv-nvidia" "xorg-x11-drv-nvidia-cuda" "xorg-x11-drv-nvidia-libs" "xorg-x11-drv-nvidia-libs.i686")
    local packages_to_first_install=()
    local packages_to_second_install=()

    if check_command "nvidia-smi"; then
        prompt -wb "nVidia proprietary drivers are already installed. Skipping..."
        return
    fi

    # RPMFusion is required for nVidia drivers
    # Checks if the nonfree repository is enabled and call the enabling function if not
    if ! check_exactly_repository "rpmfusion-nonfree"; then
        prompt -wb "RPMFusion Non-Free repository is required but not found."
        prompt -db "Enabling RPMFusion first..."
        enable_RPMFusion
    fi

    prompt -db "Checking for system updates before installing nVidia drivers..."
    ensure_sudo
    smart_update
    local exit_code=$? 

    if [ $exit_code -eq 100 ]; then
        prompt -ib "Updates available. Starting upgrade..."
        if sudo dnf upgrade --refresh -y; then
            prompt -s "System upgraded successfully!"
            prompt -wb "A system reboot is recommended before proceeding with the nVidia driver installation."
            ask_reboot
        else
            prompt -eb "Upgrade failed."
        fi
    elif [ $exit_code -eq 0 ]; then
        prompt -s "System is already up to date. Nothing to do."
    else
        prompt -eb "Error checking for updates (DNS or Repo issue). Exiting nVidia installation..."
        return 1
    fi

    # Explicitly enable the openh264 library repository if not already enabled
    sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1

    # Check prerequisite packages
    prompt -db "Checking prerequisites for nVidia driver installation..."
    for pkg in "${target_first_packages[@]}"; do
        if ! check_package "$pkg"; then
            prompt -w " - $pkg: NOT FOUND"
            packages_to_first_install+=("$pkg")
        else
            prompt -i " - $pkg: OK"
        fi
    done

    # Install prerequisite packages if needed
    if [ ${#packages_to_first_install[@]} -ne 0 ]; then
        prompt -i "Installing prerequisite packages..."
        ensure_sudo

        if ! sudo dnf install -y "${packages_to_first_install[@]}"; then
            prompt -eb "Error installing prerequisite packages."
            return 1
        fi

        # Generate the MOK key for Secure Boot
        prompt -db "Generating MOK key for Secure Boot..."
        sudo kmodgenca -a

        # Ask BIOS/UEFI to enroll the key on next reboot
        prompt -ib "Asking BIOS/UEFI to enroll the key on next reboot..."
        sudo mokutil --import /etc/pki/akmods/certs/public_key.der

        prompt -wb "A system reboot is required to complete the MOK key enrollment."
        prompt -wb "Please reboot now and follow the on-screen instructions."
        prompt -wb "After completing the MOK enrollment, please re-run this nVidia installation."
        prompt -wb "If you prefer to reboot later, you can do so but it will break the nVidia installation."
        prompt -wb ">>> Remember the password you created for MOK enrollment! <<<"
        prompt -wb "It's strongly recommended to reboot now."
        ask_reboot
    else
        prompt -s "All prerequisite packages are already installed. Continuing..."
    fi

    # Check nVidia packages
    prompt -db "Checking prerequisites for nVidia driver installation..."
    for pkg in "${target_second_packages[@]}"; do
        if ! check_package "$pkg"; then
            prompt -w " - $pkg: NOT FOUND"
            packages_to_second_install+=("$pkg")
        else
            prompt -i " - $pkg: OK"
        fi
    done

    # Install nVidia packages if needed
    if [ ${#packages_to_second_install[@]} -ne 0 ]; then
        prompt -i "Installing nVidia packages..."
        ensure_sudo

        if ! sudo dnf install -y "${packages_to_second_install[@]}"; then
            prompt -eb "Error installing nVidia packages."
            return 1
        fi

        prompt -ib "Waiting for kernel modules (akmods) to build..."
        prompt -w "This may take a few minutes. Please do not close."

        # Wait 2 seconds to ensure the process has started (if just installed)
        sleep 2

        # While (while) the 'akmods' or 'rpmbuild' process is running...
        # pgrep returns 0 if it finds the process, keeping the loop alive
        while pgrep -f "akmods" > /dev/null || pgrep -f "rpmbuild" > /dev/null; do
            # Print a dot without a newline (-n)
            echo -ne "."
            sleep 2
        done

        # Skip a line at the end to clear formatting
        echo "" 
        prompt -sb "Kernel modules built successfully!"

        prompt -db "Forcing akmods and dracut to ensure modules are properly set up..."
        sudo akmods --force
        sudo dracut --force

        ask_reboot
    else
        prompt -s "All nVidia packages are already installed. Nothing to do."
    fi

    # Prevent autoremove to consider akmod-nvidia as uneeded
    sudo dnf mark user akmod-nvidia

    # Experimental scripts to enable clean resume on suspend to RAM or suspend to disk (hibernate)
    #if ! check_package "xorg-x11-drv-nvidia-power"; then
    #    prompt -db "Installing nVidia power management scripts for suspend/hibernate..."
    #else
    #    prompt -s "nVidia power management scripts are already installed. Skipping..."
    #fi

    # Enabling the nVidia suspend, resume and hibernate services
    #sudo systemctl enable nvidia-{suspend,resume,hibernate}

    # Installing Vulkan support packages
    if ! check_package "vulkan"; then
        prompt -db "Installing Vulkan support packages..."
        ensure_sudo
        sudo dnf install -y vulkan
        prompt -s "Vulkan support package installed."
    else
        prompt -s "Vulkan support package are already installed. Skipping..."
    fi

    # NVENC/NVDEC support
    prompt -db "Installing NVENC/NVDEC support packages..."
    ensure_sudo
    sudo dnf install xorg-x11-drv-nvidia-cuda-libs

    prompt -sb "nVidia proprietary drivers installation complete!"
}

# Function: main_menu
# Description: Main application menu
function main_menu() {
    while true; do
        clear
        prompt -ib "=== NVIDIA Proprietary Driver Installer (signed) ==="
        echo "1. Install NVIDIA proprietary driver (signed)"
        echo "0. Exit"
        echo ""
        read -p "Select an option: " choice

        case $choice in
            1) prompt -i "Installing NVIDIA proprietary drivers..." ; install_nvidia ; pause ;;
            0) prompt -s "Exiting..." ; exit 0 ;;
            *) prompt -e "Invalid option." ; pause ;;
        esac
    done
}

# Main execution starts here
main_menu