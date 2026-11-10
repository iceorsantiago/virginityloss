#!/usr/bin/env bash
# Read-only suspend/resume evidence collector for the LOQ 15ARP9.
# Changes nothing on the system except (optionally, with --pm-debug) turning on
# /sys/power/pm_debug_messages, which is a runtime switch that resets at reboot.
#
#   sudo bash tools/suspend-diag.sh              # collect
#   sudo bash tools/suspend-diag.sh --pm-debug   # also log verbose PM messages for the next test
#
# Output: <repo>/diag/<timestamp>/ (owned by your user)
set -uo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if (( EUID != 0 )); then echo "Run: sudo bash $repo_dir/tools/suspend-diag.sh" >&2; exit 1; fi
owner=${SUDO_USER:-root}
out="$repo_dir/diag/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out"

if [[ ${1:-} == --pm-debug ]]; then
    echo 1 > /sys/power/pm_debug_messages && echo "pm_debug_messages ON until reboot"
fi

run() { local f=$1; shift; { echo "### $*"; "$@" 2>&1; echo; } >> "$out/$f"; }
sh_() { local f=$1; shift; { echo "### $*"; bash -c "$*" 2>&1; echo; } >> "$out/$f"; }

# --- system / config ---
sh_ system.txt 'uname -a; cat /etc/debian_version'
sh_ system.txt 'cat /sys/class/dmi/id/{sys_vendor,product_name,product_version,bios_version,bios_date}'
sh_ system.txt 'cat /proc/cmdline'
sh_ system.txt 'cat /sys/power/mem_sleep /sys/power/state /sys/power/disk /sys/power/pm_debug_messages'
sh_ system.txt 'lspci -nnk | grep -A4 -iE "vga|3d|display|nvme|audio|network"'
sh_ system.txt 'lsmod | grep -iE "nvidia|drm|amdgpu|backlight|wmi|ideapad"'
sh_ system.txt 'ls -l /sys/class/backlight/; for b in /sys/class/backlight/*; do echo "$b: type=$(cat $b/type) bright=$(cat $b/brightness) actual=$(cat $b/actual_brightness 2>/dev/null) max=$(cat $b/max_brightness)"; done'
sh_ system.txt 'for c in /sys/class/drm/card*-*; do echo "$c: $(cat $c/status 2>/dev/null) $(cat $c/enabled 2>/dev/null) dpms=$(cat $c/dpms 2>/dev/null)"; done'
sh_ system.txt 'df -hT /var/tmp /var /tmp; free -h'
sh_ system.txt 'cat /proc/acpi/wakeup'
sh_ system.txt 'dpkg -l | grep -iE "nvidia|niri|noctalia|greet|linux-image|firmware-amd|systemd " | awk "{print \$1,\$2,\$3}"'
sh_ system.txt 'niri --version; noctalia --version'

sh_ nvidia.txt 'cat /proc/driver/nvidia/version; cat /proc/driver/nvidia/gpus/*/power; cat /proc/driver/nvidia/gpus/*/information'
sh_ nvidia.txt 'cat /proc/driver/nvidia/params'
sh_ nvidia.txt 'grep -rH . /etc/modprobe.d/ /usr/lib/modprobe.d/ 2>/dev/null | grep -iE "nvidia|nouveau"'
sh_ nvidia.txt 'cat /sys/module/nvidia_drm/parameters/* 2>/dev/null | paste -sd" "; ls /sys/module/nvidia_drm/parameters/'
sh_ nvidia.txt 'for u in nvidia-suspend nvidia-resume nvidia-hibernate nvidia-suspend-then-hibernate nvidia-powerd nvidia-persistenced; do printf "%s: %s %s\n" $u "$(systemctl is-enabled $u.service 2>&1)" "$(systemctl is-active $u.service 2>&1)"; done'
sh_ nvidia.txt 'systemctl cat nvidia-suspend.service nvidia-resume.service systemd-suspend.service'
sh_ nvidia.txt 'ls -l /usr/lib/systemd/system-sleep/ /lib/systemd/system-sleep/ 2>/dev/null; cat /usr/bin/nvidia-sleep.sh 2>/dev/null'
sh_ nvidia.txt 'nvidia-smi -q -d POWER,PERFORMANCE,CLOCK 2>&1 | head -80'
sh_ nvidia.txt 'ls -la /var/tmp | head; ls -la /var/tmp/nvidia* 2>/dev/null'

sh_ sleep-config.txt 'systemd-analyze cat-config systemd/sleep.conf'
sh_ sleep-config.txt 'systemd-analyze cat-config systemd/logind.conf | grep -vE "^#|^$"'
sh_ sleep-config.txt 'loginctl list-sessions; loginctl show-session $(loginctl list-sessions --no-legend | awk "{print \$1}" | head -1)'
sh_ sleep-config.txt 'systemd-inhibit --list'
sh_ sleep-config.txt 'grep -rH . /etc/greetd/ 2>/dev/null'

# --- journal ---
sh_ boots.txt 'journalctl --list-boots | tail -15'
pat='PM: |ACPI: PM|suspend|resum|s2idle|s0ix|amd_pmc|NVRM|nvidia|drm|Xid|GSP|Booter|lid|Lid|LID|backlight|eDP|niri|noctalia|greet|locking session|unlocking|failed|timeout|timed out|panicked|watchdog|hung|blocked for|segfault|core dump|nvme'
for b in 0 -1 -2 -3; do
    journalctl -b "$b" --no-pager -o short-monotonic -n 1 >/dev/null 2>&1 || continue
    journalctl -b "$b" --no-pager -o short-iso | grep -E "$pat" | tail -n 2500 > "$out/journal-b${b}-filtered.txt"
    journalctl -b "$b" -k --no-pager -o short-monotonic | tail -n 4000 > "$out/kernel-b${b}.txt"
    journalctl -b "$b" --no-pager -o short-iso _COMM=niri | tail -n 600 > "$out/niri-b${b}.txt"
    journalctl -b "$b" --no-pager -o short-iso | tail -n 400 > "$out/journal-b${b}-tail.txt"
done
sh_ coredumps.txt 'coredumpctl list --no-pager 2>/dev/null | tail -20'

chown -R "$owner": "$repo_dir/diag"
echo "Report written to $out"
ls -la "$out"
