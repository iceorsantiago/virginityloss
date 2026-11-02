#!/usr/bin/env bash
# Step 2b (root): live alongside Windows on the same disk.
#  - If it finds the Windows boot manager on the EFI partition, it enables os-prober so that
#    "Windows Boot Manager" stays in the GRUB menu every time it's regenerated (the NVIDIA step does that).
#  - Debian stays the default entry; 5 s to choose.
#  - Support for opening Windows NTFS disks (the external SSD D:) from the file manager.
# Without Windows, it only installs NTFS support and leaves GRUB alone.
set -Eeuo pipefail
source "$REPO_DIR/lib/common.sh"
export DEBIAN_FRONTEND=noninteractive

info "NTFS disks (D: with the games and the backup)"
install_optional udisks2 gvfs gvfs-backends gvfs-fuse ntfs-3g

WIN=""
for f in /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi /boot/efi/EFI/microsoft/boot/bootmgfw.efi; do
    [ -f "$f" ] && WIN="$f"
done
if [ -z "$WIN" ]; then
    ok "No Windows found on the EFI partition: GRUB left unchanged"
    exit 0
fi

info "Windows detected ($WIN): keeping it in the GRUB menu"
apt-get install -y --no-install-recommends os-prober
install -Dm644 "$REPO_DIR/system/grub/91-loq-dualboot.cfg" /etc/default/grub.d/91-loq-dualboot.cfg
update-grub
if grep -q 'Windows Boot Manager' /boot/grub/grub.cfg; then
    ok "Windows entry present in /boot/grub/grub.cfg"
else
    warn "GRUB didn't add Windows. You can still boot it with F12 at power-on, and check with: sudo os-prober"
fi

cat <<'EOF'

  Time: Windows keeps the clock in local time and Linux in UTC, so one of them ends up
  off. The fix goes on the Windows side (once, as administrator):
      windows/utc-time.reg   (double-click)   or in an admin PowerShell:
      reg add HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
EOF
