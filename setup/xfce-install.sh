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

# ─────────────────────────────────────────────
# Resolve install flags from INSTALL_APPS env var
# ─────────────────────────────────────────────
INSTALL_KODI_PPA="n"
INSTALL_KODI_FLATPAK="n"
INSTALL_RETROARCH="n"
INSTALL_STEAM="n"
INSTALL_FIREFOX="n"
INSTALL_BRAVE="n"
INSTALL_CHROME="n"
INSTALL_LIBREOFFICE="n"
INSTALL_VLC="n"
INSTALL_GIMP="n"

if [ -n "${INSTALL_APPS:-}" ]; then
    [[ "$INSTALL_APPS" == *"KODI_PPA"* ]]     && INSTALL_KODI_PPA="y"
    [[ "$INSTALL_APPS" == *"KODI_FLATPAK"* ]] && INSTALL_KODI_FLATPAK="y"
    [[ "$INSTALL_APPS" == *"RETROARCH"* ]]    && INSTALL_RETROARCH="y"
    [[ "$INSTALL_APPS" == *"STEAM"* ]]        && INSTALL_STEAM="y"
    [[ "$INSTALL_APPS" == *"FIREFOX"* ]]      && INSTALL_FIREFOX="y"
    [[ "$INSTALL_APPS" == *"BRAVE"* ]]        && INSTALL_BRAVE="y"
    [[ "$INSTALL_APPS" == *"CHROME"* ]]       && INSTALL_CHROME="y"
    [[ "$INSTALL_APPS" == *"LIBREOFFICE"* ]]  && INSTALL_LIBREOFFICE="y"
    [[ "$INSTALL_APPS" == *"VLC"* ]]          && INSTALL_VLC="y"
    [[ "$INSTALL_APPS" == *"GIMP"* ]]         && INSTALL_GIMP="y"
else
    # Fallback: interactive prompts if called standalone
    echo -e "\n${GN}=== Optional Software ===${CL}"
    read -p "Install Kodi? (1=PPA / 2=Flatpak / n=No): " -n 1 -r KODI_CHOICE; echo
    [[ "$KODI_CHOICE" = "1" ]] && INSTALL_KODI_PPA="y"
    [[ "$KODI_CHOICE" = "2" ]] && INSTALL_KODI_FLATPAK="y"
    read -p "Install RetroArch? (y/n): "   -n 1 -r INSTALL_RETROARCH;   echo
    read -p "Install Steam? (y/n): "       -n 1 -r INSTALL_STEAM;       echo
    read -p "Install Firefox? (y/n): "     -n 1 -r INSTALL_FIREFOX;     echo
    read -p "Install Brave? (y/n): "       -n 1 -r INSTALL_BRAVE;       echo
    read -p "Install Chrome? (y/n): "      -n 1 -r INSTALL_CHROME;      echo
    read -p "Install LibreOffice? (y/n): " -n 1 -r INSTALL_LIBREOFFICE; echo
    read -p "Install VLC? (y/n): "         -n 1 -r INSTALL_VLC;         echo
    read -p "Install GIMP? (y/n): "        -n 1 -r INSTALL_GIMP;        echo
fi

DEFAULT_SESSION="${DEFAULT_SESSION:-Desktop}"
CONFIGURE_AUDIO="${CONFIGURE_AUDIO:-no}"
KODI_PASS="${KODI_PASS:-kodi}"

# ─────────────────────────────────────────────
# Base system
# ─────────────────────────────────────────────
msg_info "Updating system"
apt-get update -qq &>/dev/null
apt-get upgrade -y -qq &>/dev/null
msg_ok "System updated"

msg_info "Installing XFCE and base X packages"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    xfce4 xfce4-goodies xfce4-terminal \
    xorg xserver-xorg-video-intel \
    xserver-xorg-input-evdev \
    zenity xterm whiptail x11-utils \
    pulseaudio pulseaudio-utils pavucontrol alsa-utils \
    software-properties-common curl wget \
    &>/dev/null
msg_ok "Installed XFCE and base X packages"

# ─────────────────────────────────────────────
# kodi user
# ─────────────────────────────────────────────
msg_info "Creating kodi user"
if ! id -u kodi &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,audio,input,video,render kodi
else
    usermod -aG sudo,audio,input,video,render kodi
fi
echo "kodi:${KODI_PASS}" | chpasswd
msg_ok "kodi user ready (password set)"

# ─────────────────────────────────────────────
# lightdm — autologin to bare kodi-session (NOT xfce)
# XFCE only loads when the user explicitly selects Desktop
# ─────────────────────────────────────────────
msg_info "Configuring lightdm"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    lightdm lightdm-gtk-greeter &>/dev/null
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/autologin-kodi.conf <<'EOF'
[Seat:*]
autologin-user=kodi
autologin-session=kodi-session
EOF
msg_ok "lightdm configured (autologin → kodi-session)"

# ─────────────────────────────────────────────
# Minimal kodi-session xsession entry
# Points directly to session-manager.sh — no desktop loaded
# ─────────────────────────────────────────────
msg_info "Creating kodi-session xsession entry"
mkdir -p /usr/share/xsessions
cat > /usr/share/xsessions/kodi-session.desktop <<'EOF'
[Desktop Entry]
Name=Kodi Session
Comment=Minimal session — session manager only, no desktop
Exec=/usr/local/bin/session-manager.sh
Type=Application
EOF
msg_ok "kodi-session xsession entry created"

# ─────────────────────────────────────────────
# Xorg input detection — uses printf (no nested heredoc)
# ─────────────────────────────────────────────
msg_info "Configuring Xorg input detection"
cat > /usr/local/bin/preX-populate-input.sh <<'EOF'
#!/usr/bin/env bash
CFG=/etc/X11/xorg.conf.d/10-lxc-input.conf
mkdir -p /etc/X11/xorg.conf.d
printf 'Section "ServerFlags"\n    Option "AutoAddDevices" "True"\nEndSection\n' > "$CFG"
cd /dev/input
for input in event*; do
    printf 'Section "InputDevice"\n    Identifier "%s"\n    Option "Device" "/dev/input/%s"\n    Option "AutoServerLayout" "true"\n    Driver "evdev"\nEndSection\n' \
        "$input" "$input" >> "$CFG"
