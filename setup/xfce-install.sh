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

msg_info "Installing XFCE Desktop Environment"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    xfce4 xfce4-goodies xfce4-terminal \
    xorg xserver-xorg-video-intel \
    zenity \
    pulseaudio pulseaudio-utils pavucontrol alsa-utils \
    software-properties-common curl wget \
    &>/dev/null
msg_ok "Installed XFCE"

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
# lightdm autologin
# ─────────────────────────────────────────────
msg_info "Configuring lightdm autologin"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    lightdm lightdm-gtk-greeter &>/dev/null
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/autologin-kodi.conf <<'EOF'
[Seat:*]
autologin-user=kodi
autologin-session=xfce
EOF
msg_ok "lightdm configured"

# ─────────────────────────────────────────────
# Xorg input detection (LXC-friendly)
# ─────────────────────────────────────────────
msg_info "Configuring Xorg input detection"
apt-get install -y -qq xserver-xorg-input-evdev &>/dev/null
cat > /usr/local/bin/preX-populate-input.sh <<'EOF'
#!/usr/bin/env bash
CFG=/etc/X11/xorg.conf.d/10-lxc-input.conf
mkdir -p /etc/X11/xorg.conf.d
cat > "$CFG" <<'_SEC_'
Section "ServerFlags"
    Option "AutoAddDevices" "True"
EndSection
_SEC_'
cd /dev/input
for input in event*; do
cat >> "$CFG" <<_SEC_
Section "InputDevice"
    Identifier "$input"
    Option "Device" "/dev/input/$input"
    Option "AutoServerLayout" "true"
    Driver "evdev"
EndSection
_SEC_
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
msg_ok "Xorg input configured"

# ─────────────────────────────────────────────
# PolicyKit — let kodi user do system actions
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
# PulseAudio baseline config
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
        msg_error "No audio devices detected — skipping (configure later from session menu)"
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
# (also reachable from the session menu)
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
    --text="Playing test tone on $SELECTED — listen for a beep.\n\nClick OK to play." \
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
# RETROARCH
# Install the binary from the official Libretro PPA.
# We do NOT install separate libretro-* core packages — they are unreliable
# in the stable PPA. Cores should be downloaded from inside RetroArch via:
#   Main Menu → Online Updater → Core Downloader
# Flatpak is used as a fallback if the PPA fails.
# ─────────────────────────────────────────────
RETROARCH_INSTALLED=false
if [[ "${INSTALL_RETROARCH}" =~ ^[Yy] ]]; then
    msg_info "Adding Libretro stable PPA"
    add-apt-repository -y ppa:libretro/stable &>/dev/null
    apt-get update -qq &>/dev/null
    msg_ok "Libretro PPA added"

    msg_info "Installing RetroArch"
    if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq retroarch retroarch-assets 2>/dev/null; then
        if command -v retroarch &>/dev/null; then
            RETROARCH_INSTALLED=true
            msg_ok "RetroArch installed via PPA"
        fi
    fi

    if [ "$RETROARCH_INSTALLED" = false ]; then
        msg_error "PPA install failed — trying Flatpak fallback"
        apt-get install -y -qq flatpak &>/dev/null
        flatpak remote-add --if-not-exists flathub \
            https://flathub.org/repo/flathub.flatpakrepo &>/dev/null
        if flatpak install -y --noninteractive flathub org.libretro.RetroArch &>/dev/null; then
            RETROARCH_INSTALLED=true
            # Create a wrapper so 'retroarch' works as a plain command
            cat > /usr/local/bin/retroarch <<'EOF'
