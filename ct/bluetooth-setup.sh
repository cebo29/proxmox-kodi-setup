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

# Print header
echo "╔═══════════════════════════════════════════════╗"
echo "║   Bluetooth Device Pairing Setup Script      ║"
echo "╚═══════════════════════════════════════════════╝"

# Check if bluetooth service is running
if ! systemctl is-active --quiet bluetooth; then
    msg_info "Starting Bluetooth service"
    systemctl start bluetooth
    sleep 2
    msg_ok "Bluetooth service started"
else
    msg_ok "Bluetooth service started"
fi

# Check if bluetooth adapter exists
if ! hciconfig hci0 > /dev/null 2>&1; then
    msg_error "No Bluetooth adapter found!"
    echo "Please ensure:"
    echo "  1. Bluetooth hardware is present"
    echo "  2. Bluetooth drivers are loaded"
    echo "  3. Device is not blocked (check 'rfkill list')"
    exit 1
fi

msg_ok "Bluetooth adapter detected"

# Information for user
echo ""
echo "${GN}=== Bluetooth Setup ===${CL}"
echo "This script will help you pair Bluetooth devices."
echo ""
echo "Supported device types:"
echo "  • Keyboards"
echo "  • Mice"
echo "  • Game controllers/gamepads"
echo "  • Headphones/speakers"
echo "  • Other HID devices"
echo ""

# Power on adapter
msg_info "Powering on adapter"
echo "power on" | bluetoothctl > /dev/null 2>&1
sleep 1
msg_ok "Adapter powered on"

# Enable agent
msg_info "Enabling agent"
echo "agent on" | bluetoothctl > /dev/null 2>&1
echo "default-agent" | bluetoothctl > /dev/null 2>&1
msg_ok "Agent enabled"

# Pairing instructions
echo ""
echo "${YW}Instructions:${CL}"
echo "  1. Put your Bluetooth device in pairing mode"
echo "  2. Wait for it to appear in the scan results"
echo "  3. Select the device by entering its number"
echo ""
echo "Common pairing mode methods:"
echo "  • Hold power button for 5-10 seconds"
echo "  • Press dedicated pairing button"
echo "  • Hold specific button combination"
echo ""
read -p "Press Enter when your device is in pairing mode..."

# Scan for devices
SCAN_TIME=15
msg_info "Scanning for devices ($SCAN_TIME seconds)"

# Start scan and capture output
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                  Scanning for devices...                  ║"
echo "╚════════════════════════════════════════════════════════════╝"

# Start bluetoothctl scan in background
rm -f /tmp/bt_scan.log
(
    echo "scan on"
    sleep $SCAN_TIME
    echo "scan off"
) | bluetoothctl > /tmp/bt_scan.log 2>&1 &

SCAN_PID=$!

# Show progress
for i in $(seq 1 $SCAN_TIME); do
    echo -ne "\rScanning... $i/$SCAN_TIME seconds"
    sleep 1
done
echo ""

# Wait for scan to complete
wait $SCAN_PID

msg_ok "Scan complete"

# Debug: Show raw scan output
echo ""
echo "${YW}Debug: Raw scan output:${CL}"
cat /tmp/bt_scan.log
echo ""
echo "${YW}Debug: Filtering for devices:${CL}"
grep "Device" /tmp/bt_scan.log || echo "No devices found in log"
echo ""

# Parse discovered devices
echo ""
echo "Discovered devices:"
echo ""

DEVICE_LIST=()
DEVICE_COUNT=0

while IFS= read -r line; do
    # Match lines like: "[NEW] Device E4:17:D8:16:B3:33 8BitDo Micro gamepad"
    if [[ $line =~ Device\ ([0-9A-Fa-f:]+)\ (.+)$ ]]; then
        MAC="${BASH_REMATCH[1]}"
        NAME="${BASH_REMATCH[2]}"
        # Clean up the name (remove trailing spaces)
        NAME=$(echo "$NAME" | sed 's/[[:space:]]*$//')
        ((DEVICE_COUNT++))
        DEVICE_LIST+=("$MAC|$NAME")
        echo "  ${GN}$DEVICE_COUNT)${CL} $NAME"
        echo "     ${BL}MAC: $MAC${CL}"
        echo ""
    fi
done < <(grep "Device" /tmp/bt_scan.log)

if [ $DEVICE_COUNT -eq 0 ]; then
    msg_error "No devices found"
    echo ""
    echo "Troubleshooting:"
    echo "  • Make sure the device is in pairing mode"
    echo "  • Try moving the device closer"
    echo "  • Check if the device is already paired (unpair first)"
    echo "  • Some devices need to be unpaired from other hosts first"
    exit 1
