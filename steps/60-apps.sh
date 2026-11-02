#!/usr/bin/env bash
# Optional step (user): everyday apps. Asks group by group.
# Based on xMane13's scripts/apps.sh, plus the Linux gaming part.
set -Eeuo pipefail
source "$REPO_DIR/lib/common.sh"

# Shows [y/N] but still takes s (old habit) as yes
ask() { local r; read -r -p "$1 [y/N] " r; [[ "$r" =~ ^[sSyY]$ ]]; }

if ask "Brave?"; then
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
    sudo apt-get update && sudo apt-get install -y brave-browser
fi

if ask "Development tools (gcc, gdb, cmake, clang, python)?"; then
    sudo apt-get install -y build-essential gdb cmake clang python3-venv python3-pip python3-dev
fi

if ask "VS Code?"; then
    tmp="$(mktemp -d)"
    wget -qO "$tmp/code.deb" 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64'
    sudo apt-get install -y "$tmp/code.deb"; rm -rf "$tmp"
fi

if ask "Docker Engine?"; then
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    printf '%s\n' 'Types: deb' 'URIs: https://download.docker.com/linux/debian' 'Suites: trixie' \
        'Components: stable' 'Architectures: amd64' 'Signed-By: /etc/apt/keyrings/docker.asc' \
        | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    warn "The docker group is equivalent to root. If you want it anyway:  sudo usermod -aG docker $USER"
fi

if ask "OBS, mpv, GIMP and utilities?"; then
    sudo apt-get install -y obs-studio obs-plugins mpv gimp p7zip-full
fi

if ask "Flatpak + Spotify, Discord, Obsidian?"; then
    sudo apt-get install -y flatpak
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub com.spotify.Client com.discordapp.Discord md.obsidian.Obsidian
fi

if ask "Games: Steam (Proton), Heroic (Epic/GOG/Amazon) and Greenlight (Xbox Cloud)?"; then
    sudo apt-get install -y flatpak
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub com.heroicgameslauncher.hgl io.github.unknownskl.greenlight
    # Steam needs the 32-bit NVIDIA libraries from the SAME branch as the driver.
    sudo dpkg --add-architecture i386
    sudo apt-get update
    nv="$(dpkg-query -W -f='${Version}' nvidia-driver 2>/dev/null || true)"
    cand="$(apt-cache policy nvidia-driver-libs:i386 2>/dev/null | awk '/Candidate:/ {print $2}')"
    if [ -n "$nv" ] && [ "$cand" = "$nv" ]; then
        sudo apt-get install -y steam-installer "nvidia-driver-libs:i386"
        ok "Steam installed (turn on Proton in Settings > Compatibility)"
    else
        warn "No i386 NVIDIA libraries for version $nv (candidate: ${cand:-none}); not installing Steam to avoid mixing drivers."
        warn "Alternative: Steam as a flatpak (brings its own GL runtime):  flatpak install flathub com.valvesoftware.Steam"
    fi
fi