#!/usr/bin/env bash
exec flatpak run org.libretro.RetroArch "$@"
EOF
            chmod +x /usr/local/bin/retroarch
            msg_ok "RetroArch installed via Flatpak (fallback)"
        else
            msg_error "RetroArch installation failed — skipping"
        fi
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
    command -v kodi &>/dev/null && KODI_INSTALLED=true && msg_ok "Kodi PPA installed" \
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
    apt-get install -y -f -qq &>/dev/null   # fix any broken deps
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
# Written to /usr/local/bin/session-manager.sh via heredoc.
# This is the single XFCE autostart entry — it replaces all individual
# per-app autostart files.
#
# Steam silent mode logic:
#   When a non-Steam session is launched AND Steam is installed,
#   start Steam in -silent mode so it can patch games in the background.
#   Steam's own lock prevents double-launch if already running.
# ─────────────────────────────────────────────
msg_info "Installing Session Manager"

cat > /usr/local/bin/session-manager.sh <<'SESSIONEOF'
#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Session Manager
# Single XFCE autostart entry. Shows countdown before default app, loops back
# to menu after each app exits. Steam runs silently in background for updates
# whenever it isn't the foreground session.
# ─────────────────────────────────────────────────────────────────────────────

export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

CONFIG_DIR="$HOME/.config/kodi-session"
CONFIG_FILE="$CONFIG_DIR/default"
COUNTDOWN_SECS=5

mkdir -p "$CONFIG_DIR"

# ── Detect installed apps ────────────────────
detect_apps() {
    HAVE_KODI=false
    HAVE_RETROARCH=false
    HAVE_STEAM=false

    ( command -v kodi &>/dev/null || \
      flatpak list 2>/dev/null | grep -q "tv.kodi.Kodi" ) && HAVE_KODI=true
    command -v retroarch &>/dev/null && HAVE_RETROARCH=true
    ( command -v steam &>/dev/null || [ -f /usr/games/steam ] || \
      command -v retroarch &>/dev/null && flatpak list 2>/dev/null | grep -q "com.valvesoftware.Steam" \
    ) && HAVE_STEAM=true
    # Simpler steam check
    ( command -v steam &>/dev/null || [ -f /usr/games/steam ] ) && HAVE_STEAM=true
}

# ── Launch Steam silently for background updates ─────────────────────────────
# Only starts Steam if it isn't already running. Uses -silent so no window.
maybe_start_steam_silent() {
    $HAVE_STEAM || return 0
    pgrep -x steam &>/dev/null && return 0   # already running
    if command -v steam &>/dev/null; then
        steam -silent &>/dev/null &
    elif [ -f /usr/games/steam ]; then
        /usr/games/steam -silent &>/dev/null &
    fi
}

# ── Build zenity menu rows ───────────────────
build_menu_rows() {
    MENU_ROWS=()
    detect_apps
    $HAVE_KODI       && MENU_ROWS+=("Kodi"              "Media center")
    $HAVE_RETROARCH  && MENU_ROWS+=("RetroArch"         "Emulation frontend")
    $HAVE_STEAM      && MENU_ROWS+=("Steam Big Picture" "Gaming (Big Picture mode)")
    MENU_ROWS+=("─────────────────────" "")
    MENU_ROWS+=("Desktop"              "Stay in XFCE desktop")
    MENU_ROWS+=("─────────────────────" "")
    MENU_ROWS+=("Configure Audio"      "Set up audio output device")
    MENU_ROWS+=("Change Default"       "Choose which app launches on boot")
    MENU_ROWS+=("─────────────────────" "")
    MENU_ROWS+=("Restart"              "Restart the system")
    MENU_ROWS+=("Shutdown"             "Shut down the system")
}

# ── 5-second countdown before default app ───
# Returns 0 = timed out (launch default), 1 = cancelled (show menu)
show_countdown() {
    local label="$1"
    (
        for i in $(seq "$COUNTDOWN_SECS" -1 1); do
            echo $(( 100 - (i * 100 / COUNTDOWN_SECS) ))
            echo "# Launching $label in $i second(s)...

Press Cancel to open the session menu."
            sleep 1
        done
        echo "100"
    ) | zenity --progress \
            --title="Session Manager" \
            --text="Preparing $label..." \
            --width=420 \
            --auto-close \
            2>/dev/null
    return $?
}

