#!/usr/bin/env bash
# Keep a Bluetooth speaker connected as the laptop's audio OUTPUT, including after reboots.
#  - not connected                         -> connect ONLY the speaker's Audio Sink profile (110b)
#  - connected but no audio output (sink)  -> the link is half-up: disconnect and reconnect
# Why only the Audio Sink UUID: a plain "connect" also tries the reverse A2DP direction (the Echo
# as a source), which the Echo refuses, and BlueZ then reports the whole connect as failed.
# Backs off while the speaker is unreachable (powered off, or another device holds it: the Echo
# keeps only one Bluetooth connection), so it doesn't hammer the adapter.
MAC="${1:-6C:0C:9A:39:B4:0D}"   # Echo Dot-2JS (Bluetooth address; B3:77 is its Wi-Fi address)
A2DP_SINK=0000110b-0000-1000-8000-00805f9b34fb
SINK="bluez_output.${MAC//:/_}"

connected() { bluetoothctl info "$MAC" 2>/dev/null | grep -q 'Connected: yes'; }
has_sink()  { pactl list sinks short 2>/dev/null | grep -q "$SINK"; }
ready()     { bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' &&
              bluetoothctl info "$MAC" 2>/dev/null | grep -q 'Paired: yes'; }
connect()   { timeout 20 bluetoothctl connect "$MAC" "$A2DP_SINK" >/dev/null 2>&1; sleep 4; }

wait=10
while true; do
    if ready; then
        if ! connected; then
            connect
            if connected; then echo "connected $MAC"; wait=10
            else wait=$(( wait < 60 ? wait * 2 : 60 ))   # 10, 20, 40, 60 s while unreachable
            fi
        elif ! has_sink; then
            sleep 6   # give the audio profile a moment after a fresh connect
            if connected && ! has_sink; then
                echo "connected without audio output: resetting the link"
                bluetoothctl disconnect "$MAC" >/dev/null 2>&1; sleep 3
                connect
            fi
        else
            wait=10
        fi
    fi
    sleep "$wait"
done
