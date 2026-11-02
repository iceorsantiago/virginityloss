#!/usr/bin/env bash
# Step 4 (root): Lenovo LOQ 15ARP9 tweaks.
#  - Battery conservation mode (~80% cap) via the kernel's ideapad_laptop driver,
#    with a command used through sudo (no chmod 666 on /sys like the Acer script).
#  - RTL8852BE Wi-Fi options ready but OFF: only if you see Wi-Fi drops.
set -Eeuo pipefail
source "$REPO_DIR/lib/common.sh"

info "loq-battery command (conservation mode)"
install -Dm755 "$REPO_DIR/system/bin/loq-battery" /usr/local/bin/loq-battery
rm -f /usr/local/bin/loq-bateria   # old name
if ls /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode >/dev/null 2>&1; then
    ok "ideapad_laptop exposes conservation_mode: use  sudo loq-battery on|off"
else
    warn "This kernel doesn't expose conservation_mode yet; loq-battery will tell you if it's unavailable."
fi

info "Wi-Fi options (off by default)"
install -Dm644 "$REPO_DIR/system/modprobe/rtw89-loq.conf" /etc/modprobe.d/rtw89-loq.conf
ok "/etc/modprobe.d/rtw89-loq.conf (uncomment if the Wi-Fi drops)"
