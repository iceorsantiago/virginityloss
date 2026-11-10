#!/usr/bin/env python3
"""Set the app keybindings in a niri config.kdl, in place (idempotent).

  Super+S  Spotify          (was: Noctalia control center)
  Super+E  Microsoft Edge   (was: Files)
  Super+C  Claude           (was: center column)
  Super+H  Control center   (was: focus column left; the Left arrow still does that)
  Super+K  Files            (was: focus window up; the Up arrow still does that)

Each binding replaces whatever line used that key, so your other edits are kept.
Usage: python3 tools/niri-app-keys.py <config.kdl>
"""
import re, sys

L = '~/.config/niri/launch-app.sh'
BINDS = {
    "S": f'Mod+S hotkey-overlay-title="Spotify" {{ spawn-sh "{L} \'^spotify$\' \'Spotify\'"; }}',
    "E": f'Mod+E hotkey-overlay-title="Edge" {{ spawn-sh "{L} \'^microsoft-edge\' \'Microsoft Edge\'"; }}',
    "C": f'Mod+C hotkey-overlay-title="Claude" {{ spawn-sh "{L} \'^claude\' \'Claude\'"; }}',
    "H": 'Mod+H hotkey-overlay-title="Control center" { spawn "noctalia" "msg" "panel-toggle" "control-center"; }',
    "K": 'Mod+K hotkey-overlay-title="Files" { spawn "nautilus"; }',
}

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
missing = []
for key, line in BINDS.items():
    pat = re.compile(rf'^([ \t]*)Mod\+{key}(?=[ \t{{]).*$', re.M)
    hits = list(pat.finditer(text))
    if hits:
        # keep the first line's indentation and position; drop any later duplicate of the key
        for m in reversed(hits[1:]):
            text = text[:m.start()] + text[m.end() + 1:]
        m = hits[0]
        text = text[:m.start()] + m.group(1) + line + text[m.end():]
    else:
        missing.append(line)
if missing:
    m = re.search(r'^binds\s*\{[^\n]*\n', text, re.M)
    if not m:
        sys.exit("No 'binds {' block found")
    text = text[:m.end()] + "".join(f"    {l}\n" for l in missing) + text[m.end():]
open(path, "w", encoding="utf-8").write(text)
print(f"Updated {path}")
