#!/bin/bash
# Title:       AWUS036ACM Setup
# Author:      FusedStamen
# Version:     1.0
# Category:    General
# Description: Sets up the Alfa AWUS036ACM (MT7612U) external WiFi adapter
#              for use with StamenScan, wardrive payloads, or passive capture.
#              Supports channel hopping modes for 2.4GHz and 5GHz.

MTK_PID="0e8d:7612"
IFACE="wlan2"
MON_IFACE="wlan2mon"
HOP_PID_FILE="/tmp/awus_hop.pid"

# 2.4GHz channel sets
CHANNELS_FLOCK="1 6 11"
CHANNELS_FULL_24="1 2 3 4 5 6 7 8 9 10 11 12 13"
CHANNELS_5GHZ="36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 149 153 157 161 165"

# ---- HELPERS ----

stop_hopper() {
    if [ -f "$HOP_PID_FILE" ]; then
        local pid
        pid=$(cat "$HOP_PID_FILE")
        kill "$pid" 2>/dev/null
        rm -f "$HOP_PID_FILE"
    fi
}

start_hopper() {
    local channels="$1"
    local dwell="${2:-350}"  # ms dwell per channel
    stop_hopper
    (
        while true; do
            for ch in $channels; do
                iw dev "$MON_IFACE" set channel "$ch" 2>/dev/null
                sleep "$(echo "scale=3; $dwell/1000" | awk '{printf "%.3f", $1}')"
            done
        done
    ) &
    echo $! > "$HOP_PID_FILE"
    disown $!
}

check_adapter() {
    lsusb | grep -q "$MTK_PID"
}

bring_up_monitor() {
    # Remove existing if present
    ip link set "$MON_IFACE" down 2>/dev/null
    iw dev "$MON_IFACE" del 2>/dev/null
    sleep 0.5

    # Find phy for the external adapter
    local phy=""
    for p in /sys/kernel/debug/ieee80211/phy*/; do
        [ -d "$p" ] || continue
        local pname
        pname=$(basename "$p")
        # Check if this phy belongs to MT7612U by checking MAC
        local mac
        mac=$(cat "/sys/class/ieee80211/${pname}/macaddress" 2>/dev/null)
        # Internal Pager radios use 00:13:37 OUI — skip them
        if ! echo "$mac" | grep -q "^00:13:37"; then
            phy="$pname"
            break
        fi
    done

    if [ -z "$phy" ]; then
        # Fallback — try phy2
        phy="phy2"
    fi

    iw phy "$phy" interface add "$MON_IFACE" type monitor 2>/dev/null
    if [ $? -ne 0 ]; then
        LOG red "Failed to create $MON_IFACE on $phy"
        return 1
    fi
    ip link set "$MON_IFACE" up 2>/dev/null
    return 0
}

cleanup_adapter() {
    stop_hopper
    ip link set "$MON_IFACE" down 2>/dev/null
    iw dev "$MON_IFACE" del 2>/dev/null
    LOG green "AWUS036ACM disabled and cleaned up."
}

# ---- INIT ----

LED SETUP
LOG ""
LOG cyan "╔══════════════════════════════╗"
LOG cyan "║    AWUS036ACM Setup v1.0     ║"
LOG cyan "║   Alfa MT7612U Controller    ║"
LOG cyan "╚══════════════════════════════╝"
LOG ""

# Check adapter present
if ! check_adapter; then
    LOG red "AWUS036ACM not detected."
    LOG red "Plug in adapter and try again."
    LED FAIL
    exit 1
fi

LOG green "AWUS036ACM detected (MT7612U)"
LOG ""

# Check if already running
if [ -f "$HOP_PID_FILE" ] && kill -0 "$(cat "$HOP_PID_FILE")" 2>/dev/null; then
    LOG yellow "Channel hopper already running (PID $(cat $HOP_PID_FILE))"
    LOG yellow "Current interface: $MON_IFACE"
    LOG ""
fi

# ---- MODE SELECTION ----

LOG cyan "Select adapter mode:"
LOG ""

MODE=$(LIST_PICKER "Wardrive Hop 1/6/11" "Wardrive Full Hop 1-13" "Wardrive 5GHz" "Passive ch6 (StamenScan)" "Disable / Cleanup")

case $? in "$DUCKYSCRIPT_CANCELLED"|"$DUCKYSCRIPT_REJECTED"|"$DUCKYSCRIPT_ERROR")
    LOG red "Cancelled"; exit 0 ;; esac

case "$MODE" in
    "Wardrive Hop 1/6/11")
        LOG cyan "Mode: Wardrive Hop 1/6/11"
        DWELL=350
        CHANNELS="$CHANNELS_FLOCK"
        ;;
    "Wardrive Full Hop 1-13")
        LOG cyan "Mode: Wardrive Full Hop 1-13"
        DWELL=500
        CHANNELS="$CHANNELS_FULL_24"
        ;;
    "Wardrive 5GHz")
        LOG cyan "Mode: Wardrive 5GHz"
        DWELL=400
        CHANNELS="$CHANNELS_5GHZ"
        ;;
    "Passive ch6 (StamenScan)")
        LOG cyan "Mode: Passive ch6"
        DWELL=0
        CHANNELS="6"
        ;;
    "Disable / Cleanup")
        cleanup_adapter
        LED SETUP
        exit 0
        ;;
    *)
        LOG "Exiting."
        exit 0
        ;;
esac

# ---- SETUP ----

LOG ""
LOG cyan "Bringing up $MON_IFACE..."

if ! bring_up_monitor; then
    LOG red "Failed to bring up monitor interface."
    LED FAIL
    exit 1
fi

LOG green "$MON_IFACE ready"

if [ "$MODE" -eq 4 ]; then
    # Fixed channel — no hopper
    iw dev "$MON_IFACE" set channel 6 2>/dev/null
    LOG green "Fixed channel 6 — ready for StamenScan"
else
    # Start channel hopper
    start_hopper "$CHANNELS" "$DWELL"
    LOG green "Channel hopper started (PID $(cat $HOP_PID_FILE))"
    LOG green "Dwell: ${DWELL}ms per channel"
fi

LOG ""
LOG green "AWUS036ACM active on $MON_IFACE"
LOG ""

# Show active channel info
iw dev "$MON_IFACE" info 2>/dev/null | grep -E "channel|type" | while read -r line; do
    LOG "$line"
done

LOG ""
LOG cyan "Run your payload — adapter will stay active."
LOG cyan "Run this payload again → option 5 to disable."
LOG ""

LED FINISH
