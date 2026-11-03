#!/usr/bin/env bash
# Keep a Bluetooth speaker connected: every 20 s, if it's paired but not connected, reconnect it.
# The Echo can only hold one connection; if another device has it, the attempt just fails quietly
# and the next round tries again. Started by ~/.config/systemd/user/echo-keepalive.service.
MAC="${1:-6C:0C:9A:39:B4:0D}"   # Echo Dot-2JS (Bluetooth address; B3:77 is a different address)
while true; do
    if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' &&
       bluetoothctl info "$MAC" 2>/dev/null | grep -q 'Paired: yes' &&
       ! bluetoothctl info "$MAC" 2>/dev/null | grep -q 'Connected: yes'; then
        timeout 15 bluetoothctl connect "$MAC" >/dev/null 2>&1 && echo "reconnected $MAC"
    fi
    sleep 20
done
