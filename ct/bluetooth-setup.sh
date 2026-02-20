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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RD}Please run as root (use sudo)${CL}"
    exit 1
fi

echo -e "${GN}╔═══════════════════════════════════════════════╗${CL}"
echo -e "${GN}║   Bluetooth Device Pairing Setup Script      ║${CL}"
echo -e "${GN}╚═══════════════════════════════════════════════╝${CL}"
echo ""

# Check if bluetooth is installed
if ! command -v bluetoothctl &> /dev/null; then
    msg_info "Installing Bluetooth packages"
    apt-get update &>/dev/null
    apt-get install -y bluez bluetooth &>/dev/null
    msg_ok "Installed Bluetooth packages"
fi

# Start bluetooth service
msg_info "Starting Bluetooth service"
systemctl start bluetooth
systemctl enable bluetooth &>/dev/null
msg_ok "Bluetooth service started"

# Check if bluetooth is available
if ! hciconfig hci0 &>/dev/null; then
    msg_error "No Bluetooth adapter found!"
    echo -e "${YW}Please ensure:"
    echo -e "  1. Bluetooth hardware is present"
    echo -e "  2. Bluetooth module is loaded"
    echo -e "  3. Adapter is not blocked (check with 'rfkill list')${CL}"
    exit 1
fi

msg_ok "Bluetooth adapter detected"

echo -e "\n${GN}=== Bluetooth Setup ===${CL}"
echo -e "This script will help you pair Bluetooth devices."
echo -e "Supported device types:"
echo -e "  • Keyboards"
echo -e "  • Mice"
echo -e "  • Game controllers/gamepads"
echo -e "  • Headphones/speakers"
echo -e "  • Other HID devices"
echo ""

# Power on the adapter
msg_info "Powering on Bluetooth adapter"
echo "power on" | bluetoothctl &>/dev/null
sleep 2
msg_ok "Adapter powered on"

# Enable agent
msg_info "Enabling pairing agent"
echo "agent on" | bluetoothctl &>/dev/null
echo "default-agent" | bluetoothctl &>/dev/null
msg_ok "Agent enabled"

echo -e "\n${YW}Instructions:${CL}"
echo -e "  1. Put your Bluetooth device in ${GN}pairing mode${CL}"
echo -e "  2. Wait for it to appear in the scan results"
echo -e "  3. Note the device's MAC address"
echo -e ""
echo -e "${YW}Common pairing mode methods:${CL}"
echo -e "  • Hold power button for 5-10 seconds"
echo -e "  • Press dedicated pairing button"
echo -e "  • Hold specific button combination"
echo -e ""

read -p "Press Enter when your device is in pairing mode..." dummy

msg_info "Scanning for devices (15 seconds)"
echo ""
echo -e "${GN}╔════════════════════════════════════════════════════════════╗${CL}"
echo -e "${GN}║                  Scanning for devices...                  ║${CL}"
echo -e "${GN}╚════════════════════════════════════════════════════════════╝${CL}"

# Start scanning and capture output
{
    echo "scan on"
    sleep 15
    echo "scan off"
} | bluetoothctl > /tmp/bt_scan.log 2>&1 &

# Show progress
for i in {1..15}; do
    echo -ne "\r${YW}Scanning... ${i}/15 seconds${CL}"
    sleep 1
done
echo ""

wait

# Parse discovered devices
echo -e "\n${GN}Discovered devices:${CL}\n"
grep "Device" /tmp/bt_scan.log | grep -v "not available" | awk '{print $2, $3, $4, $5, $6, $7, $8, $9}' | sort -u | nl -w2 -s". "

DEVICE_COUNT=$(grep "Device" /tmp/bt_scan.log | grep -v "not available" | awk '{print $2}' | sort -u | wc -l)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    msg_error "No devices found"
    echo -e "${YW}Troubleshooting tips:${CL}"
    echo -e "  • Ensure device is in pairing mode"
    echo -e "  • Check device battery"
    echo -e "  • Move device closer to computer"
    echo -e "  • Try restarting Bluetooth: ${BL}systemctl restart bluetooth${CL}"
    rm /tmp/bt_scan.log
    exit 1
fi

echo ""
echo -e "${YW}Enter the number of the device you want to pair (or MAC address):${CL}"
read -p "Selection: " SELECTION