# ── Session selection menu ───────────────────
show_menu() {
    build_menu_rows
    local default_label
    default_label=$(cat "$CONFIG_FILE" 2>/dev/null || echo "")
    local subtitle
    [ -n "$default_label" ] \
        && subtitle="\nBoot default: <b>$default_label</b>" \
        || subtitle="\nNo boot default set."

    zenity --list \
        --title="Session Manager" \
        --text="Welcome! What would you like to do?$subtitle" \
        --column="Session" --column="Description" \
        --width=520 --height=480 \
        --hide-column=0 --print-column=1 \
        "${MENU_ROWS[@]}" \
        2>/dev/null
}

# ── Change boot default ──────────────────────
change_default() {
    detect_apps
    local opts=()
    $HAVE_KODI      && opts+=("Kodi"              "Launch Kodi on boot")
    $HAVE_RETROARCH && opts+=("RetroArch"         "Launch RetroArch on boot")
    $HAVE_STEAM     && opts+=("Steam Big Picture" "Launch Steam Big Picture on boot")
    opts+=("Desktop" "No auto-launch — show session menu on boot")

    local chosen
    chosen=$(zenity --list \
        --title="Change Boot Default" \
        --text="Choose which session starts automatically on boot:" \
        --column="Session" --column="Description" \
        --width=500 --height=340 \
        --hide-column=0 --print-column=1 \
        "${opts[@]}" 2>/dev/null)
    [ -z "$chosen" ] && return

    if [ "$chosen" = "Desktop" ]; then
        rm -f "$CONFIG_FILE"
        zenity --info --title="Default Cleared" \
            --text="Boot default cleared.\nSession menu will appear on next start." \
            --width=360 2>/dev/null
    else
        echo "$chosen" > "$CONFIG_FILE"
        zenity --info --title="Default Saved" \
            --text="Boot default set to: <b>$chosen</b>\n\nTakes effect on next boot." \
            --width=360 2>/dev/null
    fi
}

# ── Launch an app by menu label ──────────────
launch_app() {
    case "$1" in
        "Kodi")
            if command -v kodi &>/dev/null; then
                kodi
            else
                flatpak run tv.kodi.Kodi
            fi
            ;;
        "RetroArch")
            retroarch
            ;;
        "Steam Big Picture")
            if command -v steam &>/dev/null; then
                steam -gamepadui
            elif [ -f /usr/games/steam ]; then
                /usr/games/steam -gamepadui
            else
                flatpak run com.valvesoftware.Steam -gamepadui
            fi
            ;;
    esac
}

# ── Main loop ────────────────────────────────
detect_apps   # initial detection before the loop

while true; do
    DEFAULT=$(cat "$CONFIG_FILE" 2>/dev/null || echo "")

    if [ -n "$DEFAULT" ] && [ "$DEFAULT" != "Desktop" ]; then
        if show_countdown "$DEFAULT"; then
            CHOICE="$DEFAULT"
        else
            CHOICE=$(show_menu)
        fi
    else
        CHOICE=$(show_menu)
    fi

    # Treat separators and closed dialog as Desktop
    case "$CHOICE" in
        "─────────────────────"|"") CHOICE="Desktop" ;;
    esac

    case "$CHOICE" in
        "Kodi"|"RetroArch")
            # Non-Steam foreground session: start Steam silently for updates
            maybe_start_steam_silent
            launch_app "$CHOICE"
            ;;
        "Steam Big Picture")
            # Steam IS the foreground session — launch normally
            launch_app "$CHOICE"
            ;;
        "Desktop")
            # Start Steam silently then release to desktop
            maybe_start_steam_silent
            break
            ;;
        "Configure Audio")
            /usr/local/bin/configure-audio.sh
            ;;
        "Change Default")
            change_default
            ;;
        "Restart")
            systemctl reboot
            ;;
        "Shutdown")
            systemctl poweroff
            ;;
    esac
