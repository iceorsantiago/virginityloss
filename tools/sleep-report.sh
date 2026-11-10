#!/usr/bin/env bash
# Read-only report. Optional argument is a journal boot offset, e.g. -1.
set -uo pipefail
boot=${1:-0}
if [[ ! $boot =~ ^-?[0-9]+$ ]]; then
    echo 'Usage: bash tools/sleep-report.sh [boot-offset]' >&2
    exit 2
fi
printf 'Kernel: '; uname -r
printf 'BIOS: '; cat /sys/class/dmi/id/bios_version
printf 'Command line: '; cat /proc/cmdline
printf 'Sleep modes: '; cat /sys/power/mem_sleep
cat /proc/driver/nvidia/version /proc/driver/nvidia/gpus/*/power 2>/dev/null
printf '\nSleep configuration:\n'
systemd-analyze cat-config systemd/sleep.conf
printf '\nNVIDIA service enablement:\n'
for unit in nvidia-suspend nvidia-resume nvidia-hibernate nvidia-suspend-then-hibernate; do
    printf '%s: ' "$unit"
    systemctl is-enabled "$unit.service" || true
done
printf '\nRelevant journal (boot %s):\n' "$boot"
# Bound output: ACPI D-Notifier failures can repeat thousands of times.
journalctl -b "$boot" --no-pager -o short-iso |
    grep -E 'PM: (suspend|hibernation)|NVRM:.*(Xid|GSP|Booter|procfs)|nvidia-(suspend|resume|hibernate)|laptop lid|locking session|unlocking session|failed to (suspend|freeze)|System (Suspend|Hybrid)|thread .*panicked' |
    tail -n 160
