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
