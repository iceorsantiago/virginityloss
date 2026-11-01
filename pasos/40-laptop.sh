#!/usr/bin/env bash
# Paso 4 (root): ajustes del Lenovo LOQ 15ARP9.
#  - Modo conservación de batería (tope ~80%) vía el driver ideapad_laptop del kernel,
#    con un comando que se usa con sudo (sin chmod 666 en /sys como el script de Acer).
#  - Opciones de Wi-Fi RTL8852BE listas pero APAGADAS: solo si ves cortes de Wi-Fi.
set -Eeuo pipefail
source "$REPO_DIR/lib/comun.sh"

info "Comando loq-bateria (modo conservación)"
install -Dm755 "$REPO_DIR/system/bin/loq-bateria" /usr/local/bin/loq-bateria
if ls /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode >/dev/null 2>&1; then
    ok "ideapad_laptop expone conservation_mode: usa  sudo loq-bateria on|off"
else
    warn "Este kernel no expone conservation_mode todavía; loq-bateria avisará si no está disponible."
fi

info "Opciones de Wi-Fi (desactivadas por defecto)"
install -Dm644 "$REPO_DIR/system/modprobe/rtw89-loq.conf" /etc/modprobe.d/rtw89-loq.conf
ok "/etc/modprobe.d/rtw89-loq.conf (descomenta si el Wi-Fi se corta)"
