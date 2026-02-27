#!/usr/bin/env bash

echo -e "Loading..."
APP="kodi"
var_disk="8"
var_cpu="2"
var_ram="2048"
var_os="ubuntu"
var_version="22.04"
NSAPP=$(echo ${APP,,} | tr -d ' ')
var_install="${NSAPP}-install"
NEXTID=$(pvesh get /cluster/nextid)
INTEGER='^[0-9]+$'
YW=`echo "\033[33m"`
BL=`echo "\033[36m"`
RD=`echo "\033[01;31m"`
BGN=`echo "\033[4;92m"`
GN=`echo "\033[1;92m"`
DGN=`echo "\033[32m"`
CL=`echo "\033[m"`
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
function error_exit() {
  trap - ERR
  local reason="Unknown failure occurred."
  local msg="${1:-$reason}"
  local flag="${RD}‼ ERROR ${CL}$EXIT@$LINE"
  echo -e "$flag $msg" 1>&2
  exit $EXIT
}
if (whiptail --title "${APP} LXC" --yesno "This will create a New ${APP} LXC. Proceed?" 10 58); then
    echo "User selected Yes"
else
    clear
    echo -e "⚠ User exited script \n"
    exit
fi
function header_info {
echo -e "kodi---------\n\n"
}
function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}
function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

SETTINGS_FILE="/root/.kodi-lxc-settings.conf"

function save_settings() {
    cat > "$SETTINGS_FILE" <<EOF
# Kodi LXC Settings - Last saved $(date)
var_version="$var_version"
CT_TYPE="$CT_TYPE"
PW="$PW"
CT_ID="$CT_ID"
HN="$HN"
DISK_SIZE="$DISK_SIZE"
CORE_COUNT="$CORE_COUNT"
RAM_SIZE="$RAM_SIZE"
BRG="$BRG"
NET="$NET"
GATE="$GATE"
DNS="$DNS"
MAC="$MAC"
VLAN="$VLAN"
INSTALL_MODE="$INSTALL_MODE"
INSTALL_APPS="$INSTALL_APPS"
KODI_PASS="$KODI_PASS"
CONFIGURE_AUDIO="$CONFIGURE_AUDIO"
KODI_AUTOSTART="$KODI_AUTOSTART"
STEAM_AUTOSTART="$STEAM_AUTOSTART"
EOF
    echo -e "${GN}Settings saved to $SETTINGS_FILE${CL}"
}

function load_settings() {
    if [ -f "$SETTINGS_FILE" ]; then
        source "$SETTINGS_FILE"
        echo -e "${GN}Settings loaded from previous session${CL}"
        return 0
    else
        return 1
    fi
}

function show_saved_settings() {
    echo -e "\n${GN}=== Previously Saved Settings ===${CL}"
    echo -e "${DGN}Ubuntu Version: ${BGN}$var_version${CL}"
    echo -e "${DGN}Container Type: ${BGN}$([ "$CT_TYPE" = "1" ] && echo "Unprivileged" || echo "Privileged")${CL}"
    echo -e "${DGN}Container ID: ${BGN}$CT_ID${CL}"
    echo -e "${DGN}Hostname: ${BGN}$HN${CL}"
    echo -e "${DGN}Disk Size: ${BGN}${DISK_SIZE}GB${CL}"
    echo -e "${DGN}CPU Cores: ${BGN}$CORE_COUNT${CL}"
    echo -e "${DGN}RAM: ${BGN}${RAM_SIZE}MB${CL}"
    echo -e "${DGN}Bridge: ${BGN}$BRG${CL}"
    echo -e "${DGN}IP: ${BGN}$NET${CL}"
    echo -e "${DGN}Gateway: ${BGN}${GATE:-Default}${CL}"
    echo -e "${DGN}DNS: ${BGN}${DNS:-Default}${CL}"
    echo -e "${DGN}MAC: ${BGN}${MAC:-Default}${CL}"
    echo -e "${DGN}VLAN: ${BGN}${VLAN:-Default}${CL}"
    echo -e "${DGN}Install Mode: ${BGN}$INSTALL_MODE${CL}"
    if [ "$INSTALL_MODE" = "xfce" ]; then
        echo -e "${DGN}Apps: ${BGN}${INSTALL_APPS:-None}${CL}"
    fi
    echo ""
}

