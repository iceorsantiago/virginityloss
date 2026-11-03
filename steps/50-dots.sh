#!/usr/bin/env bash
# Step 5 (user): the amane/suzuha look.
#  - Fonts: Poppins (UI), JetBrainsMono Nerd Font (terminal), Symbols Nerd Font (icons)
#  - Catppuccin Mocha Dark cursor, dark GTK theme, Papirus-Dark icons
#  - Wallpapers: snowcapped-mountains (ML4W, the r/unixporn one, default) and amane's
#    (downloaded, not redistributed)
#  - Copies config/ to ~/.config with a backup, validates niri and Noctalia and fixes what fails
# Every download is pinned to a version and its SHA-256 is checked.
set -Eeuo pipefail
source "$REPO_DIR/lib/common.sh"

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
FONTS_DIR="$HOME/.local/share/fonts"
ICONS_DIR="$HOME/.local/share/icons"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

GF=https://raw.githubusercontent.com/google/fonts/8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/ofl/poppins
NF=https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1
CUR=https://github.com/catppuccin/cursors/releases/download/v2.0.0/catppuccin-mocha-dark-cursors.zip
WP=https://raw.githubusercontent.com/MystiaFin/amane/544cbfc23af37f84ac237cd9bec53173981772b3/examples/wallpaper.png
WP_SNOW=https://raw.githubusercontent.com/mylinuxforwork/wallpaper/3d2ff28d8326793f21ce8344707ce56396b81cb5/snowcapped-mountains.jpg

info "Fonts"
mkdir -p "$FONTS_DIR/Poppins" "$FONTS_DIR/JetBrainsMonoNF" "$FONTS_DIR/SymbolsNF"
while read -r sha f; do
    [ -s "$FONTS_DIR/Poppins/$f" ] || download "$GF/$f" "$FONTS_DIR/Poppins/$f" "$sha" || warn "Couldn't download $f"
done <<'EOF'
7e65201e9b79159e2300267cc885e16c8dcef2424cdfa09a29bfb0980a94a7ba Poppins-Regular.ttf
90373e7d838d32468438fc3e152dca0bdb12edcab99ea639f158790b1ba1fd05 Poppins-Medium.ttf
d3bf1bdaf0550e83da9ac0b1d1d9fe6db086835a83aa28578e609a394b9a0286 Poppins-SemiBold.ttf
983676516167748b74de6f4771fb384c664fd913acb8b471122ecacf5da5ea6c Poppins-Bold.ttf
EOF
if ! fc-list | grep "JetBrainsMono Nerd Font" >/dev/null; then
    download "$NF/JetBrainsMono.tar.xz" "$TMP/jbm.tar.xz" 04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf \
        && tar -xJf "$TMP/jbm.tar.xz" -C "$FONTS_DIR/JetBrainsMonoNF" --wildcards '*.ttf' \
        || warn "No JetBrainsMono Nerd Font: terminal icons will show up as boxes"
fi
if ! fc-list | grep "Symbols Nerd Font" >/dev/null; then
    download "$NF/NerdFontsSymbolsOnly.tar.xz" "$TMP/sym.tar.xz" 01172f37db8543edb102e5cb5c64101c9f4686630804d49b419aa07b23a69996 \
        && tar -xJf "$TMP/sym.tar.xz" -C "$FONTS_DIR/SymbolsNF" --wildcards '*.ttf' \
        || warn "No Symbols Nerd Font"
fi
fc-cache -f >/dev/null
fc-list | grep Poppins >/dev/null && ok "Poppins" || warn "Poppins didn't get installed"

info "Catppuccin Mocha Dark cursor"
if [ ! -d "$ICONS_DIR/catppuccin-mocha-dark-cursors" ]; then
    mkdir -p "$ICONS_DIR"
    download "$CUR" "$TMP/cur.zip" a4d976491bdb1b1311b2de88327cad3f1c66c2d9da896e0c56362a660c802585 \
        && unzip -q "$TMP/cur.zip" -d "$ICONS_DIR" \
        || warn "Couldn't install the cursor"
fi
# Some X11 apps read the cursor from here
mkdir -p "$ICONS_DIR/default"
printf '[Icon Theme]\nInherits=catppuccin-mocha-dark-cursors\n' > "$ICONS_DIR/default/index.theme"

info "Wallpaper"
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
[ "$PICTURES_DIR" != "$HOME" ] || PICTURES_DIR="$HOME/Pictures"
WALLS="$PICTURES_DIR/Wallpapers"
mkdir -p "$WALLS" "$HOME/Pictures/Screenshots"
[ -s "$WALLS/snowcapped-mountains.jpg" ] || download "$WP_SNOW" "$WALLS/snowcapped-mountains.jpg" 19c29e7af97d254cc39f369ecf1520a9153bc67b32b9d5cce3fe1fa0eb7c18b1 \
    || warn "Couldn't download the wallpaper; pick another one from Noctalia (Super+Shift+W)"