done
EOF
chmod +x /usr/local/bin/preX-populate-input.sh
mkdir -p /etc/systemd/system/lightdm.service.d
cat > /etc/systemd/system/lightdm.service.d/override.conf <<'EOF'
[Service]
ExecStartPre=/bin/sh -c '/usr/local/bin/preX-populate-input.sh'
SupplementaryGroups=video render input audio tty
EOF
systemctl daemon-reload
msg_ok "Xorg input detection configured"

# ─────────────────────────────────────────────
# PolicyKit
# ─────────────────────────────────────────────
msg_info "Configuring PolicyKit"
mkdir -p /etc/polkit-1/localauthority/50-local.d
cat > /etc/polkit-1/localauthority/50-local.d/allow-kodi.pkla <<'EOF'
[Allow kodi user all permissions]
Identity=unix-user:kodi
Action=*
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF
msg_ok "PolicyKit configured"

# ─────────────────────────────────────────────
# PulseAudio baseline
# ─────────────────────────────────────────────
msg_info "Configuring PulseAudio"
mkdir -p /home/kodi/.config/pulse
cat > /home/kodi/.config/pulse/default.pa <<'EOF'
#!/usr/bin/pulseaudio -nF
.include /etc/pulse/default.pa
unload-module module-suspend-on-idle
EOF
chown -R kodi:kodi /home/kodi/.config/pulse
msg_ok "PulseAudio base config set"

# ─────────────────────────────────────────────
# Audio device configuration (optional at install time)
# ─────────────────────────────────────────────
SKIP_AUDIO=true
SELECTED_CARD=""
SELECTED_DEV=""
SELECTED_DEVICE_NAME=""