function default_settings() {
                echo -e "${DGN}Using ${var_os} Version: ${BGN}${var_version}${CL}"

    echo -e "${DGN}Using Container Type: ${BGN}Unprivileged${CL}"
    CT_TYPE="1"
                echo -e "${DGN}Using Root Password: ${BGN}Automatic Login${CL}"
                PW=""
                echo -e "${DGN}Using Container ID: ${BGN}$NEXTID${CL}"
                CT_ID=$NEXTID
                echo -e "${DGN}Using Hostname: ${BGN}$NSAPP${CL}"
                HN=$NSAPP
                echo -e "${DGN}Using Disk Size: ${BGN}$var_disk${CL}${DGN}GB${CL}"
                DISK_SIZE="$var_disk"
                echo -e "${DGN}Allocated Cores ${BGN}$var_cpu${CL}"
                CORE_COUNT="$var_cpu"
                echo -e "${DGN}Allocated Ram ${BGN}$var_ram${CL}"
                RAM_SIZE="$var_ram"
                echo -e "${DGN}Using Bridge: ${BGN}vmbr0${CL}"
                BRG="vmbr0"
                echo -e "${DGN}Using Static IP Address: ${BGN}dhcp${CL}"
                NET=dhcp
                echo -e "${DGN}Using Gateway Address: ${BGN}Default${CL}"
                GATE=""
                echo -e "${DGN}Using DNS Address: ${BGN}Default${CL}"
                DNS=""
                echo -e "${DGN}Using MAC Address: ${BGN}Default${CL}"
                MAC=""
    echo -e "${DGN}Using VLAN Tag: ${BGN}Default${CL}"
    VLAN=""
                echo -e "${BL}Creating a ${APP} LXC using the above default settings${CL}"
}
function advanced_settings() {
var_version=$(whiptail --title "UBUNTU VERSION" --radiolist "Choose Version" 10 58 3 \
"20.04" "Focal" OFF \
"22.04" "Jammy" ON \
3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then echo -e "${DGN}Using Ubuntu Version: ${BGN}$var_version${CL}"; fi
CT_TYPE=$(whiptail --title "CONTAINER TYPE" --radiolist --cancel-button Exit-Script "Choose Type" 8 58 2 \
"1" "Unprivileged" ON \
"0" "Privileged" OFF \
3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo -e "${DGN}Using Container Type: ${BGN}$CT_TYPE${CL}"
fi
PW1=$(whiptail --inputbox "Set Root Password" 8 58  --title "PASSWORD(leave blank for automatic login)" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
  if [ -z $PW1 ]; then PW1="Automatic Login" PW=" ";
    echo -e "${DGN}Using Root Password: ${BGN}$PW1${CL}"
else
    PW="-password $PW1"
    echo -e "${DGN}Using Root Password: ${BGN}$PW1${CL}"
  fi
fi
CT_ID=$(whiptail --inputbox "Set Container ID" 8 58 $NEXTID --title "CONTAINER ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
exitstatus=$?
if [ -z $CT_ID ]; then CT_ID="$NEXTID"; echo -e "${DGN}Container ID: ${BGN}$CT_ID${CL}";
else
  if [ $exitstatus = 0 ]; then echo -e "${DGN}Using Container ID: ${BGN}$CT_ID${CL}"; fi;
fi
CT_NAME=$(whiptail --inputbox "Set Hostname" 8 58 $NSAPP --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
exitstatus=$?
if [ -z $CT_NAME ]; then HN="$NSAPP"; echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}";
else
  if [ $exitstatus = 0 ]; then HN=$(echo ${CT_NAME,,} | tr -d ' '); echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"; fi;
fi
DISK_SIZE=$(whiptail --inputbox "Set Disk Size in GB" 8 58 $var_disk --title "DISK SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
exitstatus=$?
if [ -z $DISK_SIZE ]; then DISK_SIZE="$var_disk"; echo -e "${DGN}Using Disk Size: ${BGN}$DISK_SIZE${CL}";
else
  if [ $exitstatus = 0 ]; then echo -e "${DGN}Using Disk Size: ${BGN}$DISK_SIZE${CL}"; fi;
    if ! [[ $DISK_SIZE =~ $INTEGER ]] ; then echo -e "${RD}⚠ DISK SIZE MUST BE A INTEGER NUMBER!${CL}"; advanced_settings; fi;
fi
CORE_COUNT=$(whiptail --inputbox "Allocate CPU Cores" 8 58 $var_cpu --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
exitstatus=$?
if [ -z $CORE_COUNT ]; then CORE_COUNT="$var_cpu"; echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}";
else
  if [ $exitstatus = 0 ]; then echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"; fi;
fi
RAM_SIZE=$(whiptail --inputbox "Allocate RAM in MiB" 8 58 $var_ram --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
exitstatus=$?
if [ -z $RAM_SIZE ]; then RAM_SIZE="$var_ram"; echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}";
else
  if [ $exitstatus = 0 ]; then echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"; fi;
fi
BRG=$(whiptail --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
exitstatus=$?
if [ -z $BRG ]; then BRG="vmbr0"; echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}";
else
  if [ $exitstatus = 0 ]; then echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"; fi;
fi
NET=$(whiptail --inputbox "Set a Static IPv4 CIDR Address(/24)" 8 58 dhcp --title "IP ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
exitstatus=$?
if [ -z $NET ]; then NET="dhcp"; echo -e "${DGN}Using IP Address: ${BGN}$NET${CL}";
else
  if [ $exitstatus = 0 ]; then echo -e "${DGN}Using IP Address: ${BGN}$NET${CL}"; fi;
fi
GATE1=$(whiptail --inputbox "Set a Gateway IP (mandatory if Static IP was used)" 8 58  --title "GATEWAY IP" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
  if [ -z $GATE1 ]; then GATE1="Default" GATE="";
    echo -e "${DGN}Using Gateway IP Address: ${BGN}$GATE1${CL}"
else
    GATE=",gw=$GATE1"
    echo -e "${DGN}Using Gateway IP Address: ${BGN}$GATE1${CL}"
  fi
fi
DNS1=$(whiptail --inputbox "Set a DNS IP (leave blank for default)" 8 58  --title "DNS IP ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
  if [ -z $DNS1 ]; then DNS1="Default" DNS="";
    echo -e "${DGN}Using DNS IP Address: ${BGN}$DNS1${CL}"
else
    DNS="-nameserver $DNS1"
    echo -e "${DGN}Using DNS IP Address: ${BGN}$DNS1${CL}"
  fi
fi
MAC1=$(whiptail --inputbox "Set a MAC Address(leave blank for default)" 8 58  --title "MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
  if [ -z $MAC1 ]; then MAC1="Default" MAC="";
    echo -e "${DGN}Using MAC Address: ${BGN}$MAC1${CL}"
else
    MAC=",hwaddr=$MAC1"
    echo -e "${DGN}Using MAC Address: ${BGN}$MAC1${CL}"
  fi
fi
VLAN1=$(whiptail --inputbox "Set a Vlan(leave blank for default)" 8 58  --title "VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
  if [ -z $VLAN1 ]; then VLAN1="Default" VLAN="";
    echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
else
    VLAN=",tag=$VLAN1"
    echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
  fi  
fi

# Ask user which installation mode they want
if (whiptail --title "KODI INSTALLATION MODE" --yesno "Choose Kodi installation mode:\n\nYes = XFCE Desktop Environment\n       • Full desktop with XFCE\n       • Exit Kodi to desktop\n       • Browser, apps, volume control\n       • Best for general use\n\nNo  = Standalone Kodi Only\n       • Kodi on TTY7 (direct)\n       • Minimal system resources\n       • Best performance\n       • Media center only" 18 68); then
    INSTALL_MODE="xfce"
    echo -e "${GN}Selected: Kodi with XFCE Desktop Environment${CL}"
    
    # Password for kodi user
    KODI_PASS=$(whiptail --inputbox "Set password for kodi user:\n\n(Leave empty or cancel to use default password: kodi)" 10 58 --title "KODI USER PASSWORD" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus != 0 ] || [ -z "$KODI_PASS" ]; then
        KODI_PASS="kodi"
        echo -e "${YW}Using default password: kodi${CL}"
    else
        echo -e "${GN}Password set for kodi user${CL}"
    fi
    
    # Ask about audio configuration
    if (whiptail --title "AUDIO CONFIGURATION" --yesno "Would you like to configure audio device during installation?\n\nYes = Configure audio now (with device testing)\nNo  = Skip for now (use desktop shortcut later)" 12 58); then
        CONFIGURE_AUDIO="yes"
        echo -e "${GN}Will configure audio during installation${CL}"
    else
        CONFIGURE_AUDIO="no"
        echo -e "${YW}Audio configuration will be skipped${CL}"
    fi
    
    # Optional software selection - with validation loop
    while true; do
        APPS=$(whiptail --title "OPTIONAL SOFTWARE" --checklist \
            "Select applications to install:" 24 68 12 \
            "KODI_PPA"    "Kodi Media Center (PPA - v20.x)"    OFF \
            "KODI_FLATPAK" "Kodi Media Center (Flatpak - v21.x)" OFF \
            "FIREFOX"     "Firefox web browser"                OFF \
            "BRAVE"       "Brave web browser"                  OFF \
            "CHROME"      "Google Chrome"                      OFF \
            "LIBREOFFICE" "LibreOffice suite"                  OFF \
            "VLC"         "VLC Media Player"                   OFF \
            "GIMP"        "GIMP Image Editor"                  OFF \
            "STEAM"       "Steam gaming platform"              OFF \
            "MAME"        "MAME + AML Launcher (play ROMs in Kodi)" OFF \
            "RETROARCH"   "RetroArch multi-system emulator"    OFF \
            3>&1 1>&2 2>&3)
        
        # Validate: can't install both Kodi versions
        if [[ "$APPS" == *"KODI_PPA"* ]] && [[ "$APPS" == *"KODI_FLATPAK"* ]]; then
            whiptail --msgbox "Error: Cannot install both Kodi versions!\n\nPlease select only ONE:\n  • Kodi PPA (v20.x)\n  OR\n  • Kodi Flatpak (v21.x)\n\nClick OK to re-select applications." 14 58 --title "CONFLICT DETECTED"
            continue
        fi
        break
    done
    
    # Ask about autostart for Kodi if selected
    if [[ "$APPS" == *"KODI_PPA"* ]] || [[ "$APPS" == *"KODI_FLATPAK"* ]]; then
        if (whiptail --title "KODI AUTOSTART" --yesno "Start Kodi automatically on boot?" 8 58); then
            KODI_AUTOSTART="yes"
            echo -e "${GN}Kodi will autostart on boot${CL}"
        else
            KODI_AUTOSTART="no"
            echo -e "${YW}Kodi will not autostart (can launch manually)${CL}"
        fi
    else
        KODI_AUTOSTART="no"
    fi
    
    # Ask about autostart for Steam if selected
    if [[ "$APPS" == *"STEAM"* ]]; then
        if (whiptail --title "STEAM AUTOSTART" --yesno "Start Steam automatically on boot?" 8 58); then
            STEAM_AUTOSTART="yes"
            echo -e "${GN}Steam will autostart on boot${CL}"
        else
            STEAM_AUTOSTART="no"
            echo -e "${YW}Steam will not autostart (can launch manually)${CL}"
        fi
    else
        STEAM_AUTOSTART="no"
    fi
    
    # Export variables for xfce-install.sh
    export KODI_PASS
    export CONFIGURE_AUDIO
    export KODI_AUTOSTART
    export STEAM_AUTOSTART
    export INSTALL_APPS="$APPS"
else
    INSTALL_MODE="standalone"
    echo -e "${GN}Selected: Standalone Kodi${CL}"
    # Initialize xfce-only vars so save_settings() doesn't fail with nounset
    KODI_PASS=""
    CONFIGURE_AUDIO=""
    KODI_AUTOSTART=""
    STEAM_AUTOSTART=""
    INSTALL_APPS=""
fi

# Ask if user wants to save settings
if (whiptail --title "SAVE SETTINGS" --yesno "Would you like to save these settings for future use?\n\nSaved settings can be loaded next time you run this script." 10 58); then
    SAVE_SETTINGS=true
    echo -e "${GN}Settings will be saved after successful creation${CL}"
else
    SAVE_SETTINGS=false
fi

if (whiptail --title "ADVANCED SETTINGS COMPLETE" --yesno "Ready to create ${APP} LXC?" --no-button Do-Over 10 58); then
    echo -e "${RD}Creating a ${APP} LXC using the above advanced settings${CL}"
else
  clear
  header_info
  echo -e "${RD}Using Advanced Settings${CL}"
  advanced_settings
fi
}

function start_script() {
# Check if saved settings exist
if [ -f "$SETTINGS_FILE" ]; then
    if (whiptail --title "SAVED SETTINGS FOUND" --yesno "Previous settings found. Would you like to:\n\nYes = Load previous settings\nNo  = Start with fresh settings" 12 58); then
        load_settings
        show_saved_settings
        
        if (whiptail --title "USE SAVED SETTINGS?" --yesno "Use these saved settings?" 10 58); then
            echo -e "${GN}Using saved settings${CL}"
            CT_ID=$(pvesh get /cluster/nextid)
            echo -e "${DGN}Using Next Available Container ID: ${BGN}$CT_ID${CL}"
            
            # Set defaults for variables if they don't exist (old saved settings compatibility)
            KODI_PASS="${KODI_PASS:-kodi}"
            CONFIGURE_AUDIO="${CONFIGURE_AUDIO:-no}"
            KODI_AUTOSTART="${KODI_AUTOSTART:-yes}"
            STEAM_AUTOSTART="${STEAM_AUTOSTART:-yes}"
            
            # Export XFCE variables if in XFCE mode
            if [ "$INSTALL_MODE" = "xfce" ]; then
                export KODI_PASS
                export CONFIGURE_AUDIO
                export KODI_AUTOSTART
                export STEAM_AUTOSTART
                export INSTALL_APPS
            fi
            
            SAVE_SETTINGS=false
            return 0
        else
            echo -e "${YW}Starting fresh configuration...${CL}"
        fi
    fi
fi

if (whiptail --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced 10 58); then
  header_info
  echo -e "${BL}Using Default Settings${CL}"
  default_settings
  # Ask installation mode for default settings too
  if (whiptail --title "KODI INSTALLATION MODE" --yesno "Choose Kodi installation mode:\n\nYes = XFCE Desktop Environment\n       • Full desktop with XFCE\n       • Exit Kodi to desktop\n       • Browser, apps, volume control\n       • Best for general use\n\nNo  = Standalone Kodi Only\n       • Kodi on TTY7 (direct)\n       • Minimal system resources\n       • Best performance\n       • Media center only" 18 68); then
      INSTALL_MODE="xfce"
      echo -e "${GN}Selected: Kodi with XFCE Desktop Environment${CL}"
      
      # Password for kodi user
      KODI_PASS=$(whiptail --inputbox "Set password for kodi user:\n\n(Leave empty or cancel to use default password: kodi)" 10 58 --title "KODI USER PASSWORD" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus != 0 ] || [ -z "$KODI_PASS" ]; then
          KODI_PASS="kodi"
          echo -e "${YW}Using default password: kodi${CL}"
      else
          echo -e "${GN}Password set for kodi user${CL}"
      fi
      
      # Ask about audio configuration
      if (whiptail --title "AUDIO CONFIGURATION" --yesno "Would you like to configure audio device during installation?\n\nYes = Configure audio now (with device testing)\nNo  = Skip for now (use desktop shortcut later)" 12 58); then
          CONFIGURE_AUDIO="yes"
          echo -e "${GN}Will configure audio during installation${CL}"
      else
          CONFIGURE_AUDIO="no"
          echo -e "${YW}Audio configuration will be skipped${CL}"
      fi
      
      # Optional software selection - with validation loop
      while true; do
          APPS=$(whiptail --title "OPTIONAL SOFTWARE" --checklist \
              "Select applications to install:" 24 68 12 \
              "KODI_PPA"    "Kodi Media Center (PPA - v20.x)"    OFF \
              "KODI_FLATPAK" "Kodi Media Center (Flatpak - v21.x)" OFF \
              "FIREFOX"     "Firefox web browser"                OFF \
              "BRAVE"       "Brave web browser"                  OFF \
              "CHROME"      "Google Chrome"                      OFF \
              "LIBREOFFICE" "LibreOffice suite"                  OFF \
              "VLC"         "VLC Media Player"                   OFF \
              "GIMP"        "GIMP Image Editor"                  OFF \
              "STEAM"       "Steam gaming platform"              OFF \
              "MAME"        "MAME + AML Launcher (play ROMs in Kodi)" OFF \
              "RETROARCH"   "RetroArch multi-system emulator"    OFF \
              3>&1 1>&2 2>&3)
          
          # Validate: can't install both Kodi versions
          if [[ "$APPS" == *"KODI_PPA"* ]] && [[ "$APPS" == *"KODI_FLATPAK"* ]]; then
              whiptail --msgbox "Error: Cannot install both Kodi versions!\n\nPlease select only ONE:\n  • Kodi PPA (v20.x)\n  OR\n  • Kodi Flatpak (v21.x)\n\nClick OK to re-select applications." 14 58 --title "CONFLICT DETECTED"
              continue
          fi
          break
      done
      
      # Ask about autostart for Kodi if selected
      if [[ "$APPS" == *"KODI_PPA"* ]] || [[ "$APPS" == *"KODI_FLATPAK"* ]]; then
          if (whiptail --title "KODI AUTOSTART" --yesno "Start Kodi automatically on boot?" 8 58); then
              KODI_AUTOSTART="yes"
              echo -e "${GN}Kodi will autostart on boot${CL}"
          else
              KODI_AUTOSTART="no"
              echo -e "${YW}Kodi will not autostart (can launch manually)${CL}"
          fi
      else
          KODI_AUTOSTART="no"
      fi
      
      # Ask about autostart for Steam if selected
      if [[ "$APPS" == *"STEAM"* ]]; then
          if (whiptail --title "STEAM AUTOSTART" --yesno "Start Steam automatically on boot?" 8 58); then
              STEAM_AUTOSTART="yes"
              echo -e "${GN}Steam will autostart on boot${CL}"
          else
              STEAM_AUTOSTART="no"
              echo -e "${YW}Steam will not autostart (can launch manually)${CL}"
          fi
      else
          STEAM_AUTOSTART="no"
      fi
      
      # Export variables for xfce-install.sh
      export KODI_PASS
      export CONFIGURE_AUDIO
      export KODI_AUTOSTART
      export STEAM_AUTOSTART
      export INSTALL_APPS="$APPS"
  else
      INSTALL_MODE="standalone"
      echo -e "${GN}Selected: Standalone Kodi${CL}"
      # Initialize xfce-only vars so save_settings() doesn't fail with nounset
      KODI_PASS=""
      CONFIGURE_AUDIO=""
      KODI_AUTOSTART=""
      STEAM_AUTOSTART=""
      INSTALL_APPS=""
  fi
  
  # Ask if user wants to save settings
  if (whiptail --title "SAVE SETTINGS" --yesno "Would you like to save these settings for future use?\n\nSaved settings can be loaded next time you run this script." 10 58); then
      SAVE_SETTINGS=true
      echo -e "${GN}Settings will be saved after successful creation${CL}"
  else
      SAVE_SETTINGS=false
  fi
else
  header_info
  echo -e "${RD}Using Advanced Settings${CL}"
  advanced_settings
fi
}
clear
start_script
if [ "$CT_TYPE" == "1" ]; then 
 FEATURES="nesting=1,keyctl=1"
 else
 FEATURES="nesting=1"
 fi
TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null
export CTID=$CT_ID
export PCT_OSTYPE=$var_os
export PCT_OSVERSION=$var_version
export PCT_DISK_SIZE=$DISK_SIZE
export PCT_OPTIONS="
  -features $FEATURES
  -hostname $HN
  -net0 name=eth0,bridge=$BRG$MAC,ip=$NET$GATE$VLAN
  -onboot 1
  -cores $CORE_COUNT
  -memory $RAM_SIZE
  -unprivileged $CT_TYPE
  $PW
  $DNS
"
bash -c "$(wget -qLO - https://raw.githubusercontent.com/tteck/Proxmox/main/ct/create_lxc.sh)" || exit

msg_info "Pre-starting LXC Container"
pct start $CTID
msg_ok "Pre-started LXC Container"

VIDEO_GID=$(pct exec ${CTID} getent group video | cut -d: -f3)
RENDER_GID=$(pct exec ${CTID} getent group render | cut -d: -f3)
TTY_GID=$(pct exec ${CTID} getent group tty | cut -d: -f3)
INPUT_GID=$(pct exec ${CTID} getent group input | cut -d: -f3)
AUDIO_GID=$(pct exec ${CTID} getent group audio | cut -d: -f3)

msg_info "Stopping LXC Container"
pct stop $CTID
msg_ok "Stopped LXC Container"

LXC_CONFIG=/etc/pve/lxc/${CTID}.conf
cat <<EOF >> $LXC_CONFIG
dev0: /dev/fuse
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.cgroup2.devices.allow: c 29:0 rwm
lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/dri/renderD128 dev/renderD128 none bind,optional,create=file
# tty 7 - default for x
lxc.cgroup2.devices.allow: c 4:7 rwm
lxc.mount.entry: /dev/tty7 dev/tty7 none bind,optional,create=file
# all input devices
lxc.cgroup2.devices.allow: c 13:* rwm
lxc.mount.entry: /dev/input dev/input none bind,optional,create=dir
# sound 
lxc.cgroup2.devices.allow: c 116:* rwm
lxc.mount.entry: /dev/snd dev/snd none bind,optional,create=dir
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.cgroup2.devices.allow: c 188:* rwm
lxc.cgroup2.devices.allow: c 10:200 rwm
EOF
if [ "$CT_TYPE" == "1" ]; then
    cat <<EOF >> $LXC_CONFIG
lxc.idmap: u 0 100000 65536
EOF
    LXC_SUB_CONF=$(python3 -c "$(wget -qLO - https://raw.githubusercontent.com/ddimick/proxmox-lxc-idmapper/master/run.py)" \
      ${VIDEO_GID}=$(getent group video | cut -d: -f3) ${RENDER_GID}=$(getent group render | cut -d: -f3) ${TTY_GID}=$(getent group tty | cut -d: -f3) ${INPUT_GID}=$(getent group input | cut -d: -f3) ${AUDIO_GID}=$(getent group audio | cut -d: -f3)) 
    echo "$LXC_SUB_CONF" | grep 'lxc.idmap: g ' >> $LXC_CONFIG
    echo "$LXC_SUB_CONF" | sed -n '/subgid/,// { /subgid/! p }' | while read line; do cat /etc/subgid | sed 's/[[:blank:]]*//g' | grep -qxF "$line" || echo $line >> /etc/subgid; done
    /usr/bin/systemctl restart lxc
else
    cat <<EOF >> $LXC_CONFIG
lxc.hook.mount: sh -c "/var/lib/lxc/${CTID}/mount_hook.sh"
EOF
    cat <<EOF >/var/lib/lxc/${CTID}/mount_hook.sh
#!/usr/bin/env bash

/bin/chown :${VIDEO_GID} /dev/fb0
/bin/chmod 660 /dev/fb0
/bin/chown :${VIDEO_GID} /dev/dri
/bin/chmod 755 /dev/dri
/bin/chown :${VIDEO_GID} /dev/dri/*
/bin/chmod 660 /dev/dri/*
/bin/chown :${RENDER_GID} /dev/renderD128
/bin/chmod 660 /dev/renderD128
/bin/chown :${TTY_GID} /dev/tty7
/bin/chown :${INPUT_GID} /dev/input/*
/bin/chown :${AUDIO_GID} /dev/snd/*
EOF
    /bin/chmod +x /var/lib/lxc/${CTID}/mount_hook.sh
fi

msg_info "Starting LXC Container"
pct start $CTID
msg_ok "Started LXC Container"

# Run the appropriate installation script based on earlier selection
if [ "$INSTALL_MODE" = "xfce" ]; then
    lxc-attach -n $CTID -- bash -c "export KODI_PASS='$KODI_PASS' CONFIGURE_AUDIO='$CONFIGURE_AUDIO' KODI_AUTOSTART='$KODI_AUTOSTART' STEAM_AUTOSTART='$STEAM_AUTOSTART' INSTALL_APPS='$INSTALL_APPS'; $(wget -qLO - https://raw.githubusercontent.com/kjames2001/proxmoxHelper/dev/setup/xfce-install.sh)" || exit
    SUCCESS_MSG="XFCE Desktop installed successfully!"
    # Read any app failures written by xfce-install.sh and build accurate summary
    FAILED_LIST=$(pct exec $CTID -- cat /tmp/kodi-install-failures.txt 2>/dev/null || true)
    if [ -n "$FAILED_LIST" ]; then
        FAILED_FORMATTED=$(echo "$FAILED_LIST" | paste -sd ', ')
        ADDITIONAL_INFO="• Custom desktop environment\n• Some apps failed to install: ${FAILED_FORMATTED}\n• Audio configuration desktop shortcut available"
    else
        ADDITIONAL_INFO="• Custom desktop environment\n• All selected applications installed\n• Audio configuration desktop shortcut available"
    fi
else
    lxc-attach -n $CTID -- bash -c "$(wget -qLO - https://raw.githubusercontent.com/kjames2001/proxmoxHelper/dev/setup/$var_install.sh)" || exit
    SUCCESS_MSG="Standalone Kodi installed successfully!"
    ADDITIONAL_INFO="• Kodi runs directly on TTY7\n• Minimal overhead for best performance"
fi

IP=$(pct exec $CTID ip a s dev eth0 | sed -n '/inet / s/\// /p' | awk '{print $2}')
pct set $CTID -description "# ${APP} LXC - ${INSTALL_MODE} mode"

# Save settings if user requested it
if [ "$SAVE_SETTINGS" = true ]; then
    save_settings
fi

msg_ok "Completed Successfully!\n"

echo -e "\n${GN}╔════════════════════════════════════════════════╗${CL}"
echo -e "${GN}║        Kodi LXC Setup Complete!                ║${CL}"
echo -e "${GN}╚════════════════════════════════════════════════╝${CL}\n"
echo -e "${SUCCESS_MSG}"
echo -e "\n${BL}Container Details:${CL}"
echo -e "  • Container ID: ${GN}$CTID${CL}"
echo -e "  • IP Address: ${GN}$IP${CL}"
echo -e "  • Installation Mode: ${GN}$INSTALL_MODE${CL}"
echo -e "\n${BL}Features:${CL}"
echo -e "$ADDITIONAL_INFO"
echo -e "\n"
