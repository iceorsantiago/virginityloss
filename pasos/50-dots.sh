#!/usr/bin/env bash
# Paso 5 (usuario): la estética de amane/suzuha.
#  - Fuentes: Poppins (UI), JetBrainsMono Nerd Font (terminal), Symbols Nerd Font (iconos)
#  - Cursor Catppuccin Mocha Dark, tema GTK oscuro, iconos Papirus-Dark
#  - Wallpaper del repo amane (se descarga, no se redistribuye)
#  - Copia config/ a ~/.config con respaldo, valida niri y Noctalia y corrige lo que no pase
# Todas las descargas están fijadas a una versión y se comprueba su SHA-256.
set -Eeuo pipefail
source "$REPO_DIR/lib/comun.sh"

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
FUENTES="$HOME/.local/share/fonts"
ICONOS="$HOME/.local/share/icons"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

GF=https://raw.githubusercontent.com/google/fonts/8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/ofl/poppins
NF=https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1
CUR=https://github.com/catppuccin/cursors/releases/download/v2.0.0/catppuccin-mocha-dark-cursors.zip
WP=https://raw.githubusercontent.com/MystiaFin/amane/544cbfc23af37f84ac237cd9bec53173981772b3/examples/wallpaper.png

info "Fuentes"
mkdir -p "$FUENTES/Poppins" "$FUENTES/JetBrainsMonoNF" "$FUENTES/SymbolsNF"
while read -r sha f; do
    [ -s "$FUENTES/Poppins/$f" ] || bajar "$GF/$f" "$FUENTES/Poppins/$f" "$sha" || warn "No se pudo bajar $f"
done <<'EOF'
7e65201e9b79159e2300267cc885e16c8dcef2424cdfa09a29bfb0980a94a7ba Poppins-Regular.ttf
90373e7d838d32468438fc3e152dca0bdb12edcab99ea639f158790b1ba1fd05 Poppins-Medium.ttf
d3bf1bdaf0550e83da9ac0b1d1d9fe6db086835a83aa28578e609a394b9a0286 Poppins-SemiBold.ttf
983676516167748b74de6f4771fb384c664fd913acb8b471122ecacf5da5ea6c Poppins-Bold.ttf
EOF
if ! fc-list | grep "JetBrainsMono Nerd Font" >/dev/null; then
    bajar "$NF/JetBrainsMono.tar.xz" "$TMP/jbm.tar.xz" 04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf \
        && tar -xJf "$TMP/jbm.tar.xz" -C "$FUENTES/JetBrainsMonoNF" --wildcards '*.ttf' \
        || warn "Sin JetBrainsMono Nerd Font: los iconos de la terminal se verán como cuadros"
fi
if ! fc-list | grep "Symbols Nerd Font" >/dev/null; then
    bajar "$NF/NerdFontsSymbolsOnly.tar.xz" "$TMP/sym.tar.xz" 01172f37db8543edb102e5cb5c64101c9f4686630804d49b419aa07b23a69996 \
        && tar -xJf "$TMP/sym.tar.xz" -C "$FUENTES/SymbolsNF" --wildcards '*.ttf' \
        || warn "Sin Symbols Nerd Font"
fi
fc-cache -f >/dev/null
fc-list | grep Poppins >/dev/null && ok "Poppins" || warn "Poppins no quedó instalada"

info "Cursor Catppuccin Mocha Dark"
if [ ! -d "$ICONOS/catppuccin-mocha-dark-cursors" ]; then
    mkdir -p "$ICONOS"
    bajar "$CUR" "$TMP/cur.zip" a4d976491bdb1b1311b2de88327cad3f1c66c2d9da896e0c56362a660c802585 \
        && unzip -q "$TMP/cur.zip" -d "$ICONOS" \
        || warn "No se pudo instalar el cursor"
fi
# Algunas apps X11 leen el cursor de aquí
mkdir -p "$ICONOS/default"
printf '[Icon Theme]\nInherits=catppuccin-mocha-dark-cursors\n' > "$ICONOS/default/index.theme"

info "Wallpaper"
IMAGENES="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
[ "$IMAGENES" != "$HOME" ] || IMAGENES="$HOME/Pictures"
WALLS="$IMAGENES/Wallpapers"
mkdir -p "$WALLS" "$HOME/Pictures/Screenshots"
[ -s "$WALLS/amane.png" ] || bajar "$WP" "$WALLS/amane.png" 65de98d08676cd84fbb22ee0a7439db83a438d504fa5c0f7296a1c3b7d71f163 \
    || warn "No se pudo bajar el wallpaper; elige otro desde Noctalia (Super+Shift+W)"

info "Copiando config/ a $CFG"
BACKUP="$CFG/loq-dots-respaldo-$(date +%Y%m%d-%H%M%S)"
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
[ -d "$BACKUP" ] && ok "Tus archivos anteriores quedaron en $BACKUP"

# Rutas reales del wallpaper (la carpeta de Imágenes cambia con el idioma)
sed -i -e "s|@WALLPAPERS@|$WALLS|g" -e "s|@WALLPAPER@|$WALLS/amane.png|g" "$CFG/noctalia/config.toml"

info "Validando niri"
if command -v niri >/dev/null; then
    if niri validate -c "$CFG/niri/config.kdl" >/dev/null 2>&1; then
        ok "niri: config válida"
    else
        warn "niri rechazó la config; probando sin el bloque de blur (requiere niri >= 26.04)"
        sed -i '/>>> blur/,/<<< blur/d' "$CFG/niri/config.kdl"
        niri validate -c "$CFG/niri/config.kdl" && ok "niri: válida sin blur" \
            || warn "niri sigue con errores. Míralos con:  niri validate"
    fi
fi

info "Validando Noctalia"
if command -v noctalia >/dev/null; then
    if noctalia config validate "$CFG/noctalia" >"$TMP/noct.txt" 2>&1; then
        ok "Noctalia: config válida"
    else
        cat "$TMP/noct.txt"
        if grep -qiE 'palette|custom|theme' "$TMP/noct.txt"; then
            warn "La paleta propia no pasó; uso la paleta Catppuccin integrada de Noctalia"
            sed -i -e 's|^source *= *"custom"|source = "builtin"|' -e 's|^custom_palette *=.*|builtin = "Catppuccin"|' "$CFG/noctalia/config.toml"
            noctalia config validate "$CFG/noctalia" && ok "Noctalia: válida con Catppuccin integrada" \
                || warn "Noctalia sigue con avisos; ábrela y revisa Ajustes (Super+N)"
        else
            warn "Noctalia marcó problemas (arriba). Normalmente son avisos y arranca igual."
        fi
    fi
fi

info "Tema de apps GTK, fuentes y cursor"
gs() { if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then gsettings "$@"; else dbus-run-session gsettings "$@"; fi; }
gs set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
dpkg -s adw-gtk3 >/dev/null 2>&1 && gs set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' || true
dpkg -s papirus-icon-theme >/dev/null 2>&1 && gs set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
gs set org.gnome.desktop.interface font-name 'Poppins 11' || true
gs set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11' || true
gs set org.gnome.desktop.interface cursor-theme 'catppuccin-mocha-dark-cursors' || true
gs set org.gnome.desktop.interface cursor-size 24 || true

info "fish como shell"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/fish" ] && [ -x /usr/bin/fish ]; then
    sudo chsh -s /usr/bin/fish "$USER" && ok "fish es tu shell (aplica al volver a entrar)"
fi
