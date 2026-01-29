#!/usr/bin/env bash

YW=`echo "\033[33m"`
RD=`echo "\033[01;31m"`
BL=`echo "\033[36m"`
GN=`echo "\033[1;92m"`
CL=`echo "\033[m"`
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"
HOLD="-"

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
    local msg="$1"
    echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

msg_info "Installing XFCE Desktop Environment"
apt-get update &>/dev/null
apt-get install -y xfce4 xfce4-goodies &>/dev/null
msg_ok "Installed XFCE"

msg_info "Setting password for kodi user"
echo -e "\n${YW}Please set a password for the kodi user:${CL}"
passwd kodi
msg_ok "Password set for kodi user"

msg_info "Installing GNOME Software and Flatpak support"
apt-get install -y gnome-software gnome-software-plugin-flatpak flatpak &>/dev/null
msg_ok "Installed GNOME Software and Flatpak"

msg_info "Adding Flathub repository"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &>/dev/null
msg_ok "Added Flathub repository"

# read -p "Do you want to install Steam? (y/n): " -n 1 -r
# echo
# if [[ $REPLY =~ ^[Yy]$ ]]
# then
#     msg_info "Installing Steam"
#     dpkg --add-architecture i386 &>/dev/null
#     apt-get update &>/dev/null
#     apt-get install -y steam &>/dev/null
#     apt-get install -y -f &>/dev/null
#     msg_ok "Installed Steam"
# else
#     msg_info "Skipping Steam installation"
#     msg_ok "Creating Steam installer script on desktop"
    
#     # Create steam installer script
#     mkdir -p /home/kodi/Desktop
#     cat <<'STEAMEOF' >/home/kodi/Desktop/install-steam.sh
# #!/usr/bin/env bash

# YW=`echo "\033[33m"`
# RD=`echo "\033[01;31m"`
# GN=`echo "\033[1;92m"`
# CL=`echo "\033[m"`
# CM="${GN}✓${CL}"
# BFR="\\r\\033[K"
# HOLD="-"

# function msg_info() {
#     local msg="$1"
#     echo -ne " ${HOLD} ${YW}${msg}..."
# }

# function msg_ok() {
#     local msg="$1"
#     echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
# }

# # Check if running as root
# if [ "$EUID" -ne 0 ]; then 
#     echo "Please run with: sudo bash ~/Desktop/install-steam.sh"
#     read -p "Press Enter to exit..."
#     exit 1
# fi

# msg_info "Enabling 32-bit architecture"
# dpkg --add-architecture i386
# msg_ok "Enabled 32-bit architecture"

# msg_info "Updating package lists"
# apt-get update &>/dev/null
# msg_ok "Updated package lists"

# msg_info "Installing Steam"
# apt-get install -y steam &>/dev/null
# msg_ok "Installed Steam"

# msg_info "Installing dependencies"
# apt-get install -y -f &>/dev/null
# msg_ok "Installed dependencies"

# echo -e "\n${GN}Steam installation complete!${CL}"
# echo -e "You can launch Steam from the XFCE Applications menu."
# echo -e "\nThis script will now be deleted."
# read -p "Press Enter to exit..."

# # Self-delete
# rm -- "$0"
# STEAMEOF
    
#     chmod +x /home/kodi/Desktop/install-steam.sh
#     chown kodi:kodi /home/kodi/Desktop/install-steam.sh
# fi

msg_info "Configuring lightdm to boot into XFCE"
cat <<EOF >/etc/lightdm/lightdm.conf.d/autologin-kodi.conf
[Seat:*]
autologin-user=kodi
autologin-session=xfce
EOF
msg_ok "Configured lightdm for XFCE"

msg_info "Setting up Kodi autostart in XFCE"
mkdir -p /home/kodi/.config/autostart
cat <<EOF >/home/kodi/.config/autostart/kodi.desktop
[Desktop Entry]
Type=Application
Name=Kodi
Exec=kodi
X-XFCE-Autostart-enabled=true
EOF
chown -R kodi:kodi /home/kodi/.config
msg_ok "Set up Kodi autostart"

msg_info "Setting up PolicyKit permissions"
mkdir -p /etc/polkit-1/localauthority/50-local.d
cat <<EOF >/etc/polkit-1/localauthority/50-local.d/allow-shutdown.pkla
[Allow kodi user to shutdown]
Identity=unix-user:kodi
Action=org.freedesktop.login1.power-off;org.freedesktop.login1.power-off-multiple-sessions;org.freedesktop.login1.reboot;org.freedesktop.login1.reboot-multiple-sessions
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF

cat <<EOF >/etc/polkit-1/localauthority/50-local.d/allow-package-management.pkla
[Allow kodi user to install packages]
Identity=unix-user:kodi
Action=org.debian.apt.*;org.freedesktop.packagekit.*
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF
msg_ok "Set up PolicyKit permissions"

msg_info "Restarting lightdm"
systemctl restart lightdm
msg_ok "Restarted lightdm"

echo -e "\n${GN}Setup complete!${CL}"
echo -e "Your LXC will now:"
echo -e "  1. Boot into XFCE"
echo -e "  2. Automatically launch Kodi"
echo -e "  3. Fall back to XFCE desktop when you exit Kodi"
echo -e "  4. Allow shutdown/reboot from XFCE menu"
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "  5. Steam can be installed later using the script on the desktop"
fi
