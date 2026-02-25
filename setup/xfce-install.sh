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

# Initialize app installation variables with defaults
INSTALL_FIREFOX="${INSTALL_FIREFOX:-n}"
INSTALL_BRAVE="${INSTALL_BRAVE:-n}"
INSTALL_CHROME="${INSTALL_CHROME:-n}"
INSTALL_LIBREOFFICE="${INSTALL_LIBREOFFICE:-n}"
INSTALL_VLC="${INSTALL_VLC:-n}"
INSTALL_GIMP="${INSTALL_GIMP:-n}"
INSTALL_STEAM="${INSTALL_STEAM:-n}"

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

msg_info "Creating kodi user"
if ! id -u kodi &>/dev/null; then
    useradd -m -s /bin/bash kodi
    msg_ok "Created kodi user"
else
    msg_ok "Kodi user already exists"
fi

msg_info "Setting password for kodi user"
if [ -n "$KODI_PASS" ]; then
    echo "kodi:$KODI_PASS" | chpasswd
    msg_ok "Password set for kodi user"
else
    echo -e "\n${YW}Please set a password for the kodi user:${CL}"
    passwd kodi
    msg_ok "Password set for kodi user"
fi

msg_info "Adding kodi user to sudo and device access groups"
usermod -aG sudo,audio,input,video,render kodi
msg_ok "Added kodi user to sudo and device access groups"

# Parse INSTALL_APPS to check for Kodi
KODI_EXEC=""
if [ -n "$INSTALL_APPS" ]; then
    if [[ "$INSTALL_APPS" == *"KODI_PPA"* ]]; then
        msg_info "Installing Kodi from PPA"
        apt-get install -y software-properties-common &>/dev/null
        add-apt-repository -y ppa:team-xbmc/ppa &>/dev/null
        apt-get update &>/dev/null
        apt-get install -y kodi &>/dev/null
        if command -v kodi &> /dev/null; then
            KODI_EXEC="kodi"
            msg_ok "Installed Kodi from PPA (version 20.x)"
        else
            msg_error "Kodi installation failed"
        fi
    elif [[ "$INSTALL_APPS" == *"KODI_FLATPAK"* ]]; then
        msg_info "Installing Kodi via Flatpak"
        apt-get install -y flatpak &>/dev/null
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &>/dev/null
        flatpak install -y flathub tv.kodi.Kodi &>/dev/null
        if flatpak list | grep -q "tv.kodi.Kodi"; then
            KODI_EXEC="flatpak run tv.kodi.Kodi"
            msg_ok "Installed Kodi via Flatpak (version 21.x)"
        else
            msg_error "Kodi Flatpak installation failed"
        fi
    fi
    
    # Parse other apps
    [[ "$INSTALL_APPS" == *"FIREFOX"* ]] && INSTALL_FIREFOX="y" || INSTALL_FIREFOX="n"
    [[ "$INSTALL_APPS" == *"BRAVE"* ]] && INSTALL_BRAVE="y" || INSTALL_BRAVE="n"
    [[ "$INSTALL_APPS" == *"CHROME"* ]] && INSTALL_CHROME="y" || INSTALL_CHROME="n"
    [[ "$INSTALL_APPS" == *"LIBREOFFICE"* ]] && INSTALL_LIBREOFFICE="y" || INSTALL_LIBREOFFICE="n"
    [[ "$INSTALL_APPS" == *"VLC"* ]] && INSTALL_VLC="y" || INSTALL_VLC="n"
    [[ "$INSTALL_APPS" == *"GIMP"* ]] && INSTALL_GIMP="y" || INSTALL_GIMP="n"
    [[ "$INSTALL_APPS" == *"STEAM"* ]] && INSTALL_STEAM="y" || INSTALL_STEAM="n"
else
    # Fallback to interactive prompts if INSTALL_APPS not set
    echo -e "\n${GN}=== Optional Software Installation ===${CL}"
    echo -e "Select which applications you want to install:"
    echo ""
    
    # Ask about Kodi first
    read -p "Install Kodi? (1=PPA/2=Flatpak/n=No): " -n 1 -r KODI_CHOICE
    echo
    if [ "$KODI_CHOICE" = "1" ]; then
        msg_info "Installing Kodi from PPA"
        apt-get install -y software-properties-common &>/dev/null
        add-apt-repository -y ppa:team-xbmc/ppa &>/dev/null
        apt-get update &>/dev/null
        apt-get install -y kodi &>/dev/null
        if command -v kodi &> /dev/null; then
            KODI_EXEC="kodi"
            msg_ok "Installed Kodi from PPA (version 20.x)"
        fi
    elif [ "$KODI_CHOICE" = "2" ]; then
        msg_info "Installing Kodi via Flatpak"
        apt-get install -y flatpak &>/dev/null
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &>/dev/null
        flatpak install -y flathub tv.kodi.Kodi &>/dev/null
        if flatpak list | grep -q "tv.kodi.Kodi"; then
            KODI_EXEC="flatpak run tv.kodi.Kodi"
            msg_ok "Installed Kodi via Flatpak (version 21.x)"
        fi
    fi
    
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
fi

