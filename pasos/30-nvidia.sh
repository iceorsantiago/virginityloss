#!/usr/bin/env bash
# Paso 3 (root): driver NVIDIA para la RTX 4050 (AD107, 10de:28e1).
#
# Por qué el repo de NVIDIA y no el de Debian:
#  - El nvidia-driver de Debian 13 es la rama 550: la wiki de Debian la marca sin mantenimiento,
#    su versión "open" ya no compila en el kernel actual de trixie y no llega a CUDA 13,
#    así que no corre el PyTorch actual (pide driver >= 580).
#  - El repo debian13 de NVIDIA trae ramas 595+ con módulos "open" (recomendados para Ada).
#  - Se fija UNA rama (pinning) para que apt no salte de versión mayor solo.
#  - Nunca se mezclan paquetes NVIDIA de Debian con los de NVIDIA, ni el instalador .run.
#
# Este equipo NO tiene GPU integrada: si el módulo no carga, no hay escritorio.
# Por eso Secure Boot se maneja aquí (llave MOK de DKMS) antes de instalar el driver.
set -Eeuo pipefail
source "$REPO_DIR/lib/comun.sh"
export DEBIAN_FRONTEND=noninteractive
RAMA="${NVIDIA_RAMA:-595}"
REPO_NV=https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64

info "GPU"
lspci -nn | grep -iE 'vga|3d|display' || true
lspci -nn | grep -i '10de:' >/dev/null || die "No veo una GPU NVIDIA. Corre con --sin-nvidia si es otro equipo."

# No mezclar con los paquetes NVIDIA de Debian
if dpkg -l 'nvidia-*' 2>/dev/null | awk '/^ii/ {print $2"="$3}' | grep -E '=550\.' >/dev/null; then
    die "Hay paquetes NVIDIA 550 de Debian instalados. Quítalos primero:
  sudo apt purge 'nvidia-*' 'libnvidia-*' && sudo apt autoremove"
fi

info "Headers del kernel, DKMS y herramientas de Secure Boot"
apt-get install -y --no-install-recommends linux-headers-amd64 "linux-headers-$(uname -r)" dkms mokutil openssl build-essential

SB=0
if mokutil --sb-state 2>/dev/null | grep -i 'enabled' >/dev/null; then SB=1; fi
if [ "$SB" -eq 1 ]; then
    info "Secure Boot activo: preparando la llave con la que DKMS firma los módulos"
    if [ ! -f /var/lib/dkms/mok.pub ]; then
        dkms generate_mok
    fi
    ok "/var/lib/dkms/mok.pub"
else
    ok "Secure Boot desactivado: no hace falta firmar"
fi

info "Repositorio de NVIDIA (debian13) y rama $RAMA"
if ! dpkg -s cuda-keyring >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    wget -qO "$tmp/cuda-keyring.deb" "$REPO_NV/cuda-keyring_1.1-1_all.deb"
    dpkg -i "$tmp/cuda-keyring.deb"
    rm -rf "$tmp"
fi
apt-get update
if existe_pkg "nvidia-driver-pinning-$RAMA"; then
    apt-get install -y "nvidia-driver-pinning-$RAMA"
else
    warn "No existe nvidia-driver-pinning-$RAMA; se instala la rama más nueva sin fijar. Ramas disponibles:"
    apt-cache search --names-only '^nvidia-driver-pinning-' || true
fi

info "Driver (módulos open)"
apt-get install -y nvidia-open

info "Opciones del módulo"
install -Dm644 "$REPO_DIR/system/modprobe/nvidia-loq.conf" /etc/modprobe.d/nvidia-loq.conf
# niri: evita que el driver retenga ~1 GB de VRAM extra (recomendación de la wiki de niri para NVIDIA)
install -Dm644 "$REPO_DIR/system/nvidia/50-limit-free-buffer-pool-in-wayland-compositors.json" \
    /etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json

info "Parámetros de arranque (GRUB, archivo aparte para no tocar /etc/default/grub)"
install -Dm644 "$REPO_DIR/system/grub/90-loq-nvidia.cfg" /etc/default/grub.d/90-loq-nvidia.cfg

info "Suspensión: servicios de NVIDIA que guardan la VRAM"
for s in nvidia-suspend nvidia-resume nvidia-hibernate; do
    systemctl list-unit-files "$s.service" >/dev/null 2>&1 && systemctl enable "$s.service" || warn "no existe $s.service"
done

update-initramfs -u -k all
update-grub

info "Comprobando la compilación del módulo"
dkms status | grep -i nvidia || die "DKMS no muestra el módulo nvidia. Revisa: sudo dkms status && sudo dkms autoinstall"
if [ "$SB" -eq 1 ]; then
    # Sin pipe: con pipefail el código de salida de mokutil haría fallar la prueba aunque la llave esté
    mok="$(mokutil --test-key /var/lib/dkms/mok.pub 2>&1 || true)"
    if grep -qi 'already enrolled' <<<"$mok"; then
        ok "La llave MOK ya está enrolada"
        rm -f "${ESTADO:-/tmp}/mok-pendiente"
    else
        cat <<'EOF'

  Ahora pon una contraseña de un solo uso (mínimo 8 caracteres) para enrolar la llave.
  Te la pedirá UNA vez la pantalla azul de MokManager al reiniciar. Anótala.
EOF
        mokutil --import /var/lib/dkms/mok.pub
        touch "${ESTADO:-/tmp}/mok-pendiente"
        chown "${SUDO_USER:-root}:" "${ESTADO:-/tmp}/mok-pendiente" 2>/dev/null || true
    fi
fi
ok "NVIDIA listo (se activa al reiniciar)"
