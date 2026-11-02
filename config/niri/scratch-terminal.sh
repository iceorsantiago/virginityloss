#!/usr/bin/env bash
# Super+T: drop-down style floating terminal (niri has no scratchpad or minimize).
#  - not open yet          -> open it
#  - open and focused      -> hide it (moves to the spare empty workspace at the end)
#  - open somewhere else   -> bring it to the workspace you're on and focus it
# The shell inside keeps running while hidden.
set -euo pipefail
APP=kitty-scratch

read -r win focused win_out out idx < <(
    { niri msg --json windows; echo; niri msg --json workspaces; echo; niri msg --json focused-output; } |
    python3 -I -c '
import json, sys
wins, wss, fo = (json.loads(l) for l in sys.stdin.read().split("\n") if l.strip())
w = next((w for w in wins if w["app_id"] == sys.argv[1]), None)
ws_out = {s["id"]: s["output"] for s in wss}
active = next(s["idx"] for s in wss if s["output"] == fo["name"] and s["is_active"])
print(w["id"] if w else "-", int(bool(w and w["is_focused"])),
      ws_out.get(w["workspace_id"], "-") if w else "-", fo["name"], active)
' "$APP"
)

if [ "$win" = - ]; then
    exec kitty --class="$APP"
elif [ "$focused" = 1 ]; then
    niri msg action move-window-to-workspace --window-id "$win" --focus false 255
else
    [ "$win_out" = "$out" ] || niri msg action move-window-to-monitor --id "$win" "$out"
    niri msg action move-window-to-workspace --window-id "$win" --focus true "$idx"
    niri msg action focus-window --id "$win"
fi
