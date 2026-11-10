#!/usr/bin/env bash
# Undo tools/apply-suspend-fix.sh: restore /etc/modprobe.d and the initramfs from the last backup.
set -Eeuo pipefail
if (( EUID != 0 )); then echo "Run: sudo bash $0" >&2; exit 1; fi
bk=${1:-$(cat /var/backups/loq-suspend-fix/LAST)}
[[ -d $bk/modprobe.d ]] || { echo "No backup at $bk" >&2; exit 1; }
rm -f /etc/modprobe.d/zz-nvidia-loq-suspend.conf
cp -a "$bk/modprobe.d/." /etc/modprobe.d/
for f in "$bk"/initrd.img-*; do cp -a "$f" /boot/; done
echo "Restored /etc/modprobe.d and /boot/initrd.img-* from $bk. Reboot to load the old options."
