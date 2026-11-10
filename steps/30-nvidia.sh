#!/usr/bin/env bash
# Step 3 (root): NVIDIA driver for the RTX 4050 (AD107, 10de:28e1).
#
# Why NVIDIA's repo and not Debian's:
#  - Debian 13's nvidia-driver is the 550 branch: the Debian wiki marks it unmaintained,
#    its "open" version no longer builds on trixie's current kernel and doesn't reach CUDA 13,
#    so current PyTorch doesn't run (it needs driver >= 580).
#  - NVIDIA's debian13 repo has 595+ branches with "open" modules (recommended for Ada).
#  - ONE branch is pinned so apt doesn't jump to a new major version on its own.
#  - Debian's NVIDIA packages are never mixed with NVIDIA's, nor with the .run installer.
#
# This machine has NO integrated GPU: if the module doesn't load, there's no desktop.
# That's why Secure Boot is handled here (DKMS MOK key) before installing the driver.
set -Eeuo pipefail
source "$REPO_DIR/lib/common.sh"
export DEBIAN_FRONTEND=noninteractive
BRANCH="${NVIDIA_BRANCH:-${NVIDIA_RAMA:-595}}"
REPO_NV=https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64

info "GPU"
lspci -nn | grep -iE 'vga|3d|display' || true
lspci -nn | grep -i '10de:' >/dev/null || die "No NVIDIA GPU found. Run with --no-nvidia if this is another machine."

# Don't mix with Debian's NVIDIA packages
if dpkg -l 'nvidia-*' 2>/dev/null | awk '/^ii/ {print $2"="$3}' | grep -E '=550\.' >/dev/null; then
    die "Debian's NVIDIA 550 packages are installed. Remove them first:
  sudo apt purge 'nvidia-*' 'libnvidia-*' && sudo apt autoremove"
fi

info "Kernel headers, DKMS and Secure Boot tools"
apt-get install -y --no-install-recommends linux-headers-amd64 "linux-headers-$(uname -r)" dkms mokutil openssl build-essential

SB=0
if mokutil --sb-state 2>/dev/null | grep -i 'enabled' >/dev/null; then SB=1; fi
if [ "$SB" -eq 1 ]; then
    info "Secure Boot on: preparing the key DKMS signs the modules with"
    if [ ! -f /var/lib/dkms/mok.pub ]; then
        dkms generate_mok
    fi
    ok "/var/lib/dkms/mok.pub"
else
    ok "Secure Boot off: no signing needed"
fi

info "NVIDIA repository (debian13) and branch $BRANCH"
if ! dpkg -s cuda-keyring >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    wget -qO "$tmp/cuda-keyring.deb" "$REPO_NV/cuda-keyring_1.1-1_all.deb"
    dpkg -i "$tmp/cuda-keyring.deb"
    rm -rf "$tmp"
fi
apt-get update
if pkg_exists "nvidia-driver-pinning-$BRANCH"; then
    apt-get install -y "nvidia-driver-pinning-$BRANCH"
else
    warn "nvidia-driver-pinning-$BRANCH doesn't exist; installing the newest branch unpinned. Available branches:"
    apt-cache search --names-only '^nvidia-driver-pinning-' || true
fi

info "Driver (open modules)"
apt-get install -y nvidia-open

info "Module options"
install -Dm644 "$REPO_DIR/system/modprobe/nvidia-loq.conf" /etc/modprobe.d/nvidia-loq.conf
# Suspend: S0ix (GC6) off, overriding nvidia.conf; see docs/suspend-resume.md
install -Dm644 "$REPO_DIR/system/modprobe/zz-nvidia-loq-suspend.conf" /etc/modprobe.d/zz-nvidia-loq-suspend.conf
# niri: stops the driver from holding ~1 GB of extra VRAM (niri wiki recommendation for NVIDIA)
install -Dm644 "$REPO_DIR/system/nvidia/50-limit-free-buffer-pool-in-wayland-compositors.json" \
    /etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json

info "Boot parameters (GRUB, separate file so /etc/default/grub is left alone)"
install -Dm644 "$REPO_DIR/system/grub/90-loq-nvidia.cfg" /etc/default/grub.d/90-loq-nvidia.cfg

info "Suspend: NVIDIA services that save VRAM"
for s in nvidia-suspend nvidia-resume nvidia-hibernate nvidia-suspend-then-hibernate; do
    systemctl list-unit-files "$s.service" >/dev/null 2>&1 && systemctl enable "$s.service" || warn "$s.service doesn't exist"
done

update-initramfs -u -k all
update-grub

info "Checking the module build"
dkms status | grep -i nvidia || die "DKMS doesn't show the nvidia module. Check: sudo dkms status && sudo dkms autoinstall"
if [ "$SB" -eq 1 ]; then
    # No pipe: with pipefail, mokutil's exit code would fail the test even when the key is enrolled
    mok="$(mokutil --test-key /var/lib/dkms/mok.pub 2>&1 || true)"
    if grep -qi 'already enrolled' <<<"$mok"; then
        ok "The MOK key is already enrolled"
        rm -f "${STATE:-/tmp}/mok-pending" "${STATE:-/tmp}/mok-pendiente"
    else
        cat <<'EOF'

  Now set a one-time password (at least 8 characters) to enroll the key.
  The blue MokManager screen will ask for it ONCE when you reboot. Write it down.
EOF
        mokutil --import /var/lib/dkms/mok.pub
        touch "${STATE:-/tmp}/mok-pending"
        chown "${SUDO_USER:-root}:" "${STATE:-/tmp}/mok-pending" 2>/dev/null || true
    fi
fi
ok "NVIDIA ready (takes effect after reboot)"
