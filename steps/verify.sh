#!/usr/bin/env bash
# Post-reboot check. Read-only, changes nothing.  ./install.sh --verify
set -uo pipefail
source "$REPO_DIR/lib/common.sh"

FAILURES=0
check() { # check "description" command...
    local d="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$d"; else printf '\033[1;31m xx\033[0m %s\n' "$d"; FAILURES=$((FAILURES + 1)); fi
}

info "System"
check "Debian 13"                       grep -q 'VERSION_CODENAME=trixie' /etc/os-release
check "greetd enabled at boot"          systemctl is-enabled greetd
check "niri installed"                  command -v niri
check "Noctalia installed"              command -v noctalia
check "niri config valid"               niri validate
check "Noctalia config valid"           noctalia config validate

# Only root can read /boot/efi and grub.cfg; efibootmgr works as a user
if efibootmgr 2>/dev/null | grep -i 'Windows Boot Manager' >/dev/null; then
    info "Dual boot"
    if [ -r /boot/grub/grub.cfg ]; then
        check "Windows in the GRUB menu"  grep -q 'Windows Boot Manager' /boot/grub/grub.cfg
    else
        echo "     GRUB menu: no permission to read it (check with: sudo grep 'Windows Boot Manager' /boot/grub/grub.cfg)"
    fi
    check "os-prober enabled"           grep -rqs 'GRUB_DISABLE_OS_PROBER=false' /etc/default/grub /etc/default/grub.d
fi

info "NVIDIA"
check "nvidia module loaded"            grep -q '^nvidia ' /proc/modules
# Only root can read the parameter; without permission, look at what was passed at boot
if [ -r /sys/module/nvidia_drm/parameters/modeset ]; then
    check "nvidia_drm with modeset=Y"   grep -q Y /sys/module/nvidia_drm/parameters/modeset
else
    check "nvidia-drm.modeset=1 at boot" grep -qw 'nvidia-drm.modeset=1' /proc/cmdline
fi
check "nvidia-smi sees the RTX 4050"    sh -c 'nvidia-smi --query-gpu=name --format=csv,noheader | grep -q "RTX 4050"'
if mokutil --sb-state 2>/dev/null | grep -i enabled >/dev/null; then
    # No pipe: with pipefail, mokutil's exit code would fail the test even when the key is enrolled
    mok="$(mokutil --test-key /var/lib/dkms/mok.pub 2>&1 || true)"
    if grep -qi 'already enrolled' <<<"$mok"; then
        ok "Secure Boot: DKMS key enrolled"
        rm -f "$HOME/.local/state/loq-dots/mok-pending" "$HOME/.local/state/loq-dots/mok-pendiente"
    else
        printf '\033[1;31m xx\033[0m %s\n' "Secure Boot: the DKMS key is NOT enrolled (sudo mokutil --import /var/lib/dkms/mok.pub and reboot)"
        FAILURES=$((FAILURES + 1))
    fi
fi
check "suspend fix: pcie_aspm=off at boot"   grep -qw 'pcie_aspm=off' /proc/cmdline
check "suspend fix: NVMe deep states off"    grep -qw 'nvme_core.default_ps_max_latency_us=0' /proc/cmdline
check "suspend fix: NVIDIA S0ix/GC6 off"     sh -c 'grep -A2 "S0ix Power" /proc/driver/nvidia/gpus/*/power | grep -q "Status:.*Disabled"'
check "suspend fix: NVIDIA VRAM saved"       grep -q '^PreserveVideoMemoryAllocations: 1' /proc/driver/nvidia/params
check "suspend fix: nvidia-suspend enabled"  systemctl is-enabled -q nvidia-suspend.service
check "suspend fix: nvidia-resume enabled"   systemctl is-enabled -q nvidia-resume.service
command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null | sed 's/^/     /'

info "LOQ hardware"
check "Wi-Fi (rtw89_8852be)"            grep -q '^rtw89_8852be' /proc/modules
check "NetworkManager manages the Wi-Fi" sh -c 'nmcli -t -f TYPE,STATE device | grep -q "^wifi:connected"'
check "Bluetooth"                       sh -c 'bluetoothctl list | grep -q Controller'
check "Bluetooth Classic-only (Echo fix)" grep -q '^ControllerMode = bredr' /etc/bluetooth/main.conf
check "btusb autosuspend off"           sh -c 'test "$(cat /sys/module/btusb/parameters/enable_autosuspend)" = N'
check "Echo keepalive enabled"           systemctl --user is-enabled -q echo-keepalive.service
check "Audio (PipeWire)"                sh -c 'pactl info | grep -q PipeWire'
check "Brightness control"              sh -c 'ls /sys/class/backlight/ | grep -q .'
ls /sys/class/backlight/ 2>/dev/null | sed 's/^/     backlight: /'
check "Conservation mode available"     sh -c 'ls /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode'
echo "     suspend: $(cat /sys/power/mem_sleep 2>/dev/null)"

info "Look"
check "Poppins"                         sh -c 'fc-list | grep -q Poppins'
check "JetBrainsMono Nerd Font"         sh -c 'fc-list | grep -q "JetBrainsMono Nerd Font"'
check "Symbols Nerd Font"               sh -c 'fc-list | grep -q "Symbols Nerd Font"'
check "Catppuccin cursor"               test -d "$HOME/.local/share/icons/catppuccin-mocha-dark-cursors"
check "Wallpaper"                       sh -c 'ls "$(xdg-user-dir PICTURES)/Wallpapers/snowcapped-mountains.jpg" || ls ~/Pictures/Wallpapers/snowcapped-mountains.jpg'
check "fish as the shell"               sh -c 'getent passwd "$USER" | grep -q /usr/bin/fish'

echo
if [ "$FAILURES" -eq 0 ]; then
    ok "All good."
else
    warn "$FAILURES checks failed. The fixes are in the 'Troubleshooting' section of the README."
fi
cat <<'EOF'

  Manual tests still to do:
   - Suspend (close the lid or Super+X > Suspend) and come back: the screen should return.
   - Brightness and volume keys: they should show the Noctalia OSD.
   - External monitor over HDMI: niri msg outputs
EOF
exit "$FAILURES"