# Check if input is a number (device from list) or MAC address
if [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
    # It's a number - get MAC from list
    MAC_ADDRESS=$(grep "Device" /tmp/bt_scan.log | grep -v "not available" | awk '{print $2}' | sort -u | sed -n "${SELECTION}p")
else
    # Assume it's a MAC address
    MAC_ADDRESS="$SELECTION"
fi

if [ -z "$MAC_ADDRESS" ]; then
    msg_error "Invalid selection"
    rm /tmp/bt_scan.log
    exit 1
fi

# Get device name for confirmation
DEVICE_NAME=$(grep "$MAC_ADDRESS" /tmp/bt_scan.log | awk '{$1=$2=""; print $0}' | sed 's/^[ \t]*//' | head -1)

echo ""
echo -e "${GN}Selected device:${CL}"
echo -e "  MAC: ${BL}$MAC_ADDRESS${CL}"
echo -e "  Name: ${BL}$DEVICE_NAME${CL}"
echo ""

read -p "Proceed with pairing? (y/n): " -n 1 -r CONFIRM
echo ""

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo -e "${YW}Pairing cancelled${CL}"
    rm /tmp/bt_scan.log
    exit 0
fi

# Pair the device
msg_info "Pairing with device"
echo "pair $MAC_ADDRESS" | bluetoothctl &>/tmp/bt_pair.log

# Check for PIN/passkey request
if grep -qi "PIN\|passkey\|confirm" /tmp/bt_pair.log; then
    echo -e "\n${YW}Device requires PIN/passkey${CL}"
    grep -i "PIN\|passkey\|confirm" /tmp/bt_pair.log | tail -1
    read -p "Enter PIN (if needed, or press Enter to skip): " PIN
    if [ -n "$PIN" ]; then
        echo "$PIN" | bluetoothctl &>/dev/null
    fi
fi

sleep 3

if grep -qi "pairing successful\|paired: yes" /tmp/bt_pair.log; then
    msg_ok "Device paired successfully"
else
    msg_error "Pairing failed"
    echo -e "${YW}Debug info:${CL}"
    tail -5 /tmp/bt_pair.log
    rm /tmp/bt_scan.log /tmp/bt_pair.log
    exit 1
fi

# Trust the device
msg_info "Trusting device for auto-reconnect"
echo "trust $MAC_ADDRESS" | bluetoothctl &>/dev/null
sleep 1
msg_ok "Device trusted"

# Connect the device
msg_info "Connecting to device"
echo "connect $MAC_ADDRESS" | bluetoothctl &>/tmp/bt_connect.log
sleep 3

if grep -qi "connection successful\|connected: yes" /tmp/bt_connect.log; then
    msg_ok "Device connected"
else
    echo -e "${YW}Connection pending - device may connect automatically${CL}"
fi

# Show final status
echo ""
echo -e "${GN}═══════════════════════════════════════════════${CL}"
echo -e "${GN}             Pairing Complete!                 ${CL}"
echo -e "${GN}═══════════════════════════════════════════════${CL}"
echo ""
echo -e "${GN}Device Information:${CL}"
echo "info $MAC_ADDRESS" | bluetoothctl | grep -E "Name:|Paired:|Trusted:|Connected:"

echo ""
echo -e "${GN}Next steps:${CL}"
echo -e "  • Device should reconnect automatically on next boot"
echo -e "  • If using in LXC, device should be accessible inside container"
echo -e "  • For gamepad/controller, test in Kodi or your preferred app"
echo ""

read -p "Would you like to pair another device? (y/n): " -n 1 -r ANOTHER
echo ""

if [[ $ANOTHER =~ ^[Yy]$ ]]; then
    # Clean up and restart
    rm /tmp/bt_scan.log /tmp/bt_pair.log /tmp/bt_connect.log
    exec "$0" "$@"
fi

# Clean up
rm -f /tmp/bt_scan.log /tmp/bt_pair.log /tmp/bt_connect.log

echo -e "\n${GN}Bluetooth setup complete!${CL}"
echo -e "You can manage devices later with: ${BL}bluetoothctl${CL}"
echo ""
echo -e "${YW}Common bluetoothctl commands:${CL}"
echo -e "  • ${BL}devices${CL} - List paired devices"
echo -e "  • ${BL}info <MAC>${CL} - Show device info"
echo -e "  • ${BL}connect <MAC>${CL} - Connect to device"
echo -e "  • ${BL}disconnect <MAC>${CL} - Disconnect device"
echo -e "  • ${BL}remove <MAC>${CL} - Unpair device"
echo ""