done
SESSIONEOF

chmod +x /usr/local/bin/session-manager.sh

# Write the boot default chosen at install time
SESSION_CONFIG_DIR="/home/kodi/.config/kodi-session"
mkdir -p "$SESSION_CONFIG_DIR"
if [ "$DEFAULT_SESSION" != "Desktop" ] && [ -n "$DEFAULT_SESSION" ]; then
    echo "$DEFAULT_SESSION" > "$SESSION_CONFIG_DIR/default"
    msg_ok "Session default written: $DEFAULT_SESSION"
else
    msg_ok "Session default: show menu on boot"
fi
chown -R kodi:kodi "$SESSION_CONFIG_DIR"
msg_ok "Session Manager installed → /usr/local/bin/session-manager.sh"

# ─────────────────────────────────────────────
# XFCE autostart — single entry pointing to session manager
# ─────────────────────────────────────────────
msg_info "Configuring XFCE autostart"
mkdir -p /home/kodi/.config/autostart
cat > /home/kodi/.config/autostart/session-manager.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Session Manager
Comment=Boot session chooser
Exec=/usr/local/bin/session-manager.sh
X-XFCE-Autostart-enabled=true
EOF
chown kodi:kodi /home/kodi/.config/autostart/session-manager.desktop
msg_ok "XFCE autostart → session-manager"

# ─────────────────────────────────────────────
# Desktop shortcuts
# ─────────────────────────────────────────────
msg_info "Creating desktop shortcuts"
mkdir -p /home/kodi/Desktop

cat > /home/kodi/Desktop/session-manager.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Session Manager
Comment=Open the session chooser menu
Exec=/usr/local/bin/session-manager.sh
Icon=preferences-system
Terminal=false
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
EOF

cat > /home/kodi/Desktop/volume-control.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Volume Control (ALSA)
Exec=xfce4-terminal --title="Volume Control" -e "alsamixer"
Icon=multimedia-volume-control
Terminal=false
EOF

cat > /home/kodi/Desktop/shutdown.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Shutdown
Exec=systemctl poweroff
Icon=system-shutdown
Terminal=false
EOF

cat > /home/kodi/Desktop/reboot.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Reboot
Exec=systemctl reboot
Icon=system-reboot
Terminal=false
EOF

