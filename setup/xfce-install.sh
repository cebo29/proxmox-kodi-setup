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

msg_info "Adding kodi user to sudo group"
usermod -aG sudo kodi
msg_ok "Added kodi user to sudo group"

echo -e "\n${GN}=== Optional Software Installation ===${CL}"
echo -e "Select which applications you want to install:"
echo ""

# Firefox
read -p "Install Firefox? (y/n): " -n 1 -r INSTALL_FIREFOX
echo

# Brave Browser
read -p "Install Brave Browser? (y/n): " -n 1 -r INSTALL_BRAVE
echo

# Google Chrome
read -p "Install Google Chrome? (y/n): " -n 1 -r INSTALL_CHROME
echo

# LibreOffice
read -p "Install LibreOffice? (y/n): " -n 1 -r INSTALL_LIBREOFFICE
echo

# VLC Media Player
read -p "Install VLC Media Player? (y/n): " -n 1 -r INSTALL_VLC
echo

# GIMP
read -p "Install GIMP (Image Editor)? (y/n): " -n 1 -r INSTALL_GIMP
echo

# Steam
read -p "Install Steam? (y/n): " -n 1 -r INSTALL_STEAM
echo

echo ""

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

cat <<EOF >/etc/polkit-1/localauthority/50-local.d/allow-all.pkla
[Allow kodi user all permissions]
Identity=unix-user:kodi
Action=*
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF

msg_ok "Set up PolicyKit permissions"

# Install selected applications
echo -e "\n${GN}=== Installing Selected Applications ===${CL}\n"

if [[ $INSTALL_FIREFOX =~ ^[Yy]$ ]]; then
    msg_info "Installing Firefox"
    apt-get install -y firefox &>/dev/null
    msg_ok "Installed Firefox"
fi

if [[ $INSTALL_BRAVE =~ ^[Yy]$ ]]; then
    msg_info "Installing Brave Browser"
    apt-get install -y curl &>/dev/null
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg &>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list &>/dev/null
    apt-get update &>/dev/null
    apt-get install -y brave-browser &>/dev/null
    msg_ok "Installed Brave Browser"
fi

if [[ $INSTALL_CHROME =~ ^[Yy]$ ]]; then
    msg_info "Installing Google Chrome"
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb &>/dev/null
    apt-get install -y /tmp/chrome.deb &>/dev/null
    rm /tmp/chrome.deb
    msg_ok "Installed Google Chrome"
fi

if [[ $INSTALL_LIBREOFFICE =~ ^[Yy]$ ]]; then
    msg_info "Installing LibreOffice"
    apt-get install -y libreoffice &>/dev/null
    msg_ok "Installed LibreOffice"
fi

if [[ $INSTALL_VLC =~ ^[Yy]$ ]]; then
    msg_info "Installing VLC Media Player"
    apt-get install -y vlc &>/dev/null
    msg_ok "Installed VLC Media Player"
fi

if [[ $INSTALL_GIMP =~ ^[Yy]$ ]]; then
    msg_info "Installing GIMP"
    apt-get install -y gimp &>/dev/null
    msg_ok "Installed GIMP"
fi

if [[ $INSTALL_STEAM =~ ^[Yy]$ ]]; then
    msg_info "Installing Steam"
    dpkg --add-architecture i386 &>/dev/null
    apt-get update &>/dev/null
    apt-get install -y steam &>/dev/null
    apt-get install -y -f &>/dev/null
    msg_ok "Installed Steam"
fi

# Create desktop launchers for skipped applications
mkdir -p /home/kodi/Desktop

if [[ ! $INSTALL_FIREFOX =~ ^[Yy]$ ]]; then
    cat <<'FIREFOXEOF' >/usr/local/bin/install-firefox.sh
#!/usr/bin/env bash
echo "Installing Firefox..."
apt-get update &>/dev/null
apt-get install -y firefox &>/dev/null
echo "Firefox installation complete!"
echo "The desktop launcher will now be deleted."
read -p "Press Enter to exit..."
rm -f /home/kodi/Desktop/install-firefox.desktop
rm -f "$0"
FIREFOXEOF
    chmod +x /usr/local/bin/install-firefox.sh
    
    cat <<EOF >/home/kodi/Desktop/install-firefox.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Install Firefox
