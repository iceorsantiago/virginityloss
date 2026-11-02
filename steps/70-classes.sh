#!/usr/bin/env bash
# Optional step (user): everything the classes use. ./install.sh --classes
#  - Node 24 LTS with fnm + pnpm (Expo 58 / React Native 0.88 / pnpm 11 / Electron 45 need Node >= 22.13;
#    Debian 13's nodejs is 20.19)
#  - Typst and LaTeX (reports), PostgreSQL/MySQL/SQLite clients, Java (SQL Power Architect)
#  - Networking: Wireshark (without root, wireshark group), nmap, picocom (Raspberry Pi serial console)
#  - Microsoft Edge: the Workshop 5 capture scripts use Playwright with channel="msedge"
#  - Firewall: Metro (Expo Go on the phone) on port 8081, only from private networks
#  - Cisco Packet Tracer: installed if its .deb is in ~/Downloads (download it from NetAcad with your account)
set -Eeuo pipefail
source "$REPO_DIR/lib/common.sh"

# Shows [y/N] but still takes s (old habit) as yes
ask() { local r; read -r -p "$1 [y/N] " r; [[ "$r" =~ ^[sSyY]$ ]]; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
BIN="$HOME/.local/bin"; mkdir -p "$BIN"

FNM=https://github.com/Schniz/fnm/releases/download/v1.39.0/fnm-linux.zip
TYPST=https://github.com/typst/typst/releases/download/v0.15.1/typst-x86_64-unknown-linux-musl.tar.xz

info "Debian packages"
echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wireshark tshark nmap picocom \
    postgresql-client default-mysql-client sqlite3 default-jre \
    latexmk texlive-latex-extra texlive-lang-spanish texlive-fonts-recommended texlive-science
sudo usermod -aG wireshark "$USER"
ok "Wireshark without sudo (applies after logging in again)"

info "Microsoft Edge"
if ! command -v microsoft-edge-stable >/dev/null; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/microsoft-edge.gpg
    # Same file the Edge package maintains, so the repo doesn't end up duplicated
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge stable main" \
        | sudo tee /etc/apt/sources.list.d/microsoft-edge.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y microsoft-edge-stable
fi
ok "Edge $(microsoft-edge-stable --version 2>/dev/null || echo '?')"

info "Node 24 LTS (fnm) and pnpm"
if [ ! -x "$BIN/fnm" ]; then
    download "$FNM" "$TMP/fnm.zip" 7807664f39d39fc518da1c35ba0181e4b3267603c4b1dedeb4b5fc6ae440a224 || die "Couldn't download fnm"
    unzip -q -o "$TMP/fnm.zip" -d "$TMP" && install -m755 "$TMP/fnm" "$BIN/fnm"
fi
"$BIN/fnm" install 24
"$BIN/fnm" default 24
"$BIN/fnm" exec --using=24 corepack enable --install-directory "$BIN"
ok "node $("$BIN/fnm" exec --using=24 node -v), pnpm via corepack"

info "Typst"
if [ ! -x "$BIN/typst" ]; then
    download "$TYPST" "$TMP/typst.tar.xz" a6d077d0a95eed5a2eba715b2dae06be954f624ccbf85758a03f389ded33118c || die "Couldn't download Typst"
    tar -xJf "$TMP/typst.tar.xz" -C "$TMP" && install -m755 "$TMP"/typst-*/typst "$BIN/typst"
fi
ok "$("$BIN/typst" --version)"

info "Firewall: Expo Go (Metro, port 8081) from private networks"
for net in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
    sudo ufw allow from "$net" to any port 8081 proto tcp comment 'Expo Metro' >/dev/null
done
ok "ufw: 8081/tcp allowed from the local network"

info "Cisco Packet Tracer"
PT="$(ls -t "$HOME"/Downloads/CiscoPacketTracer*.deb 2>/dev/null | head -n1 || true)"
if [ -n "$PT" ]; then
    sudo apt-get install -y "$PT" && ok "Packet Tracer installed from $PT"
else
    warn "Download the Packet Tracer .deb (Ubuntu 64-bit) from netacad.com to ~/Downloads and run ./install.sh --classes again"
fi

if ! id -nG "$USER" | grep -qw docker && ask "Use Docker without sudo (docker group, equivalent to root)?"; then
    sudo usermod -aG docker "$USER"
    ok "docker group (applies after logging in again)"
fi

echo
info "Done. Log out and back in so the groups (wireshark, docker) apply."
