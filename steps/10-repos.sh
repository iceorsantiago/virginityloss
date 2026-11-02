#!/usr/bin/env bash
# Step 1 (root): Debian components and external repositories.
#  - Enables contrib, non-free and non-free-firmware (Realtek firmware, NVIDIA).
#  - Noctalia: the official apt repo from its docs (pkg.noctalia.dev).
#  - niri: not in Debian 13; it comes from the DankLinux repo on openSUSE OBS (same as xMane13's repo).
#  - Both external repos are "pinned": they can only provide their own packages,
#    never replace a Debian version.
set -Eeuo pipefail
source "$REPO_DIR/lib/common.sh"
export DEBIAN_FRONTEND=noninteractive

COMPONENTS="main contrib non-free non-free-firmware"

info "Debian components: $COMPONENTS"
# deb822 format (debian.sources)
for f in /etc/apt/sources.list.d/*.sources; do
    [ -e "$f" ] || continue
    grep -qE '^URIs:.*(deb|security)\.debian\.org' "$f" || continue
    backup "$f"
    sed -i -E "/^Components:/c\\Components: $COMPONENTS" "$f"
    ok "$f"
done
# Classic format (sources.list), the one the netinst installer leaves
if [ -f /etc/apt/sources.list ]; then
    backup /etc/apt/sources.list
    # The install CD/USB line breaks "apt update" once you remove the USB
    sed -i -E 's|^(deb(-src)? cdrom:)|# \1|' /etc/apt/sources.list
    awk -v comps="$COMPONENTS" '
        /^deb(-src)? / && /(deb|security)\.debian\.org/ {
            n = split($0, c, " ")
            # deb [options] URI suite components...
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

info "Noctalia repository"
if ! dpkg -s nickh-archive-keyring >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    wget -qO "$tmp/keyring.deb" https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb
    dpkg -i "$tmp/keyring.deb"
    rm -rf "$tmp"
fi
wget -qO /etc/apt/sources.list.d/noctalia-trixie.sources https://pkg.noctalia.dev/deb/noctalia-trixie.sources
rm -f /etc/apt/sources.list.d/noctalia.list   # old v4 repo, no longer exists

info "DankLinux repository (niri, xwayland-satellite)"
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

info "Priorities: external repos can't replace Debian packages"
install -Dm644 "$REPO_DIR/system/apt/loq-dots-pin" /etc/apt/preferences.d/loq-dots-pin

apt-get update
for p in niri noctalia; do pkg_exists "$p" || die "apt can't find '$p' after adding the repos. Check the output of 'apt-get update'."; done
ok "niri $(apt-cache policy niri | awk '/Candidate:/ {print $2}'), noctalia $(apt-cache policy noctalia | awk '/Candidate:/ {print $2}')"
