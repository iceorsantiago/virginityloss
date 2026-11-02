#!/usr/bin/env bash
# Focus an app's window if it's already open, otherwise start it.
# Usage: focus-or-launch.sh <app-id> <command...>    e.g. focus-or-launch.sh brave-browser brave-browser
set -euo pipefail
app="$1"; shift
id="$(niri msg --json windows | python3 -I -c '
import json, sys
wins = [w for w in json.load(sys.stdin) if w["app_id"] == sys.argv[1]]
# The focused one first, so pressing again cycles nowhere unexpected
wins.sort(key=lambda w: not w["is_focused"])
print(wins[0]["id"] if wins else "")
' "$app")"
if [ -n "$id" ]; then
    niri msg action focus-window --id "$id"
else
    exec "$@"
fi
