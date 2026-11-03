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

info "Bluetooth: no USB autosuspend (it drops speakers like the Echo Dot)"
install -Dm644 "$REPO_DIR/system/modprobe/btusb-loq.conf" /etc/modprobe.d/btusb-loq.conf
ok "/etc/modprobe.d/btusb-loq.conf (applies after a reboot)"

info "Bluetooth: Classic only (BR/EDR), so the Echo Dot doesn't drop on connect"
# With LE enabled, the kernel tries Cross-Transport Key Derivation (BR/EDR SMP Pairing Request)
# whenever the laptop ends up Central on a new link key. The Echo rejects it ("CTKD not allowed",
# 0x0e) and the kernel then tears the whole link down with "Authentication Failure" (seen in
# btmon; same as bluez/bluez#2661). Classic-only mode removes the trigger and keeps Secure
# Connections on. Revert with ControllerMode = dual if you ever need Bluetooth LE devices.
main_conf=/etc/bluetooth/main.conf
if grep -qE '^[#[:space:]]*ControllerMode[[:space:]]*=' "$main_conf"; then
    sed -i -E 's/^[#[:space:]]*ControllerMode[[:space:]]*=.*/ControllerMode = bredr/' "$main_conf"
else
    sed -i -E '0,/^\[General\]/s//[General]\nControllerMode = bredr/' "$main_conf"
fi
grep -q '^ControllerMode = bredr' "$main_conf" && ok "$main_conf: ControllerMode = bredr"
systemctl restart bluetooth.service && ok "bluetooth.service restarted"

info "Faster boot: don't wait for the network before the desktop starts"
# A laptop needs nothing network-related at boot; this alone was ~5.7 s of every startup
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
ok "NetworkManager-wait-online disabled"
