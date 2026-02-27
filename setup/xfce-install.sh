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
INSTALL_MAME="${INSTALL_MAME:-n}"
INSTALL_RETROARCH="${INSTALL_RETROARCH:-n}"

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

FAILED_APPS=()   # tracks any app that fails to install

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
    # Use quoted token match so standalone MAME token is unambiguous
    [[ "$INSTALL_APPS" == *'"MAME"'* ]] && INSTALL_MAME="y" || INSTALL_MAME="n"
    [[ "$INSTALL_APPS" == *"RETROARCH"* ]] && INSTALL_RETROARCH="y" || INSTALL_RETROARCH="n"
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

    # MAME + AML Launcher
    read -p "Install MAME + AML Launcher (play ROMs in Kodi)? (y/n): " -n 1 -r INSTALL_MAME
    echo

    # RetroArch
    read -p "Install RetroArch (Multi-system Emulator)? (y/n): " -n 1 -r INSTALL_RETROARCH
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

    cat > /usr/local/bin/kodi-exit-monitor.sh <<'KODIMONSCRIPT'
#!/bin/bash
# Monitor for Kodi process and restart panel when it exits

while true; do
    # Wait for Kodi to be running (check both native and flatpak)
    while ! pgrep -x "kodi.bin" > /dev/null 2>&1 && ! pgrep -f "tv.kodi.Kodi" > /dev/null 2>&1; do
        sleep 2
    done

    # Kodi is running, wait for it to exit
    while pgrep -x "kodi.bin" > /dev/null 2>&1 || pgrep -f "tv.kodi.Kodi" > /dev/null 2>&1; do
        sleep 2
    done

    # Kodi just exited, restart the panel with correct environment
    sleep 1
    su - kodi -c "DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 killall xfce4-panel; DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 xfce4-panel &"

    # Wait a bit before monitoring again
    sleep 5
done
KODIMONSCRIPT
    chmod +x /usr/local/bin/kodi-exit-monitor.sh

    # Create systemd service for the monitor
    cat > /etc/systemd/system/kodi-exit-monitor.service <<'KODIMONSERVICE'
[Unit]
Description=Monitor Kodi exit and restart XFCE panel
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/kodi-exit-monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
KODIMONSERVICE

    systemctl daemon-reload
    systemctl enable kodi-exit-monitor.service

    msg_ok "Set up Kodi exit monitor service"
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
        msg_error "Firefox installation failed"; FAILED_APPS+=("Firefox")
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
        msg_error "Brave Browser installation failed"; FAILED_APPS+=("Brave Browser")
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
        msg_error "Google Chrome installation failed"; FAILED_APPS+=("Google Chrome")
    fi
fi

if [[ $INSTALL_LIBREOFFICE =~ ^[Yy]$ ]]; then
    msg_info "Installing LibreOffice"
    apt-get install -y libreoffice &>/dev/null
    if command -v libreoffice &> /dev/null; then
        msg_ok "Installed LibreOffice"
    else
        msg_error "LibreOffice installation failed"; FAILED_APPS+=("LibreOffice")
    fi
fi

if [[ $INSTALL_VLC =~ ^[Yy]$ ]]; then
    msg_info "Installing VLC Media Player"
    apt-get install -y vlc &>/dev/null
    if command -v vlc &> /dev/null; then
        msg_ok "Installed VLC Media Player"
    else
        msg_error "VLC Media Player installation failed"; FAILED_APPS+=("VLC")
    fi
fi

if [[ $INSTALL_GIMP =~ ^[Yy]$ ]]; then
    msg_info "Installing GIMP"
    apt-get install -y gimp &>/dev/null
    if command -v gimp &> /dev/null; then
        msg_ok "Installed GIMP"
    else
        msg_error "GIMP installation failed"; FAILED_APPS+=("GIMP")
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
        msg_error "Steam installation failed"; FAILED_APPS+=("Steam")
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

