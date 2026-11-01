#!/usr/bin/env bash
# Paso 1 (root): componentes de Debian y repositorios externos.
#  - Activa contrib, non-free y non-free-firmware (firmware Realtek, NVIDIA).
#  - Noctalia: repo apt oficial de su documentación (pkg.noctalia.dev).
#  - niri: no está en Debian 13; viene del repo DankLinux en openSUSE OBS (igual que el repo de xMane13).
#  - Ambos repos externos quedan "pineados": solo pueden aportar sus propios paquetes,
#    nunca reemplazar una versión de Debian.
set -Eeuo pipefail
source "$REPO_DIR/lib/comun.sh"
export DEBIAN_FRONTEND=noninteractive

COMPONENTES="main contrib non-free non-free-firmware"

info "Componentes de Debian: $COMPONENTES"
# Formato deb822 (debian.sources)
for f in /etc/apt/sources.list.d/*.sources; do
    [ -e "$f" ] || continue
    grep -qE '^URIs:.*(deb|security)\.debian\.org' "$f" || continue
    respaldar "$f"
    sed -i -E "/^Components:/c\\Components: $COMPONENTES" "$f"
    ok "$f"
done
# Formato clásico (sources.list), el que deja el instalador netinst
if [ -f /etc/apt/sources.list ]; then
    respaldar /etc/apt/sources.list
    # La línea del CD/USB de instalación rompe "apt update" cuando quitas el USB
    sed -i -E 's|^(deb(-src)? cdrom:)|# \1|' /etc/apt/sources.list
    awk -v comps="$COMPONENTES" '
        /^deb(-src)? / && /(deb|security)\.debian\.org/ {
            n = split($0, c, " ")
            # deb [opciones] URI suite componentes...
            i = 2; if (c[2] ~ /^\[/) { while (c[i] !~ /\]$/) i++; i++ }
            line = c[1]; for (k = 2; k <= i + 1; k++) line = line " " c[k]
            print line " " comps; next
        }
        { print }' /etc/apt/sources.list > /etc/apt/sources.list.tmp
    mv /etc/apt/sources.list.tmp /etc/apt/sources.list
    grep -E '^deb' /etc/apt/sources.list || true
fi

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl wget gpg pciutils lsb-release

info "Repositorio de Noctalia"
if ! dpkg -s nickh-archive-keyring >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    wget -qO "$tmp/keyring.deb" https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb
    dpkg -i "$tmp/keyring.deb"
    rm -rf "$tmp"
fi
wget -qO /etc/apt/sources.list.d/noctalia-trixie.sources https://pkg.noctalia.dev/deb/noctalia-trixie.sources
rm -f /etc/apt/sources.list.d/noctalia.list   # repo viejo de v4, ya no existe

info "Repositorio DankLinux (niri, xwayland-satellite)"
DANK=https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_13
install -d -m 0755 /etc/apt/keyrings
curl -fsSL "$DANK/Release.key" | gpg --dearmor --yes -o /etc/apt/keyrings/danklinux.gpg
cat > /etc/apt/sources.list.d/danklinux.sources <<EOF
Types: deb
URIs: $DANK/
Suites: /
Signed-By: /etc/apt/keyrings/danklinux.gpg
EOF
rm -f /etc/apt/sources.list.d/danklinux.list

info "Prioridades: los repos externos no pueden reemplazar paquetes de Debian"
install -Dm644 "$REPO_DIR/system/apt/loq-dots-pin" /etc/apt/preferences.d/loq-dots-pin

apt-get update
for p in niri noctalia; do existe_pkg "$p" || die "apt no encuentra '$p' después de agregar los repos. Revisa la salida de 'apt-get update'."; done
ok "niri $(apt-cache policy niri | awk '/Candidate:/ {print $2}'), noctalia $(apt-cache policy noctalia | awk '/Candidate:/ {print $2}')"
