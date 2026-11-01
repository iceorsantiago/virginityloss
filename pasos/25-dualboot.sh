#!/usr/bin/env bash
# Paso 2b (root): convivir con Windows en el mismo disco.
#  - Si encuentra el gestor de arranque de Windows en la partición EFI, activa os-prober para que
#    "Windows Boot Manager" siga en el menú de GRUB cada vez que se regenera (el paso NVIDIA lo hace).
#  - Debian queda como opción por defecto; 5 s para elegir.
#  - Soporte para abrir los discos NTFS de Windows (el SSD externo D:) desde el gestor de archivos.
# Sin Windows, solo instala el soporte NTFS y no toca GRUB.
set -Eeuo pipefail
source "$REPO_DIR/lib/comun.sh"
export DEBIAN_FRONTEND=noninteractive

info "Discos NTFS (D: con los juegos y el backup)"
instalar_opcionales udisks2 gvfs gvfs-backends gvfs-fuse ntfs-3g

WIN=""
for f in /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi /boot/efi/EFI/microsoft/boot/bootmgfw.efi; do
    [ -f "$f" ] && WIN="$f"
done
if [ -z "$WIN" ]; then
    ok "No encontré Windows en la partición EFI: sin cambios en GRUB"
    exit 0
fi

info "Windows detectado ($WIN): manteniéndolo en el menú de GRUB"
apt-get install -y --no-install-recommends os-prober
install -Dm644 "$REPO_DIR/system/grub/91-loq-dualboot.cfg" /etc/default/grub.d/91-loq-dualboot.cfg
update-grub
if grep -q 'Windows Boot Manager' /boot/grub/grub.cfg; then
    ok "Entrada de Windows presente en /boot/grub/grub.cfg"
else
    warn "GRUB no agregó Windows. Puedes entrar igual con F12 al encender, y revisar con: sudo os-prober"
fi

cat <<'EOF'

  Hora: Windows guarda el reloj en hora local y Linux en UTC, así que uno de los dos se
  desfasa. La solución va del lado de Windows (una vez, como administrador):
      windows/hora-utc.reg   (doble clic)   o en PowerShell admin:
      reg add HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
EOF