# ── MAME + AML Launcher ───────────────────────────────────────────────────────
# Installs:  1) mame (standalone binary from Ubuntu universe)
#            2) plugin.program.AML (Advanced MAME Launcher Kodi addon)
#            3) Pre-configured settings.xml and mame.ini pointing to ~/ROMs/mame
# The user only needs to run "Setup plugin → All in one step" inside AML once to
# build the game database (this runs the mame binary so it must be done in Kodi).
if [[ $INSTALL_MAME =~ ^[Yy]$ ]]; then
    msg_info "Installing MAME"
    # mame is in the universe repo on Ubuntu 22.04. software-properties-common
    # provides add-apt-repository. mame-doc is only Suggests (not Depends) so
    # no broken-package issues on Jammy.
    apt-get install -y software-properties-common unzip wget &>/dev/null
    add-apt-repository -y universe &>/dev/null
    apt-get update &>/dev/null
    apt-get install -y mame &>/dev/null

    # Ubuntu installs the mame binary to /usr/games/mame, which is NOT in root's
    # PATH inside an LXC. Use dpkg to verify the package actually installed, and
    # resolve the binary path explicitly rather than relying on command -v.
    MAME_OK=false
    MAME_BIN=""
    if dpkg -l mame 2>/dev/null | grep -q '^ii'; then
        # Find the real binary location - could be /usr/games/mame or /usr/bin/mame
        MAME_BIN=$(dpkg -L mame 2>/dev/null | grep -E '^\/usr\/.*/mame$' | head -1)
        if [ -x "${MAME_BIN}" ]; then
            msg_ok "Installed MAME (${MAME_BIN})"
            MAME_OK=true
        else
            msg_error "MAME installation failed (binary not found after install)"; FAILED_APPS+=("MAME")
        fi
    else
        msg_error "MAME installation failed (package not installed)"; FAILED_APPS+=("MAME")
    fi

    # ── Advanced MAME Launcher (AML) Kodi addon ───────────────────────────────
    # Only install AML if MAME itself succeeded. AML is a pure-Python addon
    # available in the official Kodi Nexus repo. We download the zip, extract
    # it to ~/.kodi/addons/, and pre-write settings.xml so AML already knows
    # the MAME executable and ROM path on first launch.
    if [ "$MAME_OK" = true ]; then
    AML_ID="plugin.program.AML"
    AML_VERSION="1.0.2"
    AML_ZIP="${AML_ID}-${AML_VERSION}.zip"
    AML_URL="https://mirrors.kodi.tv/addons/nexus/${AML_ID}/${AML_ZIP}"
    AML_DATA_DIR="/home/kodi/.kodi/userdata/addon_data/${AML_ID}"
    ROM_DIR="/home/kodi/ROMs/mame"
    # MAME_BIN was already resolved via dpkg -L above

    msg_info "Installing Advanced MAME Launcher (AML) Kodi addon"
    mkdir -p "$AML_DIR" "$AML_DATA_DIR" "$ROM_DIR"

    AML_TMP="/tmp/${AML_ZIP}"
    wget -qO "$AML_TMP" "$AML_URL" 2>/dev/null
    if unzip -qo "$AML_TMP" -d "/home/kodi/.kodi/addons/" 2>/dev/null; then
        rm -f "$AML_TMP"
        # Pre-configure AML with the MAME executable path and ROM directory
        cat > "${AML_DATA_DIR}/settings.xml" << AMLSETTINGS
<settings version="2">
    <setting id="mame_prog">${MAME_BIN}</setting>
    <setting id="rom_path">${ROM_DIR}</setting>
    <setting id="assets_path"></setting>
    <setting id="chd_path"></setting>
    <setting id="dats_path"></setting>
    <setting id="samples_path"></setting>
    <setting id="SL_rom_path"></setting>
    <setting id="SL_chd_path"></setting>
</settings>
AMLSETTINGS
        # Configure standalone MAME to also use the same ROM path
        mkdir -p /home/kodi/.mame
        cat > /home/kodi/.mame/mame.ini << MAMEINI
