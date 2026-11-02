# Functions shared by install.sh and the steps. Loaded with `source`.

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m xx\033[0m %s\n' "$*" >&2; exit 1; }

# Download $1 to $2 and check its SHA-256 ($3). Fails if it doesn't match.
download() {
    local url="$1" dest="$2" sha="$3"
    curl -fsSL --retry 3 -o "$dest.part" "$url" || { rm -f "$dest.part"; return 1; }
    if ! echo "$sha  $dest.part" | sha256sum -c --quiet - >/dev/null 2>&1; then
        rm -f "$dest.part"
        warn "SHA-256 mismatch: $url"
        return 1
    fi
    mv "$dest.part" "$dest"
}

# True if apt has an installable candidate for the package
pkg_exists() {
    local c
    c="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')"
    [ -n "$c" ] && [ "$c" != "(none)" ]
}

# Install the packages that exist and warn about the ones that don't (for non-critical extras)
install_optional() {
    local p available=()
    for p in "$@"; do
        if pkg_exists "$p"; then available+=("$p"); else warn "not available in apt, skipping: $p"; fi
    done
    [ "${#available[@]}" -eq 0 ] || DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${available[@]}"
}

# Copy $1 to $1.bak-loq-dots the first time (never overwrites an existing backup)
backup() { [ -e "$1" ] && [ ! -e "$1.bak-loq-dots" ] && cp -a "$1" "$1.bak-loq-dots"; return 0; }