msg_info "Configuring lightdm to boot into XFCE"
if ! command -v lightdm &> /dev/null; then
    apt-get install -y lightdm lightdm-gtk-greeter &>/dev/null
fi

mkdir -p /etc/lightdm/lightdm.conf.d
cat <<EOF >/etc/lightdm/lightdm.conf.d/autologin-kodi.conf
[Seat:*]
autologin-user=kodi
autologin-session=xfce
EOF
msg_ok "Configured lightdm for XFCE"

msg_info "Setting up device detection for xorg"
apt-get install -y xserver-xorg-input-evdev &>/dev/null
# Following script needs to be executed before Xorg starts to enumerate all input devices
mkdir -p /etc/X11/xorg.conf.d
cat >/usr/local/bin/preX-populate-input.sh << '__EOF__'
#!/usr/bin/env bash

### Creates config file for X with all currently present input devices
#   after connecting new device restart X (systemctl restart lightdm)
######################################################################

cat >/etc/X11/xorg.conf.d/10-lxc-input.conf << '_EOF_'
Section "ServerFlags"
     Option "AutoAddDevices" "True"
EndSection
_EOF_

cd /dev/input
for input in event*
do
cat >> /etc/X11/xorg.conf.d/10-lxc-input.conf <<_EOF_
Section "InputDevice"
    Identifier "$input"
    Option "Device" "/dev/input/$input"
    Option "AutoServerLayout" "true"
    Driver "evdev"
EndSection
_EOF_
done
__EOF__
chmod +x /usr/local/bin/preX-populate-input.sh
mkdir -p /etc/systemd/system/lightdm.service.d
cat > /etc/systemd/system/lightdm.service.d/override.conf << '__EOF__'
[Service]
ExecStartPre=/bin/sh -c '/usr/local/bin/preX-populate-input.sh'
SupplementaryGroups=video render input audio tty
__EOF__
systemctl daemon-reload
msg_ok "Set up device detection for xorg"

msg_info "Setting up Kodi autostart in XFCE"
if [ -n "$KODI_EXEC" ]; then
    # Check if autostart is enabled (default to yes)
    if [ "${KODI_AUTOSTART:-yes}" = "yes" ]; then
        mkdir -p /home/kodi/.config/autostart
        cat > /home/kodi/.config/autostart/kodi.desktop <<KODIEOF
[Desktop Entry]
Type=Application
Name=Kodi
Exec=$KODI_EXEC
X-XFCE-Autostart-enabled=true
KODIEOF
        chown -R kodi:kodi /home/kodi/.config
        msg_ok "Set up Kodi autostart"
    else
        msg_info "Kodi installed but autostart disabled (launch manually from menu)"
    fi
else
    msg_info "Kodi not installed, skipping autostart setup"
fi

# Set up Kodi exit monitor service to restart panel after Kodi exits
if [ -n "$KODI_EXEC" ] && [ "${KODI_AUTOSTART:-yes}" = "yes" ]; then
    msg_info "Setting up Kodi exit monitor service"
    
    cat > /etc/systemd/system/kodi-exit-monitor.service <<'KODIMONEOF'
[Unit]
Description=Monitor Kodi Process and Restart XFCE Panel
After=lightdm.service
Requires=lightdm.service

[Service]
Type=simple
User=kodi
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/home/kodi/.Xauthority"
Restart=always
RestartSec=5
ExecStart=/usr/local/bin/kodi-exit-monitor.sh

[Install]
WantedBy=multi-user.target
KODIMONEOF

    cat > /usr/local/bin/kodi-exit-monitor.sh <<'KODIMONSCRIPT'
#!/bin/bash

# Get kodi user's UID for proper session access
KODI_UID=$(id -u kodi)
export XDG_RUNTIME_DIR="/run/user/${KODI_UID}"
export DISPLAY=:0
export XAUTHORITY=/home/kodi/.Xauthority

# Wait for X server to be ready
while [ ! -e "$XAUTHORITY" ]; do
    sleep 1
done

# Wait for Kodi to start
while ! pgrep -x "kodi.bin" > /dev/null; do
    sleep 2
done

# Wait for Kodi to exit
while pgrep -x "kodi.bin" > /dev/null; do
    sleep 2
done

# Restart the XFCE panel after Kodi exits
# Kill existing panel
killall xfce4-panel 2>/dev/null
sleep 2

# Start panel as kodi user with proper environment
su - kodi -c "DISPLAY=:0 XAUTHORITY=/home/kodi/.Xauthority xfce4-panel" &