Comment=Install Firefox browser
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-firefox.sh"
Terminal=false
Icon=firefox
Categories=System;
EOF
    chmod +x /home/kodi/Desktop/install-firefox.desktop
    chown kodi:kodi /home/kodi/Desktop/install-firefox.desktop
fi

if [[ ! $INSTALL_BRAVE =~ ^[Yy]$ ]]; then
    cat <<'BRAVEEOF' >/usr/local/bin/install-brave.sh
#!/usr/bin/env bash
echo "Installing Brave Browser..."
apt-get install -y curl &>/dev/null
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg &>/dev/null
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list &>/dev/null
apt-get update &>/dev/null
apt-get install -y brave-browser &>/dev/null
echo "Brave Browser installation complete!"
echo "The desktop launcher will now be deleted."
read -p "Press Enter to exit..."
rm -f /home/kodi/Desktop/install-brave.desktop
rm -f "$0"
BRAVEEOF
    chmod +x /usr/local/bin/install-brave.sh
    
    cat <<EOF >/home/kodi/Desktop/install-brave.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Install Brave
Comment=Install Brave Browser
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-brave.sh"
Terminal=false
Icon=brave-browser
Categories=System;
EOF
    chmod +x /home/kodi/Desktop/install-brave.desktop
    chown kodi:kodi /home/kodi/Desktop/install-brave.desktop
fi

if [[ ! $INSTALL_CHROME =~ ^[Yy]$ ]]; then
    cat <<'CHROMEEOF' >/usr/local/bin/install-chrome.sh
#!/usr/bin/env bash
echo "Installing Google Chrome..."
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb &>/dev/null
apt-get install -y /tmp/chrome.deb &>/dev/null
rm /tmp/chrome.deb
echo "Google Chrome installation complete!"
echo "The desktop launcher will now be deleted."
read -p "Press Enter to exit..."
rm -f /home/kodi/Desktop/install-chrome.desktop
rm -f "$0"
CHROMEEOF
    chmod +x /usr/local/bin/install-chrome.sh
    
    cat <<EOF >/home/kodi/Desktop/install-chrome.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Install Chrome
Comment=Install Google Chrome browser
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-chrome.sh"
Terminal=false
Icon=google-chrome
Categories=System;
EOF
    chmod +x /home/kodi/Desktop/install-chrome.desktop
    chown kodi:kodi /home/kodi/Desktop/install-chrome.desktop
fi

if [[ ! $INSTALL_LIBREOFFICE =~ ^[Yy]$ ]]; then
    cat <<'LIBREEOF' >/usr/local/bin/install-libreoffice.sh
#!/usr/bin/env bash
echo "Installing LibreOffice..."
echo "This may take a few minutes..."
apt-get update &>/dev/null
apt-get install -y libreoffice &>/dev/null
echo "LibreOffice installation complete!"
echo "The desktop launcher will now be deleted."
read -p "Press Enter to exit..."
rm -f /home/kodi/Desktop/install-libreoffice.desktop
rm -f "$0"
LIBREEOF
    chmod +x /usr/local/bin/install-libreoffice.sh
    
    cat <<EOF >/home/kodi/Desktop/install-libreoffice.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Install LibreOffice
Comment=Install LibreOffice suite
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-libreoffice.sh"
Terminal=false
Icon=libreoffice-main
Categories=System;
EOF
    chmod +x /home/kodi/Desktop/install-libreoffice.desktop
    chown kodi:kodi /home/kodi/Desktop/install-libreoffice.desktop
fi

if [[ ! $INSTALL_VLC =~ ^[Yy]$ ]]; then
    cat <<'VLCEOF' >/usr/local/bin/install-vlc.sh