if [[ "${CONFIGURE_AUDIO}" =~ ^[Yy] ]]; then
    mapfile -t DEVICES      < <(aplay -l 2>/dev/null | grep -E "^card [0-9]+" | sed 's/card \([0-9]\+\):.*device \([0-9]\+\):.*/\1,\2/')
    mapfile -t DEVICE_NAMES < <(aplay -l 2>/dev/null | grep -E "^card [0-9]+" | sed 's/card [0-9]\+: \(.*\), device [0-9]\+: \(.*\)/\1 - \2/')

    if [ ${#DEVICES[@]} -eq 0 ]; then
        msg_error "No audio devices detected — configure later from session menu"
    else
        SKIP_AUDIO=false
        if [ ${#DEVICES[@]} -eq 1 ]; then
            SELECTED_INDEX=0
        else
            for i in "${!DEVICES[@]}"; do
                IFS=',' read -r C D <<< "${DEVICES[$i]}"
                echo -e "  ${GN}$((i+1)).${CL} hw:${C},${D} — ${DEVICE_NAMES[$i]}"
            done
            while true; do
                read -p "Select device [1-${#DEVICES[@]}]: " CHOICE
                if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#DEVICES[@]} ]; then
                    SELECTED_INDEX=$((CHOICE - 1)); break
                fi
            done
        fi
        IFS=',' read -r SELECTED_CARD SELECTED_DEV <<< "${DEVICES[$SELECTED_INDEX]}"
        SELECTED_DEVICE_NAME="${DEVICE_NAMES[$SELECTED_INDEX]}"

        cat > /home/kodi/.config/pulse/default.pa <<EOF
#!/usr/bin/pulseaudio -nF
.include /etc/pulse/default.pa
load-module module-alsa-sink device=hw:${SELECTED_CARD},${SELECTED_DEV} sink_name=selected_output
set-default-sink selected_output
unload-module module-suspend-on-idle
EOF
        cat > /etc/asound.conf <<EOF
defaults.pcm.card ${SELECTED_CARD}
defaults.pcm.device ${SELECTED_DEV}
defaults.ctl.card ${SELECTED_CARD}
EOF
        chown kodi:kodi /home/kodi/.config/pulse/default.pa
        msg_ok "Audio configured: hw:${SELECTED_CARD},${SELECTED_DEV} — ${SELECTED_DEVICE_NAME}"
    fi
fi

# ─────────────────────────────────────────────
# Configure Audio helper script
# ─────────────────────────────────────────────
msg_info "Installing Configure Audio tool"
cat > /usr/local/bin/configure-audio.sh <<'AUDIOEOF'
#!/usr/bin/env bash
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

zenity --info --title="Audio Configuration" \
    --text="This will help you configure your audio output device.\n\nClick OK to continue." \
    --width=400 2>/dev/null

mapfile -t DEVICES      < <(aplay -l 2>/dev/null | grep -E "^card [0-9]+" | sed 's/card \([0-9]\+\):.*device \([0-9]\+\):.*/\1,\2/')
mapfile -t DEVICE_NAMES < <(aplay -l 2>/dev/null | grep -E "^card [0-9]+" | sed 's/card [0-9]\+: \(.*\), device [0-9]\+: \(.*\)/\1 - \2/')

if [ ${#DEVICES[@]} -eq 0 ]; then
    zenity --error --title="No Devices Found" \
        --text="No audio devices detected.\n\nMake sure /dev/snd is passed through to the container." \
        --width=360 2>/dev/null
    exit 1
fi

LIST_ARGS=()
for i in "${!DEVICES[@]}"; do
    IFS=',' read -r C D <<< "${DEVICES[$i]}"
    LIST_ARGS+=("FALSE" "hw:${C},${D}" "${DEVICE_NAMES[$i]}")
done

SELECTED=$(zenity --list --radiolist \
    --title="Select Audio Device" \
    --text="Choose your audio output device:" \
    --column="Select" --column="Device" --column="Description" \
    "${LIST_ARGS[@]}" --width=600 --height=400 2>/dev/null)
[ -z "$SELECTED" ] && exit 0

SEL_CARD=$(echo "$SELECTED" | sed 's/hw:\([0-9]\+\),.*/\1/')
SEL_DEV=$(echo  "$SELECTED" | sed 's/hw:[0-9]\+,\([0-9]\+\)/\1/')

zenity --info --title="Test Audio" \
    --text="Playing test tone on $SELECTED\n\nClick OK to play." \
    --width=380 2>/dev/null
aplay -D plughw:${SEL_CARD},${SEL_DEV} /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null

if zenity --question --title="Audio OK?" \
    --text="Did you hear the test sound on $SELECTED?" --width=340 2>/dev/null; then
    mkdir -p ~/.config/pulse
    cat > ~/.config/pulse/default.pa <<EOF
#!/usr/bin/pulseaudio -nF
.include /etc/pulse/default.pa
load-module module-alsa-sink device=hw:${SEL_CARD},${SEL_DEV} sink_name=selected_output
set-default-sink selected_output
unload-module module-suspend-on-idle
EOF
    sudo bash -c "cat > /etc/asound.conf <<EOF
defaults.pcm.card ${SEL_CARD}
defaults.pcm.device ${SEL_DEV}
defaults.ctl.card ${SEL_CARD}
EOF"
    pulseaudio -k 2>/dev/null; sleep 1
    zenity --info --title="Done" \
        --text="Audio set to: $SELECTED\n\nRestart open apps to apply." \
        --width=360 2>/dev/null
else
    zenity --question --title="Try Again?" \
        --text="Test failed. Try a different device?" --width=300 2>/dev/null \
        && exec "$0"
fi
AUDIOEOF
chmod +x /usr/local/bin/configure-audio.sh
msg_ok "Configure Audio tool installed"

# ─────────────────────────────────────────────
# RETROARCH — installed from libretro's official buildbot
# The PPA build has the online core downloader compiled out.
# The buildbot binary is the full build with online updater intact.
# AppImage is extracted (no FUSE needed) to /opt/retroarch-bin.
# ─────────────────────────────────────────────
RETROARCH_INSTALLED=false
if [[ "${INSTALL_RETROARCH}" =~ ^[Yy] ]]; then
    msg_info "Installing RetroArch dependencies"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        libgl1 libgles2 libegl1 \
        libsdl2-2.0-0 libavcodec58 libavformat58 libswscale5 \
        libfreetype6 libasound2 curl fuse &>/dev/null
    msg_ok "RetroArch dependencies installed"

    msg_info "Fetching latest RetroArch nightly build"
    BUILDBOT_BASE="https://buildbot.libretro.com/nightly/linux/x86_64/latest"
    APPIMAGE=$(curl -s "${BUILDBOT_BASE}/" \
        | grep -oP 'RetroArch[^"]+\.AppImage' | head -1)

    if [ -z "$APPIMAGE" ]; then
        msg_error "Could not determine AppImage filename — falling back to Flatpak"
    else
        wget -q "${BUILDBOT_BASE}/${APPIMAGE}" -O /opt/RetroArch.AppImage 2>/dev/null
        if [ -s /opt/RetroArch.AppImage ]; then
            chmod +x /opt/RetroArch.AppImage
            msg_ok "Downloaded: $APPIMAGE"

            # /dev/fuse is passed through by kodi-v1.sh so AppImage runs directly
            cat > /usr/local/bin/retroarch <<'EOF'
#!/usr/bin/env bash
exec /opt/RetroArch.AppImage "$@"
EOF
            chmod +x /usr/local/bin/retroarch
            RETROARCH_INSTALLED=true
            msg_ok "RetroArch installed from buildbot (online updater enabled)"
        else
            msg_error "Download failed — falling back to Flatpak"
            rm -f /opt/RetroArch.AppImage
        fi
    fi

    # Flatpak fallback if buildbot download fails
    if [ "$RETROARCH_INSTALLED" = false ]; then
        apt-get install -y -qq flatpak &>/dev/null
        flatpak remote-add --if-not-exists flathub \
            https://flathub.org/repo/flathub.flatpakrepo &>/dev/null
        if flatpak install -y --noninteractive flathub org.libretro.RetroArch &>/dev/null; then
            RETROARCH_INSTALLED=true
            cat > /usr/local/bin/retroarch <<'EOF'
#!/usr/bin/env bash
exec flatpak run org.libretro.RetroArch "$@"
EOF
            chmod +x /usr/local/bin/retroarch
            msg_ok "RetroArch installed via Flatpak (fallback — online updater enabled)"
        else
            msg_error "RetroArch installation failed"
        fi
    fi

    # Minimal retroarch.cfg — online updater manages all paths itself
    if [ "$RETROARCH_INSTALLED" = true ]; then
        msg_info "Configuring RetroArch defaults"
        RETROARCH_CFG_DIR="/home/kodi/.config/retroarch"
        mkdir -p "$RETROARCH_CFG_DIR"
        cat > "$RETROARCH_CFG_DIR/retroarch.cfg" <<'EOF'
# RetroArch defaults — paths are managed by the Online Updater
video_fullscreen = "true"
video_windowed_fullscreen = "false"
video_threaded = "true"
audio_sync = "true"
input_exit_emulator = escape
input_menu_toggle = f1
EOF
        chown -R kodi:kodi "$RETROARCH_CFG_DIR"
        msg_ok "RetroArch configured (use Online Updater → Core Downloader for cores)"
    fi
fi

# ─────────────────────────────────────────────
# KODI
# ─────────────────────────────────────────────
KODI_INSTALLED=false
if [[ "${INSTALL_KODI_PPA}" =~ ^[Yy] ]]; then
    msg_info "Installing Kodi from PPA (v20.x)"
    add-apt-repository -y ppa:team-xbmc/ppa &>/dev/null
    apt-get update -qq &>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq kodi &>/dev/null
    command -v kodi &>/dev/null \
        && KODI_INSTALLED=true && msg_ok "Kodi PPA installed" \
        || msg_error "Kodi PPA install failed"
elif [[ "${INSTALL_KODI_FLATPAK}" =~ ^[Yy] ]]; then
    msg_info "Installing Kodi via Flatpak (v21.x)"
    apt-get install -y -qq flatpak &>/dev/null
    flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo &>/dev/null
    flatpak install -y --noninteractive flathub tv.kodi.Kodi &>/dev/null
    flatpak list 2>/dev/null | grep -q "tv.kodi.Kodi" \
        && KODI_INSTALLED=true && msg_ok "Kodi Flatpak installed" \
        || msg_error "Kodi Flatpak install failed"
fi

# ─────────────────────────────────────────────
# STEAM
# ─────────────────────────────────────────────
STEAM_INSTALLED=false
if [[ "${INSTALL_STEAM}" =~ ^[Yy] ]]; then
    msg_info "Installing Steam"
    dpkg --add-architecture i386 &>/dev/null
    apt-get update -qq &>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq steam-installer &>/dev/null
    apt-get install -y -f -qq &>/dev/null
    ( command -v steam &>/dev/null || [ -f /usr/games/steam ] ) \
        && STEAM_INSTALLED=true && msg_ok "Steam installed" \
        || msg_error "Steam install failed"
fi

# ─────────────────────────────────────────────
# Optional apps
# ─────────────────────────────────────────────
if [[ "${INSTALL_FIREFOX}" =~ ^[Yy] ]]; then
    msg_info "Installing Firefox"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq firefox &>/dev/null \
        && msg_ok "Firefox installed" || msg_error "Firefox failed"
fi
if [[ "${INSTALL_BRAVE}" =~ ^[Yy] ]]; then
    msg_info "Installing Brave"
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg 2>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > /etc/apt/sources.list.d/brave-browser-release.list
    apt-get update -qq &>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq brave-browser &>/dev/null \
        && msg_ok "Brave installed" || msg_error "Brave failed"
fi
if [[ "${INSTALL_CHROME}" =~ ^[Yy] ]]; then
    msg_info "Installing Google Chrome"
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        -O /tmp/chrome.deb 2>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq /tmp/chrome.deb &>/dev/null
    rm -f /tmp/chrome.deb
    command -v google-chrome &>/dev/null \
        && msg_ok "Chrome installed" || msg_error "Chrome failed"
fi
if [[ "${INSTALL_LIBREOFFICE}" =~ ^[Yy] ]]; then
    msg_info "Installing LibreOffice"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libreoffice &>/dev/null \
        && msg_ok "LibreOffice installed" || msg_error "LibreOffice failed"
fi
if [[ "${INSTALL_VLC}" =~ ^[Yy] ]]; then
    msg_info "Installing VLC"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq vlc &>/dev/null \
        && msg_ok "VLC installed" || msg_error "VLC failed"
fi
if [[ "${INSTALL_GIMP}" =~ ^[Yy] ]]; then
    msg_info "Installing GIMP"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gimp &>/dev/null \
        && msg_ok "GIMP installed" || msg_error "GIMP failed"
fi

# ─────────────────────────────────────────────
# Session Manager
#
# Architecture:
#   lightdm autologins to "kodi-session" which runs this script directly.
#   No desktop is loaded. The screen is black except for the zenity dialog.
#   Apps launch fullscreen (kodi by default, retroarch --fullscreen,
#   steam -gamepadui). When an app exits the loop brings the dialog back.
#   Selecting "Desktop" is the ONLY thing that loads XFCE (exec startxfce4).
#
# Steam silent mode:
#   When a non-Steam session is launched AND Steam is installed, start Steam
#   with -silent so it updates games in the background. Steam's own lock
#   prevents double-launch if already running.
# ─────────────────────────────────────────────
msg_info "Installing Session Manager"

# ── Outer X session loop ──────────────────────────────────────────────────────
# This script IS the X session (called by kodi-session.desktop via lightdm).
# It sets up xterm with a scaled font and loops: show menu → launch app → repeat.
# All UI happens inside xterm running session-menu.sh (whiptail, ncurses-style).
cat > /usr/local/bin/session-manager.sh <<'SESSIONEOF'
#!/usr/bin/env bash
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

CONFIG_DIR="$HOME/.config/kodi-session"
CONFIG_FILE="$CONFIG_DIR/default"
mkdir -p "$CONFIG_DIR"

xsetroot -solid black 2>/dev/null || true

# Scale font size to screen height (~1pt per 40px, min 12)
SCREEN_H=$(xdpyinfo 2>/dev/null | grep -m1 dimensions | awk '{print $2}' | cut -dx -f2)
SCREEN_H=${SCREEN_H:-1080}
FONT_SIZE=$(( SCREEN_H / 40 ))
[ "$FONT_SIZE" -lt 12 ] && FONT_SIZE=12

# Detect Steam for silent background updates
HAVE_STEAM=false
( command -v steam &>/dev/null || [ -f /usr/games/steam ] ) && HAVE_STEAM=true

maybe_start_steam_silent() {
    $HAVE_STEAM || return 0
    pgrep -x steam &>/dev/null && return 0
    if command -v steam &>/dev/null; then
        steam -silent &>/dev/null &
    elif [ -f /usr/games/steam ]; then
        /usr/games/steam -silent &>/dev/null &
    fi
}

FIRST_RUN=true

while true; do
    CHOICE_FILE=$(mktemp /tmp/session-choice.XXXXXX)

    xterm -fullscreen \
          -fa 'Monospace' -fs "$FONT_SIZE" \
          -fg white -bg black \
          -title "Session Manager" \
          -e /usr/local/bin/session-menu.sh "$FIRST_RUN" "$CHOICE_FILE"

    FIRST_RUN=false
    CHOICE=$(cat "$CHOICE_FILE" 2>/dev/null)
    rm -f "$CHOICE_FILE"

    xsetroot -solid black 2>/dev/null || true

    case "$CHOICE" in
        "Kodi")
            maybe_start_steam_silent
            if command -v kodi &>/dev/null; then kodi
            else flatpak run tv.kodi.Kodi; fi
            ;;
        "RetroArch")
            maybe_start_steam_silent
            retroarch --fullscreen
            ;;
        "Steam Big Picture")
            xrandr --auto 2>/dev/null || true
            if command -v steam &>/dev/null; then steam -gamepadui -fulldesktopres
            elif [ -f /usr/games/steam ]; then /usr/games/steam -gamepadui -fulldesktopres; fi
            ;;
        "Desktop")
            exec startxfce4
            ;;
        "Shutdown")
            systemctl poweroff
            ;;
        "Restart")
            systemctl reboot
            ;;
        # Empty / ESC / unknown → loop back to menu
    esac

    xsetroot -solid black 2>/dev/null || true