# Give it time to start
sleep 2

# Verify it started
if pgrep -x "xfce4-panel" > /dev/null; then
    logger "kodi-exit-monitor: Panel restarted successfully"
else
    logger "kodi-exit-monitor: Panel restart FAILED"
    # Try one more time with explicit display
    su - kodi -c "DISPLAY=:0 xfce4-panel" &
fi
KODIMONSCRIPT

    chmod +x /usr/local/bin/kodi-exit-monitor.sh
    systemctl daemon-reload
    systemctl enable kodi-exit-monitor.service
    
    msg_ok "Set up Kodi exit monitor service"
    echo -e "${YW}  Note: Panel restart may affect shutdown button permissions from XFCE menu${CL}"
    echo -e "${YW}  Use desktop Shutdown/Reboot shortcuts instead${CL}"
fi

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

msg_info "Setting up PulseAudio"
apt-get install -y pulseaudio pulseaudio-utils pavucontrol alsa-utils &>/dev/null
msg_ok "Installed PulseAudio packages"

msg_info "Creating desktop shortcuts"
mkdir -p /home/kodi/Desktop

# Volume Control shortcut
cat > /home/kodi/Desktop/Volume-Control.desktop <<'VOLEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Volume Control
Comment=ALSA Mixer Volume Control
Exec=xfce4-terminal --title="Volume Control" -e "alsamixer"
Icon=multimedia-volume-control
Terminal=false
Categories=AudioVideo;Audio;
VOLEOF
chmod +x /home/kodi/Desktop/Volume-Control.desktop
chown kodi:kodi /home/kodi/Desktop/Volume-Control.desktop
sudo -u kodi gio set /home/kodi/Desktop/Volume-Control.desktop metadata::trusted true 2>/dev/null || true

# Shutdown shortcut
cat > /home/kodi/Desktop/Shutdown.desktop <<'SHUTEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Shutdown
Comment=Shutdown the system
Exec=systemctl poweroff
Icon=system-shutdown
Terminal=false
Categories=System;
SHUTEOF
chmod +x /home/kodi/Desktop/Shutdown.desktop
chown kodi:kodi /home/kodi/Desktop/Shutdown.desktop
sudo -u kodi gio set /home/kodi/Desktop/Shutdown.desktop metadata::trusted true 2>/dev/null || true

# Reboot shortcut
cat > /home/kodi/Desktop/Reboot.desktop <<'REBOOTEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Reboot
Comment=Reboot the system
Exec=systemctl reboot
Icon=system-reboot
Terminal=false
Categories=System;
REBOOTEOF
chmod +x /home/kodi/Desktop/Reboot.desktop
chown kodi:kodi /home/kodi/Desktop/Reboot.desktop
sudo -u kodi gio set /home/kodi/Desktop/Reboot.desktop metadata::trusted true 2>/dev/null || true

msg_ok "Created desktop shortcuts (Volume, Shutdown, Reboot)"

# Check if user wants to configure audio now (from environment variable or prompt)
if [ -z "$CONFIGURE_AUDIO" ]; then
    # Fallback prompt if variable not set (standalone script execution)
    echo -e "\n${GN}=== Audio Device Configuration ===${CL}"
    echo -e "${YW}Would you like to configure audio device now?${CL}"
    echo -e "You can skip this and configure it later from the desktop shortcut."
    echo ""
    read -p "Configure audio now? (y/n): " -n 1 -r CONFIGURE_AUDIO_NOW
    echo ""
    CONFIGURE_AUDIO_NOW=$(echo "$CONFIGURE_AUDIO_NOW" | tr '[:upper:]' '[:lower:]')
else
    # Use the environment variable from kodi-v1.sh
    CONFIGURE_AUDIO_NOW="$CONFIGURE_AUDIO"
fi

if [[ $CONFIGURE_AUDIO_NOW =~ ^y ]]; then
    # Detect audio devices
    echo -e "\n${GN}=== Audio Device Detection ===${CL}"
    echo -e "Detecting available audio playback devices...\n"

# Get list of playback devices
mapfile -t DEVICES < <(aplay -l 2>/dev/null | grep -E "^card [0-9]+" | sed 's/card \([0-9]\+\):.*device \([0-9]\+\):.*/\1,\2/')
mapfile -t DEVICE_NAMES < <(aplay -l 2>/dev/null | grep -E "^card [0-9]+" | sed 's/card [0-9]\+: \(.*\), device [0-9]\+: \(.*\)/\1 - \2/')