# MAME configuration - managed by kodi-lxc setup
rompath             ${ROM_DIR}
MAMEINI
        chown -R kodi:kodi /home/kodi/.kodi /home/kodi/.mame /home/kodi/ROMs
        msg_ok "Installed AML Kodi addon (pre-configured: ${MAME_BIN} → ${ROM_DIR})"
        echo -e "   ${GN}→ In Kodi: Add-ons → Programs → Advanced MAME Launcher${CL}"
        echo -e "   ${GN}→ Open AML → press C → Setup plugin → All in one step${CL}"
        echo -e "   ${GN}→ Put ROMs in: ${ROM_DIR}${CL}"
    else
        rm -f "$AML_TMP"
        msg_error "AML Kodi addon installation failed (download/unzip error)"; FAILED_APPS+=("AML Kodi addon")
    fi
    fi # end: MAME installed OK
fi

# ── RetroArch ─────────────────────────────────────────────────────────────────
if [[ $INSTALL_RETROARCH =~ ^[Yy]$ ]]; then
    msg_info "Installing RetroArch"
    # Use the official stable PPA for a more up-to-date version than the Ubuntu repos
    apt-get install -y software-properties-common &>/dev/null
    add-apt-repository -y ppa:libretro/stable &>/dev/null
    apt-get update &>/dev/null
    apt-get install -y retroarch &>/dev/null
    if command -v retroarch &> /dev/null; then
        msg_ok "Installed RetroArch"
        # Create a ROM directory if not already created by MAME install
        mkdir -p /home/kodi/ROMs
        chown -R kodi:kodi /home/kodi/ROMs
        # Desktop shortcut
        cat > /home/kodi/Desktop/RetroArch.desktop <<'RAEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=RetroArch
Comment=Multi-system Emulator Frontend
Exec=retroarch
Icon=retroarch
Terminal=false
Categories=Game;Emulator;
RAEOF
        chmod +x /home/kodi/Desktop/RetroArch.desktop
        chown kodi:kodi /home/kodi/Desktop/RetroArch.desktop
        sudo -u kodi gio set /home/kodi/Desktop/RetroArch.desktop metadata::trusted true 2>/dev/null || true
    else
        msg_error "RetroArch installation failed"; FAILED_APPS+=("RetroArch")
    fi
fi


# ── Desktop installers for skipped apps ───────────────────────────────────────

# Kodi installers (always created to allow version switching)
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

cat <<'KODIFLATPAKEOF' >/usr/local/bin/install-kodi-flatpak.sh
#!/usr/bin/env bash
echo "Installing/Switching to Kodi Flatpak (v21.x)..."
echo ""

if command -v kodi &> /dev/null && dpkg -l | grep -q "^ii  kodi "; then
    echo "Removing existing Kodi PPA installation..."
    apt-get remove -y kodi kodi-bin kodi-data &>/dev/null
    apt-get autoremove -y &>/dev/null
    echo "PPA version removed."
    echo ""
fi

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
    echo ""

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

# ── MAME + AML desktop installer (if skipped) ────────────────────────────────
if [[ ! $INSTALL_MAME =~ ^[Yy]$ ]]; then
    cat <<'MAMEINSTEOF' >/usr/local/bin/install-mame.sh
#!/usr/bin/env bash
set -e
echo "Installing MAME + Advanced MAME Launcher (AML) for Kodi..."
echo ""

# Step 1: Install MAME from Ubuntu universe
echo "Installing MAME standalone..."
apt-get install -y software-properties-common unzip wget &>/dev/null
add-apt-repository -y universe &>/dev/null
apt-get update &>/dev/null
apt-get install -y mame &>/dev/null
# /usr/games is not in root PATH in LXC - use dpkg to verify install and find binary
if ! dpkg -l mame 2>/dev/null | grep -q '^ii'; then
    echo "ERROR: MAME installation failed. Check your internet connection."
    read -p "Press Enter to exit..."; exit 1
fi
MAME_BIN=$(dpkg -L mame 2>/dev/null | grep -E '^\/usr\/.*/mame$' | head -1)
if [ ! -x "${MAME_BIN}" ]; then
    echo "ERROR: MAME binary not found after install (expected in /usr/games/mame)."
    read -p "Press Enter to exit..."; exit 1
