#!/usr/bin/env bash
# Revisión después de reiniciar. Solo lee, no cambia nada.  ./install.sh --verificar
set -uo pipefail
source "$REPO_DIR/lib/comun.sh"

FALLOS=0
chequeo() { # chequeo "descripción" comando...
    local d="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$d"; else printf '\033[1;31m xx\033[0m %s\n' "$d"; FALLOS=$((FALLOS + 1)); fi
}

info "Sistema"
chequeo "Debian 13"                       grep -q 'VERSION_CODENAME=trixie' /etc/os-release
chequeo "greetd activo al arrancar"       systemctl is-enabled greetd
chequeo "niri instalado"                  command -v niri
chequeo "Noctalia instalado"              command -v noctalia
chequeo "config de niri válida"           niri validate
chequeo "config de Noctalia válida"       noctalia config validate

# /boot/efi y grub.cfg solo los lee root; efibootmgr sí funciona como usuario
if efibootmgr 2>/dev/null | grep -i 'Windows Boot Manager' >/dev/null; then
    info "Dual boot"
    if [ -r /boot/grub/grub.cfg ]; then
        chequeo "Windows en el menú de GRUB"  grep -q 'Windows Boot Manager' /boot/grub/grub.cfg
    else
        echo "     menú de GRUB: sin permiso para leerlo (revísalo con: sudo grep 'Windows Boot Manager' /boot/grub/grub.cfg)"
    fi
    chequeo "os-prober activado"          grep -rqs 'GRUB_DISABLE_OS_PROBER=false' /etc/default/grub /etc/default/grub.d
fi

info "NVIDIA"
chequeo "módulo nvidia cargado"           grep -q '^nvidia ' /proc/modules
# El parámetro solo lo lee root; sin permiso se mira lo que se pasó al arrancar
if [ -r /sys/module/nvidia_drm/parameters/modeset ]; then
    chequeo "nvidia_drm con modeset=Y"    grep -q Y /sys/module/nvidia_drm/parameters/modeset
else
    chequeo "nvidia-drm.modeset=1 al arrancar" grep -qw 'nvidia-drm.modeset=1' /proc/cmdline
fi
chequeo "nvidia-smi ve la RTX 4050"       sh -c 'nvidia-smi --query-gpu=name --format=csv,noheader | grep -q "RTX 4050"'
if mokutil --sb-state 2>/dev/null | grep -i enabled >/dev/null; then
    # Sin pipe: con pipefail el código de salida de mokutil haría fallar la prueba aunque la llave esté
    mok="$(mokutil --test-key /var/lib/dkms/mok.pub 2>&1 || true)"
    if grep -qi 'already enrolled' <<<"$mok"; then
        ok "Secure Boot: llave DKMS enrolada"; rm -f "$HOME/.local/state/loq-dots/mok-pendiente"
    else
        printf '\033[1;31m xx\033[0m %s\n' "Secure Boot: la llave DKMS NO está enrolada (sudo mokutil --import /var/lib/dkms/mok.pub y reinicia)"
        FALLOS=$((FALLOS + 1))
    fi
fi
command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null | sed 's/^/     /'

info "Hardware del LOQ"
chequeo "Wi-Fi (rtw89_8852be)"            grep -q '^rtw89_8852be' /proc/modules
chequeo "NetworkManager maneja el Wi-Fi"  sh -c 'nmcli -t -f TYPE,STATE device | grep -q "^wifi:connected"'
chequeo "Bluetooth"                       sh -c 'bluetoothctl list | grep -q Controller'
chequeo "Audio (PipeWire)"                sh -c 'pactl info | grep -q PipeWire'
chequeo "Control de brillo"               sh -c 'ls /sys/class/backlight/ | grep -q .'
ls /sys/class/backlight/ 2>/dev/null | sed 's/^/     backlight: /'
chequeo "Modo conservación disponible"    sh -c 'ls /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode'
echo "     suspensión: $(cat /sys/power/mem_sleep 2>/dev/null)"

info "Estética"
chequeo "Poppins"                         sh -c 'fc-list | grep -q Poppins'
chequeo "JetBrainsMono Nerd Font"         sh -c 'fc-list | grep -q "JetBrainsMono Nerd Font"'
chequeo "Symbols Nerd Font"               sh -c 'fc-list | grep -q "Symbols Nerd Font"'
chequeo "Cursor Catppuccin"               test -d "$HOME/.local/share/icons/catppuccin-mocha-dark-cursors"
chequeo "Wallpaper"                       sh -c 'ls "$(xdg-user-dir PICTURES)/Wallpapers/snowcapped-mountains.jpg" || ls ~/Pictures/Wallpapers/snowcapped-mountains.jpg'
chequeo "fish como shell"                 sh -c 'getent passwd "$USER" | grep -q /usr/bin/fish'

echo
if [ "$FALLOS" -eq 0 ]; then
    ok "Todo en orden."
else
    warn "$FALLOS comprobaciones fallaron. Las soluciones están en la sección 'Problemas' del README."
fi
cat <<'EOF'

  Pruebas manuales que faltan:
   - Suspende (cierra la tapa o Super+X > Suspender) y vuelve: la pantalla debe regresar.
   - Teclas de brillo y volumen: deben mostrar el OSD de Noctalia.
   - Monitor externo por HDMI: niri msg outputs
EOF
exit "$FALLOS"