#!/usr/bin/env bash
echo "Installing VLC Media Player..."
apt-get update &>/dev/null
apt-get install -y vlc &>/dev/null
echo "VLC Media Player installation complete!"
echo "The desktop launcher will now be deleted."
read -p "Press Enter to exit..."
rm -f /home/kodi/Desktop/install-vlc.desktop
rm -f "$0"
VLCEOF
    chmod +x /usr/local/bin/install-vlc.sh
    
    cat <<EOF >/home/kodi/Desktop/install-vlc.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Install VLC
Comment=Install VLC Media Player
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-vlc.sh"
Terminal=false
Icon=vlc
Categories=System;
EOF
    chmod +x /home/kodi/Desktop/install-vlc.desktop
    chown kodi:kodi /home/kodi/Desktop/install-vlc.desktop
fi

if [[ ! $INSTALL_GIMP =~ ^[Yy]$ ]]; then
    cat <<'GIMPEOF' >/usr/local/bin/install-gimp.sh
#!/usr/bin/env bash
echo "Installing GIMP..."
apt-get update &>/dev/null
apt-get install -y gimp &>/dev/null
echo "GIMP installation complete!"
echo "The desktop launcher will now be deleted."
read -p "Press Enter to exit..."
rm -f /home/kodi/Desktop/install-gimp.desktop
rm -f "$0"
GIMPEOF
    chmod +x /usr/local/bin/install-gimp.sh
    
    cat <<EOF >/home/kodi/Desktop/install-gimp.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Install GIMP
Comment=Install GIMP image editor
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-gimp.sh"
Terminal=false
Icon=gimp
Categories=System;
EOF
    chmod +x /home/kodi/Desktop/install-gimp.desktop
    chown kodi:kodi /home/kodi/Desktop/install-gimp.desktop
fi

if [[ ! $INSTALL_STEAM =~ ^[Yy]$ ]]; then
    cat <<'STEAMEOF' >/usr/local/bin/install-steam.sh
#!/usr/bin/env bash

YW=$(echo "\033[33m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
CM="${GN}✓${CL}"
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

msg_info "Enabling 32-bit architecture"
dpkg --add-architecture i386
msg_ok "Enabled 32-bit architecture"

msg_info "Updating package lists"
apt-get update &>/dev/null
msg_ok "Updated package lists"

msg_info "Installing Steam"
apt-get install -y steam &>/dev/null
msg_ok "Installed Steam"

msg_info "Installing dependencies"
apt-get install -y -f &>/dev/null
msg_ok "Installed dependencies"

echo -e "\n${GN}Steam installation complete!${CL}"
echo -e "You can launch Steam from the XFCE Applications menu."
echo -e "\nThe desktop launcher will now be deleted."
read -p "Press Enter to exit..."

# Remove desktop launcher and self
rm -f /home/kodi/Desktop/install-steam.desktop
rm -f "$0"
STEAMEOF
    chmod +x /usr/local/bin/install-steam.sh
    
    cat <<EOF >/home/kodi/Desktop/install-steam.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Install Steam
Comment=Install Steam and dependencies
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-steam.sh"
Terminal=false
Icon=steam
Categories=System;
EOF
    chmod +x /home/kodi/Desktop/install-steam.desktop
    chown kodi:kodi /home/kodi/Desktop/install-steam.desktop
fi

msg_info "Restarting lightdm"
systemctl restart lightdm
msg_ok "Restarted lightdm"

echo -e "\n${GN}Setup complete!${CL}"
echo -e "Your LXC will now:"
echo -e "  1. Boot into XFCE"
echo -e "  2. Automatically launch Kodi"
echo -e "  3. Fall back to XFCE desktop when you exit Kodi"
echo -e "  4. Allow shutdown/reboot from XFCE menu"
echo -e "  5. Kodi user has full sudo access"

# Count skipped apps
SKIPPED=0
[[ ! $INSTALL_STEAM =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_FIREFOX =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_BRAVE =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_CHROME =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_LIBREOFFICE =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_VLC =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_GIMP =~ ^[Yy]$ ]] && ((SKIPPED++))

if [ $SKIPPED -gt 0 ]; then
    echo -e "  6. ${SKIPPED} app installer(s) available on desktop for later installation"
fi
