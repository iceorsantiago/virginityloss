#!/usr/bin/env bash
# Apply the app keybindings (Super+S/E/C/H/K) to your LIVE niri config, with a backup.
# niri reloads its config by itself, so they work right away. Run as your user (no sudo).
set -Eeuo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cfg=${XDG_CONFIG_HOME:-$HOME/.config}/niri
bk="$cfg/config.kdl.bak-$(date +%Y%m%d-%H%M%S)"

cp -a "$cfg/config.kdl" "$bk"
install -Dm755 "$repo_dir/config/niri/launch-app.sh" "$cfg/launch-app.sh"
python3 "$repo_dir/tools/niri-app-keys.py" "$cfg/config.kdl"

if niri validate -c "$cfg/config.kdl"; then
    echo "Done. Backup: $bk"
    echo "Undo: cp '$bk' '$cfg/config.kdl'"
else
    cp -a "$bk" "$cfg/config.kdl"
    echo "niri rejected the new config; your old one is back in place." >&2
    exit 1
fi