done
SESSIONEOF
chmod +x /usr/local/bin/session-manager.sh

# ── Inner menu script (runs inside xterm, whiptail UI) ───────────────────────
# Handles countdown, menu display, Configure Audio, and Change Default.
# Writes the user's choice to CHOICE_FILE then exits so the outer loop acts.
cat > /usr/local/bin/session-menu.sh <<'MENUEOF'
#!/usr/bin/env bash
FIRST_RUN="$1"
CHOICE_FILE="$2"
COUNTDOWN_SECS=5

CONFIG_DIR="$HOME/.config/kodi-session"
CONFIG_FILE="$CONFIG_DIR/default"
mkdir -p "$CONFIG_DIR"

# ── Detect installed apps ─────────────────────────────────────────────────────
detect_apps() {
    HAVE_KODI=false; HAVE_RETROARCH=false; HAVE_STEAM=false
    ( command -v kodi &>/dev/null || \
      flatpak list 2>/dev/null | grep -q "tv.kodi.Kodi" ) && HAVE_KODI=true
    command -v retroarch &>/dev/null && HAVE_RETROARCH=true
    ( command -v steam &>/dev/null || [ -f /usr/games/steam ] ) && HAVE_STEAM=true
}

# ── Countdown (terminal style, any key cancels) ───────────────────────────────
show_countdown() {
    local label="$1"
    for i in $(seq "$COUNTDOWN_SECS" -1 1); do
        clear
        echo ""
        echo ""
        printf "  %-20s %s\n" "Launching:" "$label"
        echo ""
        printf "  %-20s %s\n" "Starting in:" "$i second(s)..."
        echo ""
        echo "  Press any key to open the session menu instead."
        echo ""
        if read -t 1 -n 1 -s; then
            return 1  # key pressed — cancelled
        fi
    done
    return 0  # timed out — launch
}