[ -s "$WALLS/amane.png" ] || download "$WP" "$WALLS/amane.png" 65de98d08676cd84fbb22ee0a7439db83a438d504fa5c0f7296a1c3b7d71f163 \
    || warn "Couldn't download the amane wallpaper (optional)"

info "Copying config/ to $CFG"
BACKUP="$CFG/loq-dots-backup-$(date +%Y%m%d-%H%M%S)"
cd "$REPO_DIR/config"
find . -type f | sed 's|^\./||' | sort | while read -r f; do
    if [ -e "$CFG/$f" ] && ! cmp -s "$f" "$CFG/$f"; then
        mkdir -p "$BACKUP/$(dirname "$f")"
        cp -a "$CFG/$f" "$BACKUP/$f"
    fi
    mkdir -p "$CFG/$(dirname "$f")"
    cp "$f" "$CFG/$f"
    echo "   $f"
done
[ -d "$BACKUP" ] && ok "Your previous files are in $BACKUP"

# Ollama (the local AI for Guess Who's Back) as a user service, when it is installed in ~/.local/opt/ollama.
# Not started at login: Guess Who's Back starts it when it opens and stops it when it closes, so the model
# only holds VRAM while the app is open. (`systemctl --user enable --now ollama` keeps it always on instead.)
systemctl --user daemon-reload || true
if [ -x "$HOME/.local/opt/ollama/bin/ollama" ]; then
    systemctl --user disable ollama.service >/dev/null 2>&1 || true
    ok "Ollama service installed (started and stopped by Guess Who's Back)"
    ln -sfn "$HOME/.local/opt/ollama/bin/ollama" "$HOME/.local/bin/ollama"
fi

# Real wallpaper paths (the Pictures folder name changes with the language)
sed -i -e "s|@WALLPAPERS@|$WALLS|g" -e "s|@WALLPAPER@|$WALLS/snowcapped-mountains.jpg|g" "$CFG/noctalia/config.toml"

info "Validating niri"
if command -v niri >/dev/null; then
    if niri validate -c "$CFG/niri/config.kdl" >/dev/null 2>&1; then
        ok "niri: config is valid"
    else
        warn "niri rejected the config; trying without the blur block (needs niri >= 26.04)"
        sed -i '/>>> blur/,/<<< blur/d' "$CFG/niri/config.kdl"
        niri validate -c "$CFG/niri/config.kdl" && ok "niri: valid without blur" \
            || warn "niri still has errors. See them with:  niri validate"
    fi
fi

info "Validating Noctalia"
if command -v noctalia >/dev/null; then
    if noctalia config validate "$CFG/noctalia" >"$TMP/noct.txt" 2>&1; then
        ok "Noctalia: config is valid"
    else
        cat "$TMP/noct.txt"
        if grep -qiE 'palette|custom|theme' "$TMP/noct.txt"; then
            warn "The custom palette didn't pass; using Noctalia's built-in Catppuccin palette"
            sed -i -e 's|^source *= *"custom"|source = "builtin"|' -e 's|^custom_palette *=.*|builtin = "Catppuccin"|' "$CFG/noctalia/config.toml"
            noctalia config validate "$CFG/noctalia" && ok "Noctalia: valid with built-in Catppuccin" \
                || warn "Noctalia still has warnings; open it and check Settings (Super+N)"
        else
            warn "Noctalia reported problems (above). They're usually warnings and it starts anyway."
        fi
    fi
fi

info "GTK app theme, fonts and cursor"
gs() { if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then gsettings "$@"; else dbus-run-session gsettings "$@"; fi; }
gs set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
dpkg -s adw-gtk3 >/dev/null 2>&1 && gs set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' || true
dpkg -s papirus-icon-theme >/dev/null 2>&1 && gs set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
gs set org.gnome.desktop.interface font-name 'Poppins 11' || true
gs set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11' || true
gs set org.gnome.desktop.interface cursor-theme 'catppuccin-mocha-dark-cursors' || true
gs set org.gnome.desktop.interface cursor-size 24 || true

info "fish as the shell"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/fish" ] && [ -x /usr/bin/fish ]; then
    sudo chsh -s /usr/bin/fish "$USER" && ok "fish is your shell (applies after logging in again)"
fi

info "Desktop panel (Conky: RAM, VRAM, GPU, weather)"
chmod +x "$CFG/conky/"*.sh 2>/dev/null || true
if command -v conky >/dev/null; then
    systemctl --user daemon-reload
    systemctl --user enable conky.service && ok "conky starts with the desktop"
else
    warn "conky isn't installed yet (./install.sh --classes installs it)"
fi

info "Echo Dot keepalive (reconnects the speaker as the audio output, also after reboots)"
# Needs steps/40-laptop.sh too (Classic-only Bluetooth); see config/bluetooth/echo-keepalive.sh.
chmod +x "$CFG/bluetooth/echo-keepalive.sh" 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable echo-keepalive.service && ok "echo-keepalive starts with the desktop"