if [ ${#DEVICES[@]} -eq 0 ]; then
    msg_error "No audio devices detected!"
    echo -e "${YW}Skipping audio configuration. You can configure it manually later.${CL}"
    SKIP_AUDIO=true
else
    SKIP_AUDIO=false
    
    echo -e "${GN}Found ${#DEVICES[@]} audio device(s):${CL}\n"
    for i in "${!DEVICES[@]}"; do
        IFS=',' read -r CARD DEV <<< "${DEVICES[$i]}"
        echo -e "  ${GN}$((i+1)).${CL} hw:${CARD},${DEV} - ${DEVICE_NAMES[$i]}"
    done
    
    # If only one device, use it automatically
    if [ ${#DEVICES[@]} -eq 1 ]; then
        SELECTED_INDEX=0
        IFS=',' read -r SELECTED_CARD SELECTED_DEV <<< "${DEVICES[0]}"
        echo -e "\n${GN}Only one device found, automatically selecting:${CL}"
        echo -e "  hw:${SELECTED_CARD},${SELECTED_DEV} - ${DEVICE_NAMES[0]}"
    else
        # Let user choose
        while true; do
            echo -e "\n${YW}Select audio device for output (enter number):${CL}"
            read -p "Choice [1-${#DEVICES[@]}]: " CHOICE
            
            if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#DEVICES[@]} ]; then
                SELECTED_INDEX=$((CHOICE-1))
                IFS=',' read -r SELECTED_CARD SELECTED_DEV <<< "${DEVICES[$SELECTED_INDEX]}"
                break
            else
                echo -e "${RD}Invalid choice. Please enter a number between 1 and ${#DEVICES[@]}.${CL}"
            fi
        done
        
        echo -e "\n${GN}Selected:${CL} hw:${SELECTED_CARD},${SELECTED_DEV} - ${DEVICE_NAMES[$SELECTED_INDEX]}"
    fi
    
    # Test audio
    echo -e "\n${YW}Testing audio device...${CL}"
    if [ -f /usr/share/sounds/alsa/Front_Center.wav ]; then
        echo -e "Playing test sound. You should hear audio now..."
        aplay -D plughw:${SELECTED_CARD},${SELECTED_DEV} /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null
        
        echo -e "\n${YW}Did you hear the test sound?${CL}"
        read -p "Audio working? (y/n): " -n 1 -r AUDIO_WORKS
        echo
        
        if [[ ! $AUDIO_WORKS =~ ^[Yy]$ ]]; then
            echo -e "\n${YW}Audio test failed. Would you like to try a different device?${CL}"
            read -p "Try another device? (y/n): " -n 1 -r TRY_AGAIN
            echo
            
            if [[ $TRY_AGAIN =~ ^[Yy]$ ]]; then
                # Allow retry with different device
                while true; do
                    echo -e "\n${GN}Available devices:${CL}\n"
                    for i in "${!DEVICES[@]}"; do
                        IFS=',' read -r CARD DEV <<< "${DEVICES[$i]}"
                        echo -e "  ${GN}$((i+1)).${CL} hw:${CARD},${DEV} - ${DEVICE_NAMES[$i]}"
                    done
                    
                    echo -e "\n${YW}Select audio device (enter number, or 0 to skip):${CL}"
                    read -p "Choice [0-${#DEVICES[@]}]: " CHOICE
                    
                    if [ "$CHOICE" = "0" ]; then
                        echo -e "${YW}Skipping audio configuration.${CL}"
                        SKIP_AUDIO=true
                        break
                    fi
                    
                    if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#DEVICES[@]} ]; then
                        SELECTED_INDEX=$((CHOICE-1))
                        IFS=',' read -r SELECTED_CARD SELECTED_DEV <<< "${DEVICES[$SELECTED_INDEX]}"
                        
                        echo -e "\n${GN}Selected:${CL} hw:${SELECTED_CARD},${SELECTED_DEV} - ${DEVICE_NAMES[$SELECTED_INDEX]}"
                        echo -e "Playing test sound..."
                        aplay -D plughw:${SELECTED_CARD},${SELECTED_DEV} /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null
                        
                        echo -e "\n${YW}Did you hear the test sound?${CL}"
                        read -p "Audio working? (y/n): " -n 1 -r AUDIO_WORKS
                        echo
                        
                        if [[ $AUDIO_WORKS =~ ^[Yy]$ ]]; then
                            break
                        fi
                    else
                        echo -e "${RD}Invalid choice.${CL}"
                    fi
                done
            else
                echo -e "${YW}Continuing with selected device anyway.${CL}"
            fi
        fi
    else
        echo -e "${YW}Test sound file not found, skipping audio test.${CL}"
    fi
fi

# Configure PulseAudio for kodi user
if [ "$SKIP_AUDIO" = false ]; then
    msg_info "Configuring PulseAudio for selected device"
    mkdir -p /home/kodi/.config/pulse
    cat > /home/kodi/.config/pulse/default.pa <<PAEOF
#!/usr/bin/pulseaudio -nF

# Include the default PulseAudio config
.include /etc/pulse/default.pa

# Explicitly load ALSA sink with selected device
load-module module-alsa-sink device=hw:${SELECTED_CARD},${SELECTED_DEV} sink_name=selected_output
set-default-sink selected_output

# Don't auto-suspend when idle
unload-module module-suspend-on-idle
PAEOF
    
    # Also configure ALSA default
    cat > /etc/asound.conf <<ALSAEOF
defaults.pcm.card ${SELECTED_CARD}
defaults.pcm.device ${SELECTED_DEV}
defaults.ctl.card ${SELECTED_CARD}
ALSAEOF
    
    msg_ok "Configured PulseAudio for hw:${SELECTED_CARD},${SELECTED_DEV}"
else
    msg_info "Configuring PulseAudio with auto-detection"
    mkdir -p /home/kodi/.config/pulse
    cat > /home/kodi/.config/pulse/default.pa <<'PAEOF'
#!/usr/bin/pulseaudio -nF

# Include the default PulseAudio config
.include /etc/pulse/default.pa

# Don't auto-suspend when idle
unload-module module-suspend-on-idle
PAEOF
    msg_ok "Configured PulseAudio with auto-detection"
fi

else
    # User chose to skip audio configuration
    echo -e "${YW}Skipping audio configuration. You can configure it later using the desktop shortcut.${CL}"
    SKIP_AUDIO=true
    
    # Create basic PulseAudio config
    msg_info "Setting up basic PulseAudio configuration"
    mkdir -p /home/kodi/.config/pulse
    cat > /home/kodi/.config/pulse/default.pa <<'PAEOF'
#!/usr/bin/pulseaudio -nF

# Include the default PulseAudio config
.include /etc/pulse/default.pa

# Don't auto-suspend when idle
unload-module module-suspend-on-idle
PAEOF
    msg_ok "Basic PulseAudio configured"
fi

# Create audio configuration script for desktop shortcut
msg_info "Creating audio configuration desktop shortcut"

# Install zenity for GUI dialogs
apt-get install -y zenity &>/dev/null

# Create Desktop folder if it doesn't exist
mkdir -p /home/kodi/Desktop

cat > /usr/local/bin/configure-audio.sh <<'AUDIOCONF'
#!/bin/bash

YW="\033[33m"
GN="\033[1;92m"
RD="\033[01;31m"
CL="\033[m"

zenity --info --title="Audio Configuration" --text="This will help you configure your audio device.\n\nClick OK to continue." --width=400

# Detect audio devices
mapfile -t DEVICES < <(aplay -l 2>/dev/null | grep -E "^card [0-9]+" | sed 's/card \([0-9]\+\):.*device \([0-9]\+\):.*/\1,\2/')
mapfile -t DEVICE_NAMES < <(aplay -l 2>/dev/null | grep -E "^card [0-9]+" | sed 's/card [0-9]\+: \(.*\), device [0-9]\+: \(.*\)/\1 - \2/')

if [ ${#DEVICES[@]} -eq 0 ]; then
    zenity --error --title="No Devices Found" --text="No audio devices detected!" --width=300
    exit 1
fi

# Build device list for zenity - using arrays to properly handle spaces
DEVICE_LIST=()
for i in "${!DEVICES[@]}"; do
    IFS=',' read -r CARD DEV <<< "${DEVICES[$i]}"
    DEVICE_LIST+=("FALSE")
    DEVICE_LIST+=("hw:${CARD},${DEV}")
    DEVICE_LIST+=("${DEVICE_NAMES[$i]}")
done

# Select device
SELECTED=$(zenity --list --radiolist --title="Select Audio Device" \
    --text="Choose your audio output device:" \
    --column="Select" --column="Device" --column="Name" \
    "${DEVICE_LIST[@]}" --width=600 --height=400)

if [ -z "$SELECTED" ]; then
    zenity --info --title="Cancelled" --text="Audio configuration cancelled." --width=300
    exit 0
fi

# Extract card and device numbers
SELECTED_CARD=$(echo "$SELECTED" | sed 's/hw:\([0-9]\+\),.*/\1/')
SELECTED_DEV=$(echo "$SELECTED" | sed 's/hw:[0-9]\+,\([0-9]\+\)/\1/')

# Test audio
zenity --info --title="Testing Audio" --text="Playing test sound on $SELECTED\n\nClick OK to play." --width=400
aplay -D plughw:${SELECTED_CARD},${SELECTED_DEV} /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null

if zenity --question --title="Audio Test" --text="Did you hear the test sound?" --width=300; then
    # Configure PulseAudio
    mkdir -p ~/.config/pulse
    cat > ~/.config/pulse/default.pa <<EOF
#!/usr/bin/pulseaudio -nF

# Include the default PulseAudio config
.include /etc/pulse/default.pa

# Explicitly load ALSA sink with selected device
load-module module-alsa-sink device=hw:${SELECTED_CARD},${SELECTED_DEV} sink_name=selected_output
set-default-sink selected_output

# Don't auto-suspend when idle
unload-module module-suspend-on-idle
EOF
    
    # Configure ALSA default
    sudo bash -c "cat > /etc/asound.conf <<EOF
defaults.pcm.card ${SELECTED_CARD}
defaults.pcm.device ${SELECTED_DEV}
defaults.ctl.card ${SELECTED_CARD}
EOF"
    
    # Restart PulseAudio
    pulseaudio -k 2>/dev/null
    sleep 1
    
    zenity --info --title="Success" --text="Audio configured successfully for $SELECTED\n\nYou may need to restart applications for changes to take effect." --width=400
else
    if zenity --question --title="Try Again?" --text="Audio test failed. Try another device?" --width=300; then
        exec "$0"
    fi
fi
AUDIOCONF
chmod +x /usr/local/bin/configure-audio.sh

# Create desktop shortcut
cat > /home/kodi/Desktop/Configure-Audio.desktop <<'DESKCONF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Configure Audio
Comment=Configure audio output device
Exec=/usr/local/bin/configure-audio.sh
Icon=audio-card
Terminal=false
Categories=Settings;HardwareSettings;
DESKCONF
chmod +x /home/kodi/Desktop/Configure-Audio.desktop
chown kodi:kodi /home/kodi/Desktop/Configure-Audio.desktop

# Mark as trusted in XFCE (allow launching)
sudo -u kodi gio set /home/kodi/Desktop/Configure-Audio.desktop metadata::trusted true 2>/dev/null || true

msg_ok "Created audio configuration shortcut"

# Set up XFCE session environment
cat > /home/kodi/.xprofile <<'XPEOF'
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/1000
XPEOF

chown -R kodi:kodi /home/kodi/.config /home/kodi/.xprofile /home/kodi/Desktop

# Enable PulseAudio socket activation for kodi user
sudo -u kodi XDG_RUNTIME_DIR=/run/user/1000 systemctl --user enable pulseaudio.socket pulseaudio.service &>/dev/null

msg_ok "Set up PulseAudio"

# Install selected applications
echo -e "\n${GN}=== Installing Selected Applications ===${CL}\n"

if [[ $INSTALL_FIREFOX =~ ^[Yy]$ ]]; then
    msg_info "Installing Firefox"
    apt-get install -y firefox &>/dev/null
    if command -v firefox &> /dev/null; then
        msg_ok "Installed Firefox"
    else
        msg_error "Firefox installation failed"
    fi
fi

if [[ $INSTALL_BRAVE =~ ^[Yy]$ ]]; then
    msg_info "Installing Brave Browser"
    apt-get install -y curl &>/dev/null
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg &>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list &>/dev/null
    apt-get update &>/dev/null
    apt-get install -y brave-browser &>/dev/null
    if command -v brave-browser &> /dev/null; then
        msg_ok "Installed Brave Browser"
    else
        msg_error "Brave Browser installation failed"
    fi
fi

if [[ $INSTALL_CHROME =~ ^[Yy]$ ]]; then
    msg_info "Installing Google Chrome"
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb &>/dev/null
    apt-get install -y /tmp/chrome.deb &>/dev/null
    rm /tmp/chrome.deb
    if command -v google-chrome &> /dev/null; then
        msg_ok "Installed Google Chrome"
    else
        msg_error "Google Chrome installation failed"
    fi
fi

if [[ $INSTALL_LIBREOFFICE =~ ^[Yy]$ ]]; then
    msg_info "Installing LibreOffice"
    apt-get install -y libreoffice &>/dev/null
    if command -v libreoffice &> /dev/null; then
        msg_ok "Installed LibreOffice"
    else
        msg_error "LibreOffice installation failed"
    fi
fi

if [[ $INSTALL_VLC =~ ^[Yy]$ ]]; then
    msg_info "Installing VLC Media Player"
    apt-get install -y vlc &>/dev/null
    if command -v vlc &> /dev/null; then
        msg_ok "Installed VLC Media Player"
    else
        msg_error "VLC Media Player installation failed"
    fi
fi

if [[ $INSTALL_GIMP =~ ^[Yy]$ ]]; then
    msg_info "Installing GIMP"
    apt-get install -y gimp &>/dev/null
    if command -v gimp &> /dev/null; then
        msg_ok "Installed GIMP"
    else
        msg_error "GIMP installation failed"
    fi
fi

if [[ $INSTALL_STEAM =~ ^[Yy]$ ]]; then
    msg_info "Installing Steam"
    dpkg --add-architecture i386 &>/dev/null
    apt-get update &>/dev/null
    apt-get install -y steam &>/dev/null
    apt-get install -y -f &>/dev/null
    if command -v steam &> /dev/null || [ -f /usr/games/steam ]; then
        msg_ok "Installed Steam"
    else
        msg_error "Steam installation failed"
    fi
    
    # Set up Steam auto-start if enabled (default to yes)
    if [ "${STEAM_AUTOSTART:-yes}" = "yes" ]; then
        msg_info "Setting up Steam auto-start"
        cat <<EOF >/home/kodi/.config/autostart/steam.desktop
[Desktop Entry]
Type=Application
Name=Steam
Exec=/usr/games/steam -silent %U
X-XFCE-Autostart-enabled=true
EOF
        chown kodi:kodi /home/kodi/.config/autostart/steam.desktop
        msg_ok "Set up Steam auto-start"
    else
        msg_info "Steam installed but autostart disabled (launch manually from menu)"
    fi
fi


# Create desktop launchers for skipped applications
mkdir -p /home/kodi/Desktop

# Kodi installers (PPA and Flatpak) if Kodi wasn't installed
# Always create Kodi installer scripts (allows version switching)
# Kodi PPA installer
cat <<'KODIPPAEOF' >/usr/local/bin/install-kodi-ppa.sh
#!/usr/bin/env bash
echo "Installing/Switching to Kodi PPA (v20.x)..."
echo ""

# Check and remove Flatpak version if installed
if flatpak list 2>/dev/null | grep -q "tv.kodi.Kodi"; then
    echo "Removing existing Kodi Flatpak installation..."
    flatpak uninstall -y tv.kodi.Kodi &>/dev/null
    echo "Flatpak version removed."
    echo ""
fi

# Check if PPA version already installed
if command -v kodi &> /dev/null && dpkg -l | grep -q "^ii  kodi "; then
    echo "Kodi PPA is already installed."
    read -p "Reinstall anyway? (y/n): " -n 1 -r REINSTALL
    echo ""
    if [[ ! $REINSTALL =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        read -p "Press Enter to exit..."
        exit 0
    fi
fi

echo "Installing Kodi PPA..."
apt-get install -y software-properties-common &>/dev/null
add-apt-repository -y ppa:team-xbmc/ppa &>/dev/null
apt-get update &>/dev/null
apt-get install -y kodi &>/dev/null

if command -v kodi &> /dev/null; then
    echo ""
    echo "Kodi PPA installation complete!"
    echo "You can launch Kodi from the applications menu."
    echo ""
    
    # Prompt for autostart
    read -p "Do you want Kodi to auto-start on boot? (y/n): " -n 1 -r AUTOSTART
    echo ""
    
    if [[ $AUTOSTART =~ ^[Yy]$ ]]; then
        mkdir -p /home/kodi/.config/autostart
        cat <<AUTOEOF >/home/kodi/.config/autostart/kodi.desktop
[Desktop Entry]
Type=Application
Name=Kodi
Exec=kodi
X-XFCE-Autostart-enabled=true
AUTOEOF
        chown -R kodi:kodi /home/kodi/.config/autostart
        echo "Kodi will now auto-start on boot."
    else
        # Remove autostart if it exists
        rm -f /home/kodi/.config/autostart/kodi.desktop
        echo "Kodi will NOT auto-start (launch manually from menu)."
    fi
else
    echo "Kodi installation failed!"
fi
echo ""
read -p "Press Enter to exit..."
KODIPPAEOF
chmod +x /usr/local/bin/install-kodi-ppa.sh

cat <<EOF >/home/kodi/Desktop/install-kodi-ppa.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Switch to Kodi PPA
Comment=Install/Switch to Kodi v20.x from PPA
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-kodi-ppa.sh"
Terminal=false
Icon=kodi
Categories=System;
EOF
chmod +x /home/kodi/Desktop/install-kodi-ppa.desktop
chown kodi:kodi /home/kodi/Desktop/install-kodi-ppa.desktop

# Kodi Flatpak installer
cat <<'KODIFLATPAKEOF' >/usr/local/bin/install-kodi-flatpak.sh
#!/usr/bin/env bash
echo "Installing/Switching to Kodi Flatpak (v21.x)..."
echo ""

# Check and remove PPA version if installed
if command -v kodi &> /dev/null && dpkg -l | grep -q "^ii  kodi "; then
    echo "Removing existing Kodi PPA installation..."
    apt-get remove -y kodi kodi-bin kodi-data &>/dev/null
    apt-get autoremove -y &>/dev/null
    echo "PPA version removed."
    echo ""
fi

# Check if Flatpak version already installed
if flatpak list 2>/dev/null | grep -q "tv.kodi.Kodi"; then
    echo "Kodi Flatpak is already installed."
    read -p "Reinstall anyway? (y/n): " -n 1 -r REINSTALL
    echo ""
    if [[ ! $REINSTALL =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        read -p "Press Enter to exit..."
        exit 0
    fi
fi

echo "Installing Kodi Flatpak..."
apt-get install -y flatpak &>/dev/null
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &>/dev/null
flatpak install -y flathub tv.kodi.Kodi &>/dev/null

if flatpak list | grep -q "tv.kodi.Kodi"; then
    echo ""
    echo "Kodi Flatpak installation complete!"
    echo "You can launch Kodi from the applications menu."
    echo ""
    
    # Prompt for autostart
    read -p "Do you want Kodi to auto-start on boot? (y/n): " -n 1 -r AUTOSTART
    echo ""
    
    if [[ $AUTOSTART =~ ^[Yy]$ ]]; then
        mkdir -p /home/kodi/.config/autostart
        cat <<AUTOEOF >/home/kodi/.config/autostart/kodi.desktop
[Desktop Entry]
Type=Application
Name=Kodi
Exec=flatpak run tv.kodi.Kodi
X-XFCE-Autostart-enabled=true
AUTOEOF
        chown -R kodi:kodi /home/kodi/.config/autostart
        echo "Kodi will now auto-start on boot."
    else
        # Remove autostart if it exists
        rm -f /home/kodi/.config/autostart/kodi.desktop
        echo "Kodi will NOT auto-start (launch manually from menu)."
    fi
else
    echo "Kodi Flatpak installation failed!"
fi
echo ""
read -p "Press Enter to exit..."
KODIFLATPAKEOF
chmod +x /usr/local/bin/install-kodi-flatpak.sh

cat <<EOF >/home/kodi/Desktop/install-kodi-flatpak.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Switch to Kodi Flatpak
Comment=Install/Switch to Kodi v21.x via Flatpak
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-kodi-flatpak.sh"
Terminal=false
Icon=kodi
Categories=System;
EOF
chmod +x /home/kodi/Desktop/install-kodi-flatpak.desktop
chown kodi:kodi /home/kodi/Desktop/install-kodi-flatpak.desktop


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

# Prompt for autostart
read -p "Do you want Steam to auto-start on boot? (y/n): " -n 1 -r AUTOSTART
echo ""

if [[ $AUTOSTART =~ ^[Yy]$ ]]; then
    mkdir -p /home/kodi/.config/autostart
    cat <<STEAMSTARTEOF >/home/kodi/.config/autostart/steam.desktop
[Desktop Entry]
Type=Application
Name=Steam
Exec=/usr/games/steam -silent %U
X-XFCE-Autostart-enabled=true
STEAMSTARTEOF
    chown kodi:kodi /home/kodi/.config/autostart/steam.desktop
    echo "Steam will now auto-start on boot."
else
    echo "Steam will NOT auto-start (launch manually from menu)."
fi

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
echo -e "  1. Boot into XFCE desktop"

# Conditional Kodi autostart message
if [ -n "$KODI_EXEC" ]; then
    if [ "${KODI_AUTOSTART:-yes}" = "yes" ]; then
        echo -e "  2. Automatically launch Kodi on boot"
        echo -e "  3. XFCE panel will restart after Kodi exits (fixes volume control)"
        echo -e "  4. ${YW}Note: Use desktop Shutdown/Reboot shortcuts (XFCE menu button may not work)${CL}"
    else
        echo -e "  2. Kodi installed (launch manually from menu)"
    fi
else
    echo -e "  2. No Kodi installed (pure XFCE desktop)"
fi

echo -e "  5. Kodi user has full sudo access"
echo -e "  6. Desktop shortcuts: Volume Control, Shutdown, Reboot, Configure Audio"

if [ "$SKIP_AUDIO" = false ]; then
    echo -e "\n${GN}Audio Configuration:${CL}"
    echo -e "  Device: hw:${SELECTED_CARD},${SELECTED_DEV} - ${DEVICE_NAMES[$SELECTED_INDEX]}"
    echo -e "  PulseAudio configured with this device as default"
    echo -e "  Use 'Volume Control' desktop shortcut (alsamixer) to adjust volume"
else
    echo -e "\n${YW}Audio Configuration:${CL}"
    echo -e "  Audio not configured during installation"
    echo -e "  Use 'Configure Audio' desktop shortcut to set up audio"
    echo -e "  Use 'Volume Control' desktop shortcut (alsamixer) to adjust volume"
fi


# Update the completion message to include app installer count
# Find and replace the completion section

# Count skipped apps
SKIPPED=0
((SKIPPED+=2))  # Always count both Kodi installers (always available)
[[ ! $INSTALL_FIREFOX =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_BRAVE =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_CHROME =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_LIBREOFFICE =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_VLC =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_GIMP =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_STEAM =~ ^[Yy]$ ]] && ((SKIPPED++))

if [ $SKIPPED -gt 0 ]; then
    echo -e "  7. ${SKIPPED} app installer(s) available on desktop for later installation"
fi
echo -e "\n${GN}All done! Enjoy your XFCE desktop.${CL}"