# ── Change boot default ───────────────────────────────────────────────────────
change_default() {
    detect_apps
    local opts=()
    $HAVE_KODI      && opts+=("Kodi"              "Launch Kodi on boot")
    $HAVE_RETROARCH && opts+=("RetroArch"         "Launch RetroArch on boot")
    $HAVE_STEAM     && opts+=("Steam Big Picture" "Launch Steam Big Picture on boot")
    opts+=("Desktop" "Show session menu on boot (no auto-launch)")

    local chosen
    chosen=$(whiptail --title "Change Boot Default" \
        --menu "Which session launches automatically on boot?" \
        $LINES $COLUMNS $(( ${#opts[@]} / 2 )) \
        "${opts[@]}" \
        3>&1 1>&2 2>&3)
    [ $? -ne 0 ] || [ -z "$chosen" ] && return

    if [ "$chosen" = "Desktop" ]; then
        rm -f "$CONFIG_FILE"
        whiptail --title "Done" \
            --msgbox "Boot default cleared.\nSession menu will appear on next boot." \
            8 50
    else
        echo "$chosen" > "$CONFIG_FILE"
        whiptail --title "Done" \
            --msgbox "Boot default set to: $chosen\n\nTakes effect on next boot." \
            8 50
    fi
}

# ── Configure Audio (TUI version for use inside the terminal session) ─────────
configure_audio_tui() {
    mapfile -t DEVICES      < <(aplay -l 2>/dev/null | grep -E "^card [0-9]+" | \
        sed 's/card \([0-9]\+\):.*device \([0-9]\+\):.*/\1,\2/')
    mapfile -t DEVICE_NAMES < <(aplay -l 2>/dev/null | grep -E "^card [0-9]+" | \
        sed 's/card [0-9]\+: \(.*\), device [0-9]\+: \(.*\) \[.*/\1 - \2/')

    if [ ${#DEVICES[@]} -eq 0 ]; then
        whiptail --title "No Devices" \
            --msgbox "No audio devices detected.\nMake sure /dev/snd is passed through." \
            8 52
        return
    fi

    local opts=()
    for i in "${!DEVICES[@]}"; do
        IFS=',' read -r C D <<< "${DEVICES[$i]}"
        opts+=("hw:${C},${D}" "${DEVICE_NAMES[$i]}")
    done

    local selected
    selected=$(whiptail --title "Select Audio Device" \
        --menu "Choose your audio output device:" \
        $LINES $COLUMNS ${#DEVICES[@]} \
        "${opts[@]}" \
        3>&1 1>&2 2>&3)
    [ $? -ne 0 ] || [ -z "$selected" ] && return

    local SEL_CARD SEL_DEV
    SEL_CARD=$(echo "$selected" | sed 's/hw:\([0-9]\+\),.*/\1/')
    SEL_DEV=$(echo  "$selected" | sed 's/hw:[0-9]\+,\([0-9]\+\)/\1/')

    # Test tone
    whiptail --title "Test Audio" \
        --msgbox "Playing test tone on $selected.\n\nPress OK to play." \
        8 52
    aplay -D plughw:${SEL_CARD},${SEL_DEV} \
        /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null

    if whiptail --title "Audio OK?" \
        --yesno "Did you hear the test sound on $selected?" 8 50; then
        mkdir -p ~/.config/pulse
        cat > ~/.config/pulse/default.pa <<EOF
#!/usr/bin/pulseaudio -nF
.include /etc/pulse/default.pa
load-module module-alsa-sink device=hw:${SEL_CARD},${SEL_DEV} sink_name=selected_output
set-default-sink selected_output
unload-module module-suspend-on-idle
EOF
        sudo bash -c "cat > /etc/asound.conf <<EOF
defaults.pcm.card ${SEL_CARD}
defaults.pcm.device ${SEL_DEV}
defaults.ctl.card ${SEL_CARD}
EOF"
        pulseaudio -k 2>/dev/null; sleep 1
        whiptail --title "Done" \
            --msgbox "Audio set to: $selected\n\nRestart any open apps to apply." \
            8 52
    else
        whiptail --title "Try Again?" \
            --yesno "Test failed. Try a different device?" 8 40 \
            && configure_audio_tui
    fi
}

# ── Main menu loop ────────────────────────────────────────────────────────────
detect_apps

DEFAULT=$(cat "$CONFIG_FILE" 2>/dev/null || echo "")

# Countdown on very first boot if a default is set
if [ "$FIRST_RUN" = "true" ] && [ -n "$DEFAULT" ] && [ "$DEFAULT" != "Desktop" ]; then
    if show_countdown "$DEFAULT"; then
        echo "$DEFAULT" > "$CHOICE_FILE"
        exit 0
    fi
    # Key pressed — fall through to menu
fi

# Menu loop: Configure Audio and Change Default loop back; everything else exits
while true; do
    detect_apps
    DEFAULT=$(cat "$CONFIG_FILE" 2>/dev/null || echo "")
    [ -n "$DEFAULT" ] && DEFAULT_LINE="Boot default: $DEFAULT" \
                       || DEFAULT_LINE="Boot default: (none — menu on boot)"

    MENU_ITEMS=()
    $HAVE_KODI      && MENU_ITEMS+=("Kodi"              "Media center")
    $HAVE_RETROARCH && MENU_ITEMS+=("RetroArch"         "Emulation frontend")
    $HAVE_STEAM     && MENU_ITEMS+=("Steam Big Picture" "Gaming — Big Picture mode")
    MENU_ITEMS+=("Desktop"         "Load XFCE desktop environment")
    MENU_ITEMS+=("Configure Audio" "Set up audio output device")
    MENU_ITEMS+=("Change Default"  "Change which app launches on boot")
    MENU_ITEMS+=("Restart"         "Restart the system")
    MENU_ITEMS+=("Shutdown"        "Shut down the system")

    MENU_H=$(( ${#MENU_ITEMS[@]} / 2 ))

    CHOICE=$(whiptail --title "Session Manager" \
        --menu "$DEFAULT_LINE\n\nSelect a session:" \
        $LINES $COLUMNS "$MENU_H" \
        "${MENU_ITEMS[@]}" \
        3>&1 1>&2 2>&3)

    # ESC or cancel — loop back (show menu again)
    [ $? -ne 0 ] && continue

    case "$CHOICE" in
        "Configure Audio")
            configure_audio_tui
            ;;
        "Change Default")
            change_default
            ;;
        *)
            # Any other choice exits to outer loop for action
            echo "$CHOICE" > "$CHOICE_FILE"
            exit 0
            ;;
    esac
done
MENUEOF
chmod +x /usr/local/bin/session-menu.sh

# Write boot default from install-time choice
SESSION_CONFIG_DIR="/home/kodi/.config/kodi-session"
mkdir -p "$SESSION_CONFIG_DIR"
if [ "$DEFAULT_SESSION" != "Desktop" ] && [ -n "$DEFAULT_SESSION" ]; then
    echo "$DEFAULT_SESSION" > "$SESSION_CONFIG_DIR/default"
    msg_ok "Session default written: $DEFAULT_SESSION"
else
    msg_ok "Session default: show menu on boot"
fi
chown -R kodi:kodi "$SESSION_CONFIG_DIR"
msg_ok "Session Manager installed"

# ─────────────────────────────────────────────
# XFCE autostart — only used when user selects Desktop
# Puts a session manager launcher on the desktop for convenience
# ─────────────────────────────────────────────
msg_info "Configuring XFCE desktop shortcuts"
mkdir -p /home/kodi/.config/autostart
mkdir -p /home/kodi/Desktop

# ── Shortcuts for installed apps ─────────────────────────────────────────────
if [ "$KODI_INSTALLED" = true ]; then
    if [[ "${INSTALL_KODI_PPA}" =~ ^[Yy] ]]; then
        cat > /home/kodi/Desktop/kodi.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Kodi
Comment=Launch Kodi Media Center
Exec=kodi
Icon=kodi
Terminal=false
X-XFCE-DesktopFile-Trusted=true
EOF
    else
        cat > /home/kodi/Desktop/kodi.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Kodi
Comment=Launch Kodi Media Center (Flatpak)
Exec=flatpak run tv.kodi.Kodi
Icon=kodi
Terminal=false
X-XFCE-DesktopFile-Trusted=true
EOF
    fi
fi

if [ "$RETROARCH_INSTALLED" = true ]; then
    cat > /home/kodi/Desktop/retroarch.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=RetroArch
Comment=Launch RetroArch emulation frontend
Exec=retroarch --fullscreen
Icon=retroarch
Terminal=false
Categories=Game;Emulator;
X-XFCE-DesktopFile-Trusted=true
EOF
    # PPA does not ship a .desktop file so RetroArch won't appear in the
    # applications menu without this. Create it in /usr/share/applications/.
    cat > /usr/share/applications/retroarch.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=RetroArch
Comment=Emulation frontend
Exec=retroarch --fullscreen
Icon=retroarch
Terminal=false
Categories=Game;Emulator;
Keywords=game;emulator;retro;
EOF
    update-desktop-database /usr/share/applications/ &>/dev/null || true
fi

if [ "$STEAM_INSTALLED" = true ]; then
    cat > /home/kodi/Desktop/steam-bigpicture.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Steam Big Picture
Comment=Launch Steam in Big Picture mode
Exec=steam -gamepadui -fulldesktopres
Icon=steam
Terminal=false
X-XFCE-DesktopFile-Trusted=true
EOF
    cat > /home/kodi/Desktop/steam.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Steam
Comment=Launch Steam normally
Exec=steam
Icon=steam
Terminal=false
X-XFCE-DesktopFile-Trusted=true
EOF
fi

cat > /home/kodi/Desktop/session-manager.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Exit to Session Manager
Comment=End desktop session and return to session chooser
Exec=pkill -TERM -u kodi xfce4-session
Icon=system-log-out
Terminal=false
X-XFCE-DesktopFile-Trusted=true
EOF

cat > /home/kodi/Desktop/configure-audio.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Configure Audio
Comment=Set audio output device
Exec=/usr/local/bin/configure-audio.sh
Icon=multimedia-volume-control
Terminal=false
X-XFCE-DesktopFile-Trusted=true
EOF

cat > /home/kodi/Desktop/volume-control.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Volume Control (ALSA)
Exec=xfce4-terminal --title="Volume Control" -e "alsamixer"
Icon=multimedia-volume-control
Terminal=false
X-XFCE-DesktopFile-Trusted=true
EOF

# systemctl poweroff/reboot work from the desktop because the polkit rule
# grants the kodi user full permissions. xfce4-session-logout --halt/--reboot
# triggers a DBus InvalidArgs bug on Ubuntu 22.04 and must not be used.
cat > /home/kodi/Desktop/shutdown.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Shutdown
Exec=systemctl poweroff
Icon=system-shutdown
Terminal=false
X-XFCE-DesktopFile-Trusted=true
EOF

cat > /home/kodi/Desktop/reboot.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Reboot
Exec=systemctl reboot
Icon=system-reboot
Terminal=false
X-XFCE-DesktopFile-Trusted=true
EOF

for f in /home/kodi/Desktop/*.desktop; do
    chmod +x "$f"
    chown kodi:kodi "$f"
done

# gio set metadata::trusted only works inside a live GVfs session, so we
# create a self-deleting XFCE autostart script that runs it on first login.
cat > /home/kodi/.config/autostart/trust-desktop-shortcuts.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Trust Desktop Shortcuts
Comment=Sets trusted flag on desktop icons (runs once)
Exec=/usr/local/bin/trust-desktop-shortcuts.sh
X-XFCE-Autostart-enabled=true
EOF

cat > /usr/local/bin/trust-desktop-shortcuts.sh <<'EOF'
#!/usr/bin/env bash
# Runs once on first XFCE login to mark all desktop shortcuts as trusted.
# Deletes itself after running so it never appears again.
sleep 2  # give GVfs a moment to start
for f in ~/Desktop/*.desktop; do
    gio set "$f" metadata::trusted true 2>/dev/null || true
done
rm -f ~/.config/autostart/trust-desktop-shortcuts.desktop
rm -f "$0"
EOF
chmod +x /usr/local/bin/trust-desktop-shortcuts.sh

msg_ok "Desktop shortcuts created"

# ─────────────────────────────────────────────
# Per-app installer shortcuts for skipped apps
# ─────────────────────────────────────────────
msg_info "Creating app installer shortcuts"

write_installer_shortcut() {
    local key="$1"
    local label="$2"
    local cmd="$3"
    local script="/usr/local/bin/install-${key,,}.sh"
    local desktop="/home/kodi/Desktop/install-${key,,}.desktop"

    cat > "$script" <<SCRIPTEOF
#!/usr/bin/env bash
echo "${label}..."
${cmd}
echo "Done."
read -p "Press Enter to close..."
SCRIPTEOF
    chmod +x "$script"

    cat > "$desktop" <<DESKEOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${label}
Exec=xfce4-terminal --hold -e "sudo ${script}"
Terminal=false
X-XFCE-DesktopFile-Trusted=true
DESKEOF
    chmod +x "$desktop"
    chown kodi:kodi "$desktop"
}

! [ "$RETROARCH_INSTALLED" = true ] && \
write_installer_shortcut "RETROARCH" "Install RetroArch" \
'apt-get install -y -qq libgl1 libgles2 libegl1 libsdl2-2.0-0 libavcodec58 libavformat58 libswscale5 libfreetype6 libasound2 curl fuse &>/dev/null
BUILDBOT_BASE="https://buildbot.libretro.com/nightly/linux/x86_64/latest"
APPIMAGE=$(curl -s "${BUILDBOT_BASE}/" | grep -oP "RetroArch[^\"]+\.AppImage" | head -1)
if [ -n "$APPIMAGE" ]; then
    echo "Downloading $APPIMAGE from buildbot..."
    wget -q "${BUILDBOT_BASE}/${APPIMAGE}" -O /opt/RetroArch.AppImage
    chmod +x /opt/RetroArch.AppImage
    printf "#!/usr/bin/env bash\nexec /opt/RetroArch.AppImage \"\$@\"\n" > /usr/local/bin/retroarch
    chmod +x /usr/local/bin/retroarch
    echo "RetroArch installed from buildbot (online updater enabled)."
else
    echo "Buildbot download failed — trying Flatpak..."
    apt-get install -y flatpak &>/dev/null
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &>/dev/null
    flatpak install -y --noninteractive flathub org.libretro.RetroArch &>/dev/null
    printf "#!/usr/bin/env bash\nexec flatpak run org.libretro.RetroArch \"\$@\"\n" > /usr/local/bin/retroarch
    chmod +x /usr/local/bin/retroarch
    echo "RetroArch installed via Flatpak."
fi'

! [ "$STEAM_INSTALLED" = true ] && \
write_installer_shortcut "STEAM" "Install Steam" \
'dpkg --add-architecture i386 &>/dev/null
apt-get update &>/dev/null
apt-get install -y steam-installer &>/dev/null
apt-get install -y -f &>/dev/null
echo "Steam installed."'

! [[ "${INSTALL_FIREFOX}" =~ ^[Yy] ]] && \
write_installer_shortcut "FIREFOX" "Install Firefox" \
'apt-get install -y firefox &>/dev/null && echo "Firefox installed." || echo "Install failed."'

! [[ "${INSTALL_BRAVE}" =~ ^[Yy] ]] && \
write_installer_shortcut "BRAVE" "Install Brave" \
'curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
https://brave-browser-apt-release.s3.brave.com/ stable main" \
    > /etc/apt/sources.list.d/brave-browser-release.list
apt-get update &>/dev/null
apt-get install -y brave-browser &>/dev/null && echo "Brave installed." || echo "Install failed."'

! [[ "${INSTALL_CHROME}" =~ ^[Yy] ]] && \
write_installer_shortcut "CHROME" "Install Google Chrome" \
'wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
apt-get install -y /tmp/chrome.deb &>/dev/null
rm -f /tmp/chrome.deb
command -v google-chrome &>/dev/null && echo "Chrome installed." || echo "Install failed."'

! [[ "${INSTALL_LIBREOFFICE}" =~ ^[Yy] ]] && \
write_installer_shortcut "LIBREOFFICE" "Install LibreOffice" \
'apt-get install -y libreoffice &>/dev/null && echo "LibreOffice installed." || echo "Install failed."'

! [[ "${INSTALL_VLC}" =~ ^[Yy] ]] && \
write_installer_shortcut "VLC" "Install VLC" \
'apt-get install -y vlc &>/dev/null && echo "VLC installed." || echo "Install failed."'

! [[ "${INSTALL_GIMP}" =~ ^[Yy] ]] && \
write_installer_shortcut "GIMP" "Install GIMP" \
'apt-get install -y gimp &>/dev/null && echo "GIMP installed." || echo "Install failed."'

# Kodi version switcher shortcuts (always present)
cat > /usr/local/bin/install-kodi-ppa.sh <<'EOF'
#!/usr/bin/env bash
echo "Switching to Kodi PPA (v20.x)..."
flatpak list 2>/dev/null | grep -q "tv.kodi.Kodi" && flatpak uninstall -y tv.kodi.Kodi &>/dev/null && echo "Removed Flatpak version."
add-apt-repository -y ppa:team-xbmc/ppa &>/dev/null
apt-get update &>/dev/null && apt-get install -y kodi &>/dev/null
command -v kodi &>/dev/null && echo "Kodi PPA installed!" || echo "Install failed."
read -p "Press Enter to close..."
EOF
chmod +x /usr/local/bin/install-kodi-ppa.sh

cat > /home/kodi/Desktop/install-kodi-ppa.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Switch to Kodi (PPA)
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-kodi-ppa.sh"
Icon=kodi
Terminal=false
X-XFCE-DesktopFile-Trusted=true
EOF

cat > /usr/local/bin/install-kodi-flatpak.sh <<'EOF'
#!/usr/bin/env bash
echo "Switching to Kodi Flatpak (v21.x)..."
dpkg -l | grep -q "^ii  kodi " && apt-get remove -y kodi kodi-bin kodi-data &>/dev/null && apt-get autoremove -y &>/dev/null && echo "Removed PPA version."
apt-get install -y flatpak &>/dev/null
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &>/dev/null
flatpak install -y --noninteractive flathub tv.kodi.Kodi &>/dev/null
flatpak list | grep -q "tv.kodi.Kodi" && echo "Kodi Flatpak installed!" || echo "Install failed."
read -p "Press Enter to close..."
EOF
chmod +x /usr/local/bin/install-kodi-flatpak.sh

cat > /home/kodi/Desktop/install-kodi-flatpak.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Switch to Kodi (Flatpak)
Exec=xfce4-terminal --hold -e "sudo /usr/local/bin/install-kodi-flatpak.sh"
Icon=kodi
Terminal=false
X-XFCE-DesktopFile-Trusted=true
EOF

for f in /home/kodi/Desktop/*.desktop; do
    chmod +x "$f"
    chown kodi:kodi "$f"
done

chown -R kodi:kodi /home/kodi/.config /home/kodi/Desktop

msg_ok "Installer shortcuts done"

# ─────────────────────────────────────────────
# Session environment
# ─────────────────────────────────────────────
cat > /home/kodi/.xprofile <<'EOF'
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/1000
EOF
chown kodi:kodi /home/kodi/.xprofile

sudo -u kodi XDG_RUNTIME_DIR=/run/user/1000 \
    systemctl --user enable pulseaudio.socket pulseaudio.service &>/dev/null || true

# ─────────────────────────────────────────────
# Start lightdm
# ─────────────────────────────────────────────
msg_info "Starting lightdm"
systemctl enable lightdm &>/dev/null
systemctl restart lightdm &>/dev/null || true
msg_ok "lightdm started"

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo -e "\n${GN}╔═══════════════════════════════════════════════════╗${CL}"
echo -e "${GN}║           xfce-install complete!                  ║${CL}"
echo -e "${GN}╚═══════════════════════════════════════════════════╝${CL}"

echo -e "\n${BL}Session Manager:${CL}"
if [ "$DEFAULT_SESSION" != "Desktop" ] && [ -n "$DEFAULT_SESSION" ]; then
    echo -e "  • Boot: ${GN}black screen → $DEFAULT_SESSION countdown → fullscreen${CL}"
else
    echo -e "  • Boot: ${GN}black screen → session menu${CL}"
fi
echo -e "  • After any app exits → session menu reappears (black background)"
echo -e "  • Desktop (XFCE) only loads if explicitly selected"
echo -e "  • Steam runs silently in background when not the active session"

echo -e "\n${BL}Installed:${CL}"
[ "$KODI_INSTALLED"      = true ]       && echo -e "  ${CM} Kodi"
[ "$RETROARCH_INSTALLED" = true ]       && echo -e "  ${CM} RetroArch  (fullscreen — download cores via Online Updater)"
[ "$STEAM_INSTALLED"     = true ]       && echo -e "  ${CM} Steam"
[[ "${INSTALL_FIREFOX}"    =~ ^[Yy] ]] && echo -e "  ${CM} Firefox"
[[ "${INSTALL_BRAVE}"      =~ ^[Yy] ]] && echo -e "  ${CM} Brave"
[[ "${INSTALL_CHROME}"     =~ ^[Yy] ]] && echo -e "  ${CM} Chrome"
[[ "${INSTALL_LIBREOFFICE}" =~ ^[Yy] ]] && echo -e "  ${CM} LibreOffice"
[[ "${INSTALL_VLC}"        =~ ^[Yy] ]] && echo -e "  ${CM} VLC"
[[ "${INSTALL_GIMP}"       =~ ^[Yy] ]] && echo -e "  ${CM} GIMP"

if [ "$SKIP_AUDIO" = false ]; then
    echo -e "\n${BL}Audio:${CL} hw:${SELECTED_CARD},${SELECTED_DEV} — ${SELECTED_DEVICE_NAME}"
else
    echo -e "\n${BL}Audio:${CL} not configured — use ${GN}Configure Audio${CL} from session menu"
fi
echo ""
