#!/usr/bin/env bash
# Paso opcional (usuario): todo lo que usan las clases. ./install.sh --clases
#  - Node 24 LTS con fnm + pnpm (Expo 58 / React Native 0.88 / pnpm 11 / Electron 45 piden Node >= 22.13;
#    el nodejs de Debian 13 es 20.19)
#  - Typst y LaTeX (informes), clientes de PostgreSQL/MySQL/SQLite, Java (SQL Power Architect)
#  - Redes: Wireshark (sin root, grupo wireshark), nmap, picocom (consola serie de la Raspberry Pi)
#  - Microsoft Edge: los scripts de captura de Workshop 5 usan Playwright con channel="msedge"
#  - Firewall: Metro (Expo Go en el celular) en el puerto 8081, solo desde redes privadas
#  - Cisco Packet Tracer: se instala si su .deb está en ~/Downloads (se baja de NetAcad con tu cuenta)
set -Eeuo pipefail
source "$REPO_DIR/lib/comun.sh"

pregunta() { local r; read -r -p "$1 [s/N] " r; [[ "$r" =~ ^[sSyY]$ ]]; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
BIN="$HOME/.local/bin"; mkdir -p "$BIN"

FNM=https://github.com/Schniz/fnm/releases/download/v1.39.0/fnm-linux.zip
TYPST=https://github.com/typst/typst/releases/download/v0.15.1/typst-x86_64-unknown-linux-musl.tar.xz

info "Paquetes de Debian"
echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wireshark tshark nmap picocom \
    postgresql-client default-mysql-client sqlite3 default-jre \
    latexmk texlive-latex-extra texlive-lang-spanish texlive-fonts-recommended texlive-science
sudo usermod -aG wireshark "$USER"
ok "Wireshark sin sudo (aplica al volver a entrar)"

info "Microsoft Edge"
if ! command -v microsoft-edge-stable >/dev/null; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/microsoft-edge.gpg
    # Mismo archivo que mantiene el paquete de Edge, así no queda el repo duplicado
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge stable main" \
        | sudo tee /etc/apt/sources.list.d/microsoft-edge.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y microsoft-edge-stable
fi
ok "Edge $(microsoft-edge-stable --version 2>/dev/null || echo '?')"

info "Node 24 LTS (fnm) y pnpm"
if [ ! -x "$BIN/fnm" ]; then
    bajar "$FNM" "$TMP/fnm.zip" 7807664f39d39fc518da1c35ba0181e4b3267603c4b1dedeb4b5fc6ae440a224 || die "No se pudo bajar fnm"
    unzip -q -o "$TMP/fnm.zip" -d "$TMP" && install -m755 "$TMP/fnm" "$BIN/fnm"
fi
"$BIN/fnm" install 24
"$BIN/fnm" default 24
"$BIN/fnm" exec --using=24 corepack enable --install-directory "$BIN"
ok "node $("$BIN/fnm" exec --using=24 node -v), pnpm vía corepack"

info "Typst"
if [ ! -x "$BIN/typst" ]; then
    bajar "$TYPST" "$TMP/typst.tar.xz" a6d077d0a95eed5a2eba715b2dae06be954f624ccbf85758a03f389ded33118c || die "No se pudo bajar Typst"
    tar -xJf "$TMP/typst.tar.xz" -C "$TMP" && install -m755 "$TMP"/typst-*/typst "$BIN/typst"
fi
ok "$("$BIN/typst" --version)"

info "Firewall: Expo Go (Metro, puerto 8081) desde redes privadas"
for red in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
    sudo ufw allow from "$red" to any port 8081 proto tcp comment 'Expo Metro' >/dev/null
done
ok "ufw: 8081/tcp permitido desde la red local"

info "Cisco Packet Tracer"
PT="$(ls -t "$HOME"/Downloads/CiscoPacketTracer*.deb 2>/dev/null | head -n1 || true)"
if [ -n "$PT" ]; then
    sudo apt-get install -y "$PT" && ok "Packet Tracer instalado desde $PT"
else
    warn "Baja el .deb de Packet Tracer (Ubuntu 64-bit) desde netacad.com a ~/Downloads y vuelve a correr ./install.sh --clases"
fi

if ! id -nG "$USER" | grep -qw docker && pregunta "¿Usar Docker sin sudo (grupo docker, equivale a root)?"; then
    sudo usermod -aG docker "$USER"
    ok "Grupo docker (aplica al volver a entrar)"
fi

echo
info "Listo. Cierra sesión y vuelve a entrar para que apliquen los grupos (wireshark, docker)."
