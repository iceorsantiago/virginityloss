#!/usr/bin/env bash
# Apply the 2026-11-10 suspend fix: NVIDIA S0ix/GC6 off (see docs/suspend-resume.md).
# Backs up everything it touches, rebuilds the initramfs, does NOT reboot.
set -Eeuo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if (( EUID != 0 )); then echo "Run: sudo bash $repo_dir/tools/apply-suspend-fix.sh" >&2; exit 1; fi

bk=/var/backups/loq-suspend-fix/$(date +%Y%m%d-%H%M%S)
mkdir -p "$bk"
cp -a /etc/modprobe.d "$bk/modprobe.d"
for f in /boot/initrd.img-*; do cp -a "$f" "$bk/"; done
echo "$bk" > /var/backups/loq-suspend-fix/LAST
echo "Backup: $bk"

install -Dm644 "$repo_dir/system/modprobe/nvidia-loq.conf"            /etc/modprobe.d/nvidia-loq.conf
install -Dm644 "$repo_dir/system/modprobe/zz-nvidia-loq-suspend.conf" /etc/modprobe.d/zz-nvidia-loq-suspend.conf

# The services that save/restore VRAM must run (the S0ix-off path depends on them)
for u in nvidia-suspend nvidia-resume nvidia-hibernate nvidia-suspend-then-hibernate; do
    systemctl list-unit-files "$u.service" >/dev/null 2>&1 && systemctl enable "$u.service"
done

echo "Effective nvidia options (last value wins):"
modprobe --showconfig | grep -E '^options nvidia ' | sed 's/^/   /'
modprobe --showconfig | grep -E '^options nvidia ' | grep -o 'NVreg_EnableS0ixPowerManagement=[01]' | tail -1 \
    | grep -q '=0$' || { echo "ERROR: S0ix is not 0 in the effective config" >&2; exit 1; }

update-initramfs -u -k all
echo
echo "Done. Nothing changes until you reboot (the nvidia module only reads options at load)."
echo "After rebooting: grep EnableS0ix /proc/driver/nvidia/params   -> must be 0"
echo "Undo: sudo bash $repo_dir/tools/rollback-suspend-fix.sh"