fi
echo "  ✓ MAME installed (${MAME_BIN})"

# Step 2: Install AML Kodi addon from official Kodi Nexus repo
AML_ID="plugin.program.AML"
AML_VERSION="1.0.2"
AML_ZIP="${AML_ID}-${AML_VERSION}.zip"
AML_URL="https://mirrors.kodi.tv/addons/nexus/${AML_ID}/${AML_ZIP}"
AML_TMP="/tmp/${AML_ZIP}"
ADDON_BASE="/home/kodi/.kodi/addons"
AML_DATA="/home/kodi/.kodi/userdata/addon_data/${AML_ID}"
ROM_DIR="/home/kodi/ROMs/mame"

echo "Downloading AML Kodi addon..."
mkdir -p "$ADDON_BASE" "$AML_DATA" "$ROM_DIR"
wget -qO "$AML_TMP" "$AML_URL" 2>/dev/null
if ! unzip -qo "$AML_TMP" -d "$ADDON_BASE" 2>/dev/null; then
    echo "ERROR: Could not download or extract AML. Check internet connection."
    rm -f "$AML_TMP"
    read -p "Press Enter to exit..."; exit 1
fi
rm -f "$AML_TMP"
echo "  ✓ AML addon installed"

# Step 3: Pre-configure AML with MAME path and ROM directory
cat > "${AML_DATA}/settings.xml" << AMLSETTINGS
<settings version="2">
    <setting id="mame_prog">${MAME_BIN}</setting>
    <setting id="rom_path">${ROM_DIR}</setting>
    <setting id="assets_path"></setting>
    <setting id="chd_path"></setting>
    <setting id="dats_path"></setting>
    <setting id="samples_path"></setting>
    <setting id="SL_rom_path"></setting>
    <setting id="SL_chd_path"></setting>
</settings>
AMLSETTINGS

# Configure standalone MAME to use the same ROM directory
mkdir -p /home/kodi/.mame
cat > /home/kodi/.mame/mame.ini << MAMEINI
rompath             ${ROM_DIR}
MAMEINI

# Create MAME desktop shortcut and set permissions
cat > /home/kodi/Desktop/MAME.desktop << 'MAMEDESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=MAME
Comment=Multiple Arcade Machine Emulator
Exec=mame
Icon=mame
Terminal=false
Categories=Game;Emulator;
MAMEDESKTOP
chmod +x /home/kodi/Desktop/MAME.desktop
chown -R kodi:kodi /home/kodi/.kodi /home/kodi/.mame /home/kodi/ROMs /home/kodi/Desktop/MAME.desktop
echo "  ✓ Paths configured"

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Put MAME ROMs (.zip) in: ${ROM_DIR}"
echo "  2. Open Kodi → Add-ons → Programs → Advanced MAME Launcher"
echo "  3. Press C on any item → Setup plugin → All in one step"
echo "     (This builds the game database - takes 5-20 mins)"
echo ""
rm -f /home/kodi/Desktop/install-mame.desktop
rm -f "$0"
read -p "Press Enter to exit..."
MAMEINSTEOF
    chmod +x /usr/local/bin/install-mame.sh

    cat <<EOF >/home/kodi/Desktop/install-mame.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Install MAME + AML
Comment=Install MAME arcade emulator and AML Kodi launcher
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-mame.sh"
Terminal=false
Icon=kodi
Categories=System;
EOF
    chmod +x /home/kodi/Desktop/install-mame.desktop
    chown kodi:kodi /home/kodi/Desktop/install-mame.desktop
fi


# ── RetroArch desktop installer (if skipped) ──────────────────────────────────
if [[ ! $INSTALL_RETROARCH =~ ^[Yy]$ ]]; then
    cat <<'RAINSTEOF' >/usr/local/bin/install-retroarch.sh
