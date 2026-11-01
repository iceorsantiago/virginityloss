#!/usr/bin/env bash
# Paso 2 (root): escritorio mínimo. niri + Noctalia + login gráfico + audio/red/bluetooth + firmware.
# Se instala sin "recommends" para no arrastrar medio GNOME; lo necesario va explícito.
set -Eeuo pipefail
source "$REPO_DIR/lib/comun.sh"
export DEBIAN_FRONTEND=noninteractive
U="${SUDO_USER:?falta SUDO_USER}"

ESENCIALES=(
    # compositor y shell
    niri xwayland xwayland-satellite noctalia
    # sesión, portales, permisos
    dbus-user-session polkitd xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk
    gnome-keyring libsecret-1-0 xdg-user-dirs xdg-utils
    # login
    greetd
    # red, bluetooth, energía
    network-manager bluez power-profiles-daemon
    # audio
    pipewire pipewire-pulse pipewire-alsa wireplumber libspa-0.2-bluetooth pulseaudio-utils
    # firmware del LOQ: Wi-Fi/BT Realtek, GSP de NVIDIA, audio
    firmware-realtek firmware-misc-nonfree firmware-sof-signed
    # terminal y herramientas que usan los dots
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

info "Paquetes esenciales"
apt-get install -y --no-install-recommends "${ESENCIALES[@]}"
info "Extras (los que no existan se omiten)"
instalar_opcionales "${EXTRAS[@]}"

info "Login gráfico (greetd)"
if dpkg -s noctalia-greeter >/dev/null 2>&1; then
    ok "noctalia-greeter instalado (usa greetd; no necesita más configuración)"
else
    apt-get install -y --no-install-recommends tuigreet
    respaldar /etc/greetd/config.toml
    install -Dm644 "$REPO_DIR/system/greetd/config.toml" /etc/greetd/config.toml
    ok "tuigreet como login"
fi
systemctl enable greetd.service
systemctl set-default graphical.target

info "Servicios"
systemctl enable NetworkManager.service bluetooth.service power-profiles-daemon.service

info "Wi-Fi: pasar la conexión del instalador a NetworkManager"
# El instalador de Debian deja el Wi-Fi en /etc/network/interfaces (ifupdown) y así
# NetworkManager no lo puede manejar ni Noctalia mostrarlo. Se copia la red a NetworkManager
# y se comenta en interfaces. Surte efecto al reiniciar, así que no corta la instalación.
IFACES=/etc/network/interfaces
if [ -f "$IFACES" ] && grep -qE '^\s*iface\s+wl' "$IFACES"; then
    dev="$(awk '/^[[:space:]]*iface[[:space:]]+wl/ {print $2; exit}' "$IFACES")"
    ssid="$(awk '/^[[:space:]]*wpa-ssid/ {sub(/^[[:space:]]*wpa-ssid[[:space:]]+/, ""); print; exit}' "$IFACES")"
    psk="$(awk '/^[[:space:]]*wpa-psk/ {sub(/^[[:space:]]*wpa-psk[[:space:]]+/, ""); print; exit}' "$IFACES")"
    ssid="${ssid%\"}"; ssid="${ssid#\"}"; psk="${psk%\"}"; psk="${psk#\"}"
    # NetworkManager ignora las interfaces de ifupdown mientras sigan ahí, así que arrancarlo no corta la red
    systemctl start NetworkManager.service
    if [ -n "$ssid" ] && ! nmcli -t -f NAME connection show 2>/dev/null | grep -qxF "$ssid"; then
        sec=()
        [ -z "$psk" ] || sec=(wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$psk")
        if nmcli connection add type wifi con-name "$ssid" ifname "$dev" ssid "$ssid" "${sec[@]}" connection.autoconnect yes >/dev/null; then
            ok "Red \"$ssid\" copiada a NetworkManager"
        else
            warn "No pude copiar la red; después de reiniciar conéctate desde la barra o con: nmtui"
        fi
    fi
    respaldar "$IFACES"
    # Comenta el bloque del Wi-Fi (allow-hotplug/auto wlX, iface wlX y sus líneas sangradas)
    awk -v dev="$dev" '
        ($1 == "allow-hotplug" || $1 == "auto") && $2 == dev { print "# " $0; next }
        $1 == "iface" && $2 == dev { enbloque = 1; print "# " $0; next }
        enbloque && /^[[:space:]]+/ { print "# " $0; next }
        { enbloque = 0; print }' "$IFACES.bak-loq-dots" > "$IFACES"
    chmod 600 "$IFACES"
    ok "$dev comentado en $IFACES (respaldo en $IFACES.bak-loq-dots)"
    [ -n "$ssid" ] || warn "No encontré el nombre de la red; después de reiniciar conéctate desde la barra o con: nmtui"
else
    ok "nada que migrar"
fi

info "Carpetas de usuario (Imágenes, Descargas...)"
sudo -u "$U" xdg-user-dirs-update || true
