#!/usr/bin/env bash
# Step 2 (root): minimal desktop. niri + Noctalia + graphical login + audio/network/bluetooth + firmware.
# Installed without "recommends" so it doesn't drag in half of GNOME; what's needed is listed explicitly.
set -Eeuo pipefail
source "$REPO_DIR/lib/common.sh"
export DEBIAN_FRONTEND=noninteractive
U="${SUDO_USER:?SUDO_USER is not set}"

ESSENTIALS=(
    # compositor and shell
    niri xwayland xwayland-satellite noctalia
    # session, portals, permissions
    dbus-user-session polkitd xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk
    gnome-keyring libsecret-1-0 xdg-user-dirs xdg-utils
    # login
    greetd
    # network, bluetooth, power
    network-manager bluez power-profiles-daemon
    # audio
    pipewire pipewire-pulse pipewire-alsa wireplumber libspa-0.2-bluetooth pulseaudio-utils
    # LOQ firmware: Realtek Wi-Fi/BT, NVIDIA GSP, audio
    firmware-realtek firmware-misc-nonfree firmware-sof-signed
    # terminal and tools the dots use
    kitty fish fzf zoxide bat btop git curl unzip xz-utils fontconfig
    wl-clipboard grim slurp brightnessctl playerctl libnotify-bin
    libglib2.0-bin gsettings-desktop-schemas
    fonts-noto-core fonts-noto-color-emoji
)
EXTRAS=(
    starship eza fastfetch cava cliphist wl-clip-persist
    fonts-noto-cjk fonts-materialdesignicons-webfont
    papirus-icon-theme adw-gtk3 nautilus loupe file-roller pavucontrol
    noctalia-greeter
)

info "Essential packages"
apt-get install -y --no-install-recommends "${ESSENTIALS[@]}"
info "Extras (missing ones are skipped)"
install_optional "${EXTRAS[@]}"

info "Graphical login (greetd)"
if dpkg -s noctalia-greeter >/dev/null 2>&1; then
    ok "noctalia-greeter installed (uses greetd; needs no further setup)"
else
    apt-get install -y --no-install-recommends tuigreet
    backup /etc/greetd/config.toml
    install -Dm644 "$REPO_DIR/system/greetd/config.toml" /etc/greetd/config.toml
    ok "tuigreet as the login screen"
fi
systemctl enable greetd.service
systemctl set-default graphical.target

info "Services"
systemctl enable NetworkManager.service bluetooth.service power-profiles-daemon.service

info "Wi-Fi: moving the installer's connection to NetworkManager"
# The Debian installer leaves the Wi-Fi in /etc/network/interfaces (ifupdown), so
# NetworkManager can't manage it and Noctalia can't show it. The network is copied to NetworkManager
# and commented out in interfaces. It takes effect on reboot, so it doesn't cut the install.
IFACES=/etc/network/interfaces
if [ -f "$IFACES" ] && grep -qE '^\s*iface\s+wl' "$IFACES"; then
    dev="$(awk '/^[[:space:]]*iface[[:space:]]+wl/ {print $2; exit}' "$IFACES")"
    ssid="$(awk '/^[[:space:]]*wpa-ssid/ {sub(/^[[:space:]]*wpa-ssid[[:space:]]+/, ""); print; exit}' "$IFACES")"
    psk="$(awk '/^[[:space:]]*wpa-psk/ {sub(/^[[:space:]]*wpa-psk[[:space:]]+/, ""); print; exit}' "$IFACES")"
    ssid="${ssid%\"}"; ssid="${ssid#\"}"; psk="${psk%\"}"; psk="${psk#\"}"
    # NetworkManager ignores ifupdown interfaces while they're still there, so starting it doesn't cut the network
    systemctl start NetworkManager.service
    if [ -n "$ssid" ] && ! nmcli -t -f NAME connection show 2>/dev/null | grep -xF "$ssid" >/dev/null; then
        sec=()
        [ -z "$psk" ] || sec=(wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$psk")
        if nmcli connection add type wifi con-name "$ssid" ifname "$dev" ssid "$ssid" "${sec[@]}" connection.autoconnect yes >/dev/null; then
            ok "Network \"$ssid\" copied to NetworkManager"
        else
            warn "Couldn't copy the network; after rebooting, connect from the bar or with: nmtui"
        fi
    fi
    backup "$IFACES"
    # Comment out the Wi-Fi block (allow-hotplug/auto wlX, iface wlX and its indented lines)
    awk -v dev="$dev" '
        ($1 == "allow-hotplug" || $1 == "auto") && $2 == dev { print "# " $0; next }
        $1 == "iface" && $2 == dev { inblock = 1; print "# " $0; next }
        inblock && /^[[:space:]]+/ { print "# " $0; next }
        { inblock = 0; print }' "$IFACES.bak-loq-dots" > "$IFACES"
    chmod 600 "$IFACES"
    ok "$dev commented out in $IFACES (backup in $IFACES.bak-loq-dots)"
    [ -n "$ssid" ] || warn "Couldn't find the network name; after rebooting, connect from the bar or with: nmtui"
else
    ok "nothing to migrate"
fi

info "User folders (Pictures, Downloads...)"
sudo -u "$U" xdg-user-dirs-update || true
