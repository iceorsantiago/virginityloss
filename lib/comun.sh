# Funciones compartidas por install.sh y los pasos. Se carga con `source`.

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m xx\033[0m %s\n' "$*" >&2; exit 1; }

# Descarga $1 a $2 y comprueba su SHA-256 ($3). Falla si no coincide.
bajar() {
    local url="$1" dest="$2" sha="$3"
    curl -fsSL --retry 3 -o "$dest.part" "$url" || { rm -f "$dest.part"; return 1; }
    if ! echo "$sha  $dest.part" | sha256sum -c --quiet - >/dev/null 2>&1; then
        rm -f "$dest.part"
        warn "SHA-256 no coincide: $url"
        return 1
    fi
    mv "$dest.part" "$dest"
}

# true si apt tiene un candidato instalable para el paquete
existe_pkg() {
    local c
    c="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')"
    [ -n "$c" ] && [ "$c" != "(none)" ]
}

# Instala los paquetes que existan y avisa de los que no (para extras no críticos)
instalar_opcionales() {
    local p disponibles=()
    for p in "$@"; do
        if existe_pkg "$p"; then disponibles+=("$p"); else warn "no disponible en apt, se omite: $p"; fi
    done
    [ "${#disponibles[@]}" -eq 0 ] || DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${disponibles[@]}"
}

# Copia $1 a $1.bak-loq-dots la primera vez (nunca pisa un respaldo existente)
respaldar() { [ -e "$1" ] && [ ! -e "$1.bak-loq-dots" ] && cp -a "$1" "$1.bak-loq-dots"; return 0; }
