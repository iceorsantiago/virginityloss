#!/usr/bin/env bash
# Paso opcional (usuario): apps del día a día. Pregunta grupo por grupo.
# Basado en scripts/apps.sh de xMane13, más la parte de juegos para Linux.
set -Eeuo pipefail
source "$REPO_DIR/lib/comun.sh"

pregunta() { local r; read -r -p "$1 [s/N] " r; [[ "$r" =~ ^[sSyY]$ ]]; }

if pregunta "¿Brave?"; then
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
    sudo apt-get update && sudo apt-get install -y brave-browser
fi

if pregunta "¿Herramientas de desarrollo (gcc, gdb, cmake, clang, python)?"; then
    sudo apt-get install -y build-essential gdb cmake clang python3-venv python3-pip python3-dev
fi

if pregunta "¿VS Code?"; then
    tmp="$(mktemp -d)"
    wget -qO "$tmp/code.deb" 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64'
    sudo apt-get install -y "$tmp/code.deb"; rm -rf "$tmp"
fi

if pregunta "¿Docker Engine?"; then
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    printf '%s\n' 'Types: deb' 'URIs: https://download.docker.com/linux/debian' 'Suites: trixie' \
        'Components: stable' 'Architectures: amd64' 'Signed-By: /etc/apt/keyrings/docker.asc' \
        | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    warn "El grupo docker equivale a root. Si lo quieres igual:  sudo usermod -aG docker $USER"
fi

if pregunta "¿OBS, mpv, GIMP y utilidades?"; then
    sudo apt-get install -y obs-studio obs-plugins mpv gimp p7zip-full
fi

if pregunta "¿Flatpak + Spotify, Discord, Obsidian?"; then
    sudo apt-get install -y flatpak
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub com.spotify.Client com.discordapp.Discord md.obsidian.Obsidian
fi

if pregunta "¿Juegos: Steam (Proton), Heroic (Epic/GOG/Amazon) y Greenlight (Xbox Cloud)?"; then
    sudo apt-get install -y flatpak
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub com.heroicgameslauncher.hgl io.github.unknownskl.greenlight
    # Steam necesita las librerías NVIDIA de 32 bits de la MISMA rama que el driver.
    sudo dpkg --add-architecture i386
    sudo apt-get update
    nv="$(dpkg-query -W -f='${Version}' nvidia-driver 2>/dev/null || true)"
    cand="$(apt-cache policy nvidia-driver-libs:i386 2>/dev/null | awk '/Candidate:/ {print $2}')"
    if [ -n "$nv" ] && [ "$cand" = "$nv" ]; then
        sudo apt-get install -y steam-installer "nvidia-driver-libs:i386"
        ok "Steam instalado (activa Proton en Ajustes > Compatibilidad)"
    else
        warn "No hay librerías NVIDIA i386 de la versión $nv (candidato: ${cand:-ninguno}); no instalo Steam para no mezclar drivers."
        warn "Alternativa: Steam en flatpak (trae su propio runtime GL):  flatpak install flathub com.valvesoftware.Steam"
    fi
fi
