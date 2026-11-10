#!/usr/bin/env bash
# Apply only the confirmed sleep integration correction, without reinstalling drivers.
set -Eeuo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if (( EUID != 0 )); then
    echo "Run: sudo bash $repo_dir/tools/apply-sleep-config.sh" >&2
    exit 1
fi
install -Dm644 "$repo_dir/system/systemd/sleep.conf.d/90-loq-nvidia.conf" \
    /etc/systemd/sleep.conf.d/90-loq-nvidia.conf
for unit in nvidia-suspend nvidia-resume nvidia-hibernate nvidia-suspend-then-hibernate; do
    systemctl enable "$unit.service"
done
echo 'Applied: hybrid sleep disabled; NVIDIA sleep services enabled. No reboot required.'
echo 'Regular suspend still has an unresolved GSP resume failure. See docs/suspend-resume.md.'
echo 'Undo hybrid-sleep restriction: sudo rm /etc/systemd/sleep.conf.d/90-loq-nvidia.conf'
