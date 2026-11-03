#!/usr/bin/env bash
# Keep a Bluetooth speaker connected AND usable as an audio output.
# Every 10 s:
#  - not connected                      -> connect it
#  - connected but no audio output (sink) -> the link is half-dead: disconnect and reconnect
# bluetoothctl often prints "Failed to connect" even when the connection goes through, so the
# result is judged by the device's state afterwards, not by the command's exit code.
# The Echo can only hold one connection; if another device has it, the next round tries again.
MAC="${1:-6C:0C:9A:39:B4:0D}"   # Echo Dot-2JS (Bluetooth address; B3:77 is its Wi-Fi address)
SINK="bluez_output.${MAC//:/_}"

connected() { bluetoothctl info "$MAC" 2>/dev/null | grep -q 'Connected: yes'; }
has_sink()  { pactl list sinks short 2>/dev/null | grep -q "$SINK"; }

while true; do
    if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' &&
       bluetoothctl info "$MAC" 2>/dev/null | grep -q 'Paired: yes'; then
        if ! connected; then
            timeout 15 bluetoothctl connect "$MAC" >/dev/null 2>&1
            sleep 3
            connected && echo "reconnected $MAC"
        elif ! has_sink; then
            sleep 5   # give the audio profile a moment to come up after a fresh connect
            if connected && ! has_sink; then
                echo "connected without audio output: resetting the link"
                bluetoothctl disconnect "$MAC" >/dev/null 2>&1; sleep 3
                timeout 15 bluetoothctl connect "$MAC" >/dev/null 2>&1
            fi
        fi
    fi
    sleep 10
done
