#!/usr/bin/env bash
# loq-dots: Debian 13 (installed without a desktop) -> niri + Noctalia with the amane/suzuha look.
# Made for the Lenovo LOQ 15ARP9 (Ryzen 5 7235HS + RTX 4050, no integrated GPU, Secure Boot on).
#
# Usage (as your user, NOT with sudo):
#   ./install.sh               everything: repos, desktop, NVIDIA, LOQ tweaks and dots
#   ./install.sh --apps        all of the above + optional apps (asks one by one)
#   ./install.sh --no-nvidia   skip the NVIDIA driver (not recommended on this machine)
#   ./install.sh --dots-only   only copy the config again
#   ./install.sh --classes     only install the class stuff (Node, Edge, Wireshark, LaTeX/Typst, SQL...)
#   ./install.sh --verify      check that everything works (run it after rebooting)
#   ./install.sh --force       repeat steps already marked as done
#
# Each step leaves a marker in ~/.local/state/loq-dots/done, so if something fails
# you can fix it and run the script again: it picks up where it left off.
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
export REPO_DIR
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

# The old Spanish flags still work as aliases
APPS=0 NVIDIA=1 DOTS_ONLY=0 FORCE=0 CLASSES=0
for a in "$@"; do
    case "$a" in
        --apps) APPS=1 ;;
        --no-nvidia|--sin-nvidia) NVIDIA=0 ;;
        --dots-only|--solo-dots) DOTS_ONLY=1 ;;
        --classes|--clases) CLASSES=1 ;;
        --verify|--verificar) exec bash "$REPO_DIR/steps/verify.sh" ;;
        --force|--forzar) FORCE=1 ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        *) die "Unknown option: $a (see --help)" ;;
    esac
done

[ "$(id -u)" -ne 0 ] || die "Run it as your normal user (without sudo); the script asks for sudo when it needs it."
. /etc/os-release
[ "${VERSION_CODENAME:-}" = "trixie" ] || die "This is for Debian 13 (trixie); this system is: ${PRETTY_NAME:-unknown}"
[ "$(dpkg --print-architecture)" = "amd64" ] || die "amd64 only."
command -v sudo >/dev/null && sudo -v 2>/dev/null || die "Your user can't use sudo.
  As root:  apt install sudo && usermod -aG sudo $USER   and log in again.
  (If you leave the root password empty in the installer, Debian gives you sudo automatically.)"
# Keep sudo alive while the script runs
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

STATE="$HOME/.local/state/loq-dots"
# One-time migration from the old Spanish state names, so finished steps don't run again
if [ -d "$STATE/hecho" ] && [ ! -e "$STATE/done" ]; then
    mv "$STATE/hecho" "$STATE/done"
fi
for pair in escritorio:desktop clases:classes; do
    old="${pair%%:*}" new="${pair#*:}"
    if [ -e "$STATE/done/$old" ] && [ ! -e "$STATE/done/$new" ]; then
        mv "$STATE/done/$old" "$STATE/done/$new"
    fi
done
if [ -e "$STATE/mok-pendiente" ]; then
    mv -f "$STATE/mok-pendiente" "$STATE/mok-pending"
fi
mkdir -p "$STATE/done"
LOG="$STATE/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
info "Full log in $LOG"

# A freshly installed netinst may not have curl; it does have wget
{ curl -fsI --max-time 10 https://deb.debian.org || wget -q --spider --timeout=10 https://deb.debian.org; } >/dev/null 2>&1 || die "No internet. Connect (the Debian installer already set up the Wi-Fi) and try again."

# step <name> <script> <root|user>
step() {
    local name="$1" script="$2" as="$3"
    if [ -e "$STATE/done/$name" ] && [ "$FORCE" -eq 0 ]; then
        ok "$name (already done; --force to repeat)"; return
    fi
    info "Step: $name"
    if [ "$as" = root ]; then
        sudo REPO_DIR="$REPO_DIR" STATE="$STATE" bash "$REPO_DIR/steps/$script"
    else
        bash "$REPO_DIR/steps/$script"
    fi
    date -Is > "$STATE/done/$name"
}

if [ "$DOTS_ONLY" -eq 1 ]; then
    FORCE=1 step dots 50-dots.sh user
    exit 0
fi
if [ "$CLASSES" -eq 1 ]; then
    FORCE=1 step classes 70-classes.sh user
    exit 0
fi

step repos       10-repos.sh      root
step desktop     20-desktop.sh    root
step dualboot    25-dualboot.sh   root
if [ "$NVIDIA" -eq 1 ]; then step nvidia 30-nvidia.sh root; else warn "Skipping NVIDIA: without the driver this machine has no accelerated desktop."; fi
step laptop      40-laptop.sh     root
FORCE=1 step dots 50-dots.sh      user
if [ "$APPS" -eq 1 ]; then FORCE=1 step apps 60-apps.sh user; fi

echo
info "Finished."
if [ -e "$STATE/mok-pending" ]; then
    cat <<'EOF'

  IMPORTANT (Secure Boot): when you reboot, a blue screen (MokManager) will show up.
    1. "Enroll MOK"  ->  "Continue"  ->  "Yes"
    2. Type the one-time password you set a moment ago
    3. "Reboot"
  If you pick "Continue boot" without enrolling, the NVIDIA driver won't load and there will be no desktop.
  (To fix it, run:  sudo mokutil --import /var/lib/dkms/mok.pub  and reboot.)
EOF
fi
cat <<'EOF'

  Reboot now:   sudo reboot
  When it's back, log in from the login screen and then run:   ./install.sh --verify
EOF
