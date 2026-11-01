#!/usr/bin/env bash
# loq-dots: Debian 13 (instalado sin escritorio) -> niri + Noctalia con la estética de amane/suzuha.
# Hecho para el Lenovo LOQ 15ARP9 (Ryzen 5 7235HS + RTX 4050, sin GPU integrada, Secure Boot activo).
#
# Uso (como tu usuario, NO con sudo):
#   ./install.sh               todo: repos, escritorio, NVIDIA, ajustes del LOQ y dots
#   ./install.sh --apps        lo anterior + apps opcionales (pregunta una por una)
#   ./install.sh --sin-nvidia  salta el driver NVIDIA (no recomendado en este equipo)
#   ./install.sh --solo-dots   solo vuelve a copiar la configuración
#   ./install.sh --verificar   revisa que todo funcione (córrelo después de reiniciar)
#   ./install.sh --forzar      repite pasos ya marcados como hechos
#
# Cada paso deja una marca en ~/.local/state/loq-dots/hecho, así que si algo falla
# puedes corregirlo y volver a correr el script: retoma donde se quedó.
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
export REPO_DIR
# shellcheck source=lib/comun.sh
source "$REPO_DIR/lib/comun.sh"

APPS=0 NVIDIA=1 SOLO_DOTS=0 FORZAR=0
for a in "$@"; do
    case "$a" in
        --apps) APPS=1 ;;
        --sin-nvidia) NVIDIA=0 ;;
        --solo-dots) SOLO_DOTS=1 ;;
        --verificar) exec bash "$REPO_DIR/pasos/verificar.sh" ;;
        --forzar) FORZAR=1 ;;
        -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
        *) die "Opción desconocida: $a (usa --help)" ;;
    esac
done

[ "$(id -u)" -ne 0 ] || die "Córrelo como tu usuario normal (sin sudo); el script pide sudo cuando hace falta."
. /etc/os-release
[ "${VERSION_CODENAME:-}" = "trixie" ] || die "Esto es para Debian 13 (trixie); este sistema es: ${PRETTY_NAME:-desconocido}"
[ "$(dpkg --print-architecture)" = "amd64" ] || die "Solo amd64."
command -v sudo >/dev/null && sudo -v 2>/dev/null || die "Tu usuario no puede usar sudo.
  Como root:  apt install sudo && usermod -aG sudo $USER   y vuelve a entrar.
  (Si en el instalador dejas la contraseña de root vacía, Debian te da sudo automáticamente.)"
# Mantener sudo vivo mientras corre el script
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

ESTADO="$HOME/.local/state/loq-dots"
mkdir -p "$ESTADO/hecho"
LOG="$ESTADO/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
info "Registro completo en $LOG"

curl -fsI --max-time 10 https://deb.debian.org >/dev/null 2>&1 || die "Sin internet. Conéctate (el instalador de Debian ya configuró el Wi-Fi) y vuelve a intentar."

# paso <nombre> <script> <root|usuario>
paso() {
    local nombre="$1" script="$2" como="$3"
    if [ -e "$ESTADO/hecho/$nombre" ] && [ "$FORZAR" -eq 0 ]; then
        ok "$nombre (ya hecho; --forzar para repetir)"; return
    fi
    info "Paso: $nombre"
    if [ "$como" = root ]; then
        sudo REPO_DIR="$REPO_DIR" ESTADO="$ESTADO" bash "$REPO_DIR/pasos/$script"
    else
        bash "$REPO_DIR/pasos/$script"
    fi
    date -Is > "$ESTADO/hecho/$nombre"
}

if [ "$SOLO_DOTS" -eq 1 ]; then
    FORZAR=1 paso dots 50-dots.sh usuario
    exit 0
fi

paso repos       10-repos.sh      root
paso escritorio  20-escritorio.sh root
if [ "$NVIDIA" -eq 1 ]; then paso nvidia 30-nvidia.sh root; else warn "Saltando NVIDIA: sin driver no hay escritorio acelerado en este equipo."; fi
paso laptop      40-laptop.sh     root
FORZAR=1 paso dots 50-dots.sh     usuario
if [ "$APPS" -eq 1 ]; then FORZAR=1 paso apps 60-apps.sh usuario; fi

echo
info "Terminado."
if [ -e "$ESTADO/mok-pendiente" ]; then
    cat <<'EOF'

  IMPORTANTE (Secure Boot): al reiniciar aparecerá una pantalla azul (MokManager).
    1. "Enroll MOK"  ->  "Continue"  ->  "Yes"
    2. Escribe la contraseña de un solo uso que pusiste hace un momento
    3. "Reboot"
  Si eliges "Continue boot" sin enrolar, el driver NVIDIA no cargará y no habrá escritorio.
  (Se arregla corriendo:  sudo mokutil --import /var/lib/dkms/mok.pub  y reiniciando.)
EOF
fi
cat <<'EOF'

  Reinicia ahora:   sudo reboot
  Al volver, entra desde la pantalla de login y luego corre:   ./install.sh --verificar
EOF