for f in /home/kodi/Desktop/*.desktop; do
    chmod +x "$f"
    chown kodi:kodi "$f"
    sudo -u kodi gio set "$f" metadata::trusted true 2>/dev/null || true
done
msg_ok "Desktop shortcuts created"

# ─────────────────────────────────────────────
# Per-app installer desktop shortcuts
# Only created for apps that were NOT installed at setup time.
# Each shortcut self-destructs after install.
# ─────────────────────────────────────────────
msg_info "Creating installer shortcuts for skipped apps"

# Helper: write an installer script + matching .desktop shortcut
write_installer_shortcut() {
    local key="$1"       # e.g. RETROARCH
    local label="$2"     # e.g. "Install RetroArch"
    local cmd="$3"       # shell commands to install the app
    local script="/usr/local/bin/install-${key,,}.sh"
    local desktop="/home/kodi/Desktop/install-${key,,}.desktop"

    cat > "$script" <<SCRIPTEOF
#!/usr/bin/env bash
echo "${label}..."
${cmd}
echo "Done. Removing this launcher..."
rm -f "$desktop"
rm -f "\$0"
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
DESKEOF
    chmod +x "$desktop"
    chown kodi:kodi "$desktop"
}

# RetroArch installer shortcut
if ! [ "$RETROARCH_INSTALLED" = true ]; then
    write_installer_shortcut "RETROARCH" "Install RetroArch" \
'apt-get install -y software-properties-common &>/dev/null
add-apt-repository -y ppa:libretro/stable &>/dev/null
apt-get update &>/dev/null
if apt-get install -y retroarch retroarch-assets 2>/dev/null && command -v retroarch &>/dev/null; then
    echo "RetroArch installed via PPA."
else
    echo "PPA failed — trying Flatpak..."
    apt-get install -y flatpak &>/dev/null
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &>/dev/null
    flatpak install -y --noninteractive flathub org.libretro.RetroArch &>/dev/null
    cat > /usr/local/bin/retroarch <<EOF
#!/usr/bin/env bash
exec flatpak run org.libretro.RetroArch "\$@"
EOF
    chmod +x /usr/local/bin/retroarch
    echo "RetroArch installed via Flatpak."
fi
echo ""
echo "Download cores from inside RetroArch:"
echo "  Main Menu → Online Updater → Core Downloader"'
fi

# Steam installer shortcut
if ! [ "$STEAM_INSTALLED" = true ]; then
    write_installer_shortcut "STEAM" "Install Steam" \
'dpkg --add-architecture i386 &>/dev/null
apt-get update &>/dev/null
apt-get install -y steam-installer &>/dev/null
apt-get install -y -f &>/dev/null
echo "Steam installed."'
fi

# Kodi PPA/Flatpak switcher shortcuts (always present — allow easy switching)
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
EOF

for f in /home/kodi/Desktop/*.desktop; do
    chmod +x "$f"
    chown kodi:kodi "$f"
    sudo -u kodi gio set "$f" metadata::trusted true 2>/dev/null || true
done
msg_ok "Installer shortcuts done"

# ─────────────────────────────────────────────
# XFCE / session environment
# ─────────────────────────────────────────────
cat > /home/kodi/.xprofile <<'EOF'
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/1000
EOF
chown kodi:kodi /home/kodi/.xprofile
chown -R kodi:kodi /home/kodi/.config /home/kodi/Desktop

# PulseAudio user service
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
    echo -e "  • Boot default: ${GN}$DEFAULT_SESSION${CL} (5-second countdown, cancellable)"
else
    echo -e "  • Boot default: ${GN}session menu appears immediately${CL}"
fi
echo -e "  • After any app exits → session menu reappears automatically"
echo -e "  • Steam starts silently in background (updates) when not the active session"
echo -e "  • Change default any time: session menu → Change Default"

echo -e "\n${BL}Installed:${CL}"
[ "$KODI_INSTALLED"      = true ]    && echo -e "  ${CM} Kodi"
[ "$RETROARCH_INSTALLED" = true ]    && echo -e "  ${CM} RetroArch  (download cores from Main Menu → Online Updater → Core Downloader)"
[ "$STEAM_INSTALLED"     = true ]    && echo -e "  ${CM} Steam"
[[ "${INSTALL_FIREFOX}"    =~ ^[Yy] ]] && echo -e "  ${CM} Firefox"
[[ "${INSTALL_BRAVE}"      =~ ^[Yy] ]] && echo -e "  ${CM} Brave"
[[ "${INSTALL_CHROME}"     =~ ^[Yy] ]] && echo -e "  ${CM} Chrome"
[[ "${INSTALL_LIBREOFFICE}" =~ ^[Yy] ]] && echo -e "  ${CM} LibreOffice"
[[ "${INSTALL_VLC}"        =~ ^[Yy] ]] && echo -e "  ${CM} VLC"
[[ "${INSTALL_GIMP}"       =~ ^[Yy] ]] && echo -e "  ${CM} GIMP"

if [ "$SKIP_AUDIO" = false ]; then
    echo -e "\n${BL}Audio:${CL} hw:${SELECTED_CARD},${SELECTED_DEV} — ${SELECTED_DEVICE_NAME}"
else
    echo -e "\n${BL}Audio:${CL} not configured — use ${GN}Configure Audio${CL} from session menu or desktop"
fi
echo ""