#!/usr/bin/env bash
echo "Installing RetroArch from libretro/stable PPA..."
apt-get install -y software-properties-common &>/dev/null
add-apt-repository -y ppa:libretro/stable &>/dev/null
apt-get update &>/dev/null
apt-get install -y retroarch &>/dev/null
if command -v retroarch &> /dev/null; then
    echo "RetroArch installation complete!"
    mkdir -p /home/kodi/ROMs
    chown -R kodi:kodi /home/kodi/ROMs
    # Create desktop shortcut
    cat > /home/kodi/Desktop/RetroArch.desktop <<'RADESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=RetroArch
Comment=Multi-system Emulator Frontend
Exec=retroarch
Icon=retroarch
Terminal=false
Categories=Game;Emulator;
RADESKTOP
    chmod +x /home/kodi/Desktop/RetroArch.desktop
    chown kodi:kodi /home/kodi/Desktop/RetroArch.desktop
    echo "ROMs directory created at ~/ROMs"
    echo ""
    echo "Tip: Install cores from the RetroArch Online Updater to add more systems."
else
    echo "RetroArch installation failed!"
fi
echo "The desktop installer will now be deleted."
read -p "Press Enter to exit..."
rm -f /home/kodi/Desktop/install-retroarch.desktop
rm -f "$0"
RAINSTEOF
    chmod +x /usr/local/bin/install-retroarch.sh

    cat <<EOF >/home/kodi/Desktop/install-retroarch.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Install RetroArch
Comment=Install RetroArch multi-system emulator
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-retroarch.sh"
Terminal=false
Icon=retroarch
Categories=System;
EOF
    chmod +x /home/kodi/Desktop/install-retroarch.desktop
    chown kodi:kodi /home/kodi/Desktop/install-retroarch.desktop
fi


# Write any app failures to a file so kodi-v1.sh can report them accurately
if [ ${#FAILED_APPS[@]} -gt 0 ]; then
    printf '%s\n' "${FAILED_APPS[@]}" > /tmp/kodi-install-failures.txt
else
    rm -f /tmp/kodi-install-failures.txt
fi


systemctl restart lightdm
msg_ok "Restarted lightdm"

echo -e "\n${GN}Setup complete!${CL}"
echo -e "Your LXC will now:"
echo -e "  1. Boot into XFCE desktop"

# Conditional Kodi autostart message
if [ -n "$KODI_EXEC" ]; then
    if [ "${KODI_AUTOSTART:-yes}" = "yes" ]; then
        echo -e "  2. Automatically launch Kodi on boot"
    else
        echo -e "  2. Kodi installed (launch manually from menu)"
    fi
else
    echo -e "  2. No Kodi installed (pure XFCE desktop)"
fi

echo -e "  3. Kodi user has full sudo access"
echo -e "  4. Desktop shortcuts: Volume Control, Shutdown, Reboot, Configure Audio"
echo -e "  5. Shutdown/Reboot works from XFCE menu and desktop shortcuts"

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
[[ ! $INSTALL_MAME =~ ^[Yy]$ ]] && ((SKIPPED++))
[[ ! $INSTALL_RETROARCH =~ ^[Yy]$ ]] && ((SKIPPED++))

if [ $SKIPPED -gt 0 ]; then
    echo -e "  6. ${SKIPPED} app installer(s) available on desktop for later installation"
fi

if [ "$SKIP_AUDIO" = false ]; then
    echo -e "\n  7. ${GN}Audio Configuration:${CL}"
    echo -e "     Device: hw:${SELECTED_CARD},${SELECTED_DEV} - ${DEVICE_NAMES[$SELECTED_INDEX]}"
    echo -e "     PulseAudio configured with this device as default"
    echo -e "     Use 'Volume Control' desktop shortcut (alsamixer) to adjust volume"
else
    echo -e "\n  7. ${YW}Audio Configuration:${CL}"
    echo -e "     Audio not configured during installation"
    echo -e "     Use 'Configure Audio' desktop shortcut to set up audio"
    echo -e "     Use 'Volume Control' desktop shortcut (alsamixer) to adjust volume"
fi

echo -e "\n${GN}All done! Enjoy your XFCE desktop.${CL}"
