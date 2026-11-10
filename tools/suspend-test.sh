#!/usr/bin/env bash
# Repeated suspend/resume test through the real systemd path (same as lid close:
# nvidia-suspend.service -> s2idle -> nvidia-resume.service). The RTC alarm wakes it up.
#   sudo bash tools/suspend-test.sh [cycles=5] [seconds-asleep=60]
# Save your work first: if the bug is still there, the last cycle ends in a black screen
# and the power button is the way out (the log below survives in the journal).
set -uo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if (( EUID != 0 )); then echo "Run: sudo bash $repo_dir/tools/suspend-test.sh" >&2; exit 1; fi
cycles=${1:-5}; secs=${2:-60}
user=${SUDO_USER:-}; uid=$(id -u "$user" 2>/dev/null || echo 0)
log="$repo_dir/diag/suspend-test-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$repo_dir/diag"
say() { echo "$*" | tee -a "$log"; }

say "S0ix: $(grep -A2 'S0ix Power' /proc/driver/nvidia/gpus/*/power | grep Status)"
say "params: $(grep -E '^(EnableS0ix|PreserveVideo|DynamicPower)' /proc/driver/nvidia/params | paste -sd' ')"
fail=0
for i in $(seq 1 "$cycles"); do
    since=$(date '+%Y-%m-%d %H:%M:%S')
    say "--- cycle $i/$cycles: asleep ${secs}s"
    sync
    rtcwake -m no -s "$secs" >/dev/null
    systemctl suspend
    # wait until systemd says we are back
    for _ in $(seq 1 $((secs + 120))); do
        journalctl --since "$since" -q --no-pager | grep -q "System returned from sleep operation" && break
        sleep 1
    done
    sleep 8
    j=$(journalctl --since "$since" -q --no-pager -o short-iso)
    bad=$(grep -E 'Booter failed|GSP boot failed|GC6 to D0|Xid|nv_set_system_power_state|IO_PAGE_FAULT|niri.*(panicked|error.*(drm|device))' <<<"$j")
    ok_sleep=$(grep -c 'System returned from sleep' <<<"$j")
    gpu=$(timeout 15 nvidia-smi --query-gpu=name,pstate,power.draw --format=csv,noheader 2>&1 | head -1)
    edp=$(cat /sys/class/drm/card*-eDP-1/status /sys/class/drm/card*-eDP-1/enabled 2>/dev/null | paste -sd' ')
    bl=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1)
    niri=$(pgrep -x niri >/dev/null && echo running || echo DEAD)
    net=$(nmcli -t -f TYPE,STATE device 2>/dev/null | grep -E '^wifi' | head -1)
    audio=$( [[ -n $user ]] && sudo -u "$user" XDG_RUNTIME_DIR=/run/user/$uid pactl get-default-sink 2>&1 | head -1)
    say "    resumed=$ok_sleep gpu=[$gpu] eDP=[$edp] backlight=$bl niri=$niri wifi=[$net] audio=[$audio]"
    if [[ -n $bad || $ok_sleep -lt 1 || $niri != running || $gpu != *RTX* ]]; then
        say "    FAIL"; [[ -n $bad ]] && say "$bad"; fail=$((fail + 1))
    else
        say "    ok"
    fi
    sleep 5
done
say "=== $((cycles - fail))/$cycles cycles clean"
chown -R "$user": "$repo_dir/diag" 2>/dev/null || true
echo "Log: $log"
exit "$fail"