fi

# Get user selection
echo "Enter device number (1-$DEVICE_COUNT) or MAC address:"
read -p "Selection: " SELECTION

# Validate and get device info
DEVICE_MAC=""
DEVICE_NAME=""

if [[ $SELECTION =~ ^[0-9]+$ ]] && [ $SELECTION -ge 1 ] && [ $SELECTION -le $DEVICE_COUNT ]; then
    # Valid number - get device from array (subtract 1 for 0-based index)
    DEVICE_INFO="${DEVICE_LIST[$((SELECTION-1))]}"
    DEVICE_MAC="${DEVICE_INFO%%|*}"
    DEVICE_NAME="${DEVICE_INFO#*|}"
elif [[ $SELECTION =~ ^[0-9A-Fa-f:]+$ ]]; then
    # Looks like a MAC address
    DEVICE_MAC="$SELECTION"
    # Try to find name in list
    for item in "${DEVICE_LIST[@]}"; do
        if [[ $item == $DEVICE_MAC\|* ]]; then
            DEVICE_NAME="${item#*|}"
            break
        fi
    done
    if [ -z "$DEVICE_NAME" ]; then
        DEVICE_NAME="Unknown Device"
    fi
else
    msg_error "Invalid selection"
    exit 1
fi

# Confirm selection
echo ""
echo "Selected device:"
echo "  Name: $DEVICE_NAME"
echo "  MAC: $DEVICE_MAC"
echo ""
read -p "Proceed with pairing? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Pairing cancelled."
    exit 0
fi

# Remove device if already paired
msg_info "Removing existing pairing (if any)"
echo "remove $DEVICE_MAC" | bluetoothctl > /dev/null 2>&1
sleep 1
msg_ok "Ready to pair"

# Pair the device
msg_info "Pairing with device"
echo ""
echo "${YW}Note: Some devices may require you to:${CL}"
echo "  • Confirm pairing on the device"
echo "  • Enter a PIN code"
echo "  • Press a specific button"
echo ""

# Create expect-like script for pairing
PAIR_OUTPUT=$(cat <<EOF | bluetoothctl 2>&1
pair $DEVICE_MAC
quit
EOF
)

if echo "$PAIR_OUTPUT" | grep -q "Pairing successful\|AlreadyExists"; then
    msg_ok "Paired successfully"
    
    # Trust the device
    msg_info "Trusting device"
    echo "trust $DEVICE_MAC" | bluetoothctl > /dev/null 2>&1
    sleep 1
    msg_ok "Device trusted"
    
    # Connect to the device
    msg_info "Connecting to device"
    CONNECT_OUTPUT=$(echo "connect $DEVICE_MAC" | bluetoothctl 2>&1)
    
    if echo "$CONNECT_OUTPUT" | grep -q "Connection successful\|AlreadyConnected"; then
        msg_ok "Connected successfully"
        echo ""
        echo "${GN}╔════════════════════════════════════════════════╗${CL}"
        echo "${GN}║          Pairing Complete!                     ║${CL}"
        echo "${GN}╚════════════════════════════════════════════════╝${CL}"
        echo ""
        echo "Device: $DEVICE_NAME"
        echo "MAC: $DEVICE_MAC"
        echo "Status: ${GN}Paired, Trusted, and Connected${CL}"
        echo ""
        echo "Your device should now be ready to use!"
        echo "It will automatically connect when powered on."
    else
        msg_error "Connection failed"
        echo ""
        echo "${YW}Device is paired but not connected.${CL}"
        echo "You may need to:"
        echo "  • Power cycle the device"
        echo "  • Manually connect from Bluetooth settings"
        echo "  • Check if the device is in range"
        echo ""
        echo "Debug info:"
        echo "$CONNECT_OUTPUT"
    fi
else
    msg_error "Pairing failed"
    echo ""
    echo "Common reasons for pairing failure:"
    echo "  • Device not in pairing mode"
    echo "  • Device too far away (weak signal)"
    echo "  • Device already paired with another host"
    echo "  • PIN/passkey required but not entered"
    echo "  • Device battery too low"
    echo ""
    echo "Debug info:"
    echo "$PAIR_OUTPUT"
    echo ""
    echo "Try again with these steps:"
    echo "  1. Reset the device (check manual)"
    echo "  2. Unpair from other devices first"
    echo "  3. Ensure device is in pairing mode"
    echo "  4. Run this script again"
    exit 1
fi

# Show paired devices
echo ""
echo "${GN}All paired devices:${CL}"
bluetoothctl devices Paired

# Cleanup
rm -f /tmp/bt_scan.log

echo ""
echo "Done! You can now use your Bluetooth device."
