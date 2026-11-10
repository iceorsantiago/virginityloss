#!/usr/bin/env bash
# Focus an app if it's already open, otherwise start it from its .desktop entry.
# Usage: launch-app.sh <app-id regex> <desktop Name regex>
#   e.g. launch-app.sh '^spotify$' 'Spotify'
# Matching is case-insensitive. Launching through the .desktop file means it works the same
# for apt, Flatpak and AppImage installs, without hard-coding each app's binary.
set -euo pipefail
exec python3 -I - "$@" <<'EOF'
import configparser, glob, json, os, re, shlex, shutil, subprocess, sys

app_re = re.compile(sys.argv[1], re.I)
name_re = re.compile(sys.argv[2], re.I)

# 1) Already open? Focus it (the focused one first, so pressing again stays put)
wins = json.loads(subprocess.run(["niri", "msg", "--json", "windows"],
                                 capture_output=True, text=True, check=True).stdout)
wins = [w for w in wins if app_re.search(w.get("app_id") or "")]
if wins:
    wins.sort(key=lambda w: not w["is_focused"])
    subprocess.run(["niri", "msg", "action", "focus-window", "--id", str(wins[0]["id"])])
    sys.exit(0)

# 2) Find its .desktop entry (user dirs first, then system and Flatpak exports)
home = os.path.expanduser("~")
dirs = [os.environ.get("XDG_DATA_HOME", f"{home}/.local/share")]
dirs += os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
dirs += [f"{home}/.local/share/flatpak/exports/share", "/var/lib/flatpak/exports/share"]
seen = set()
for d in dirs:
    for path in sorted(glob.glob(os.path.join(d, "applications", "*.desktop"))):
        did = os.path.basename(path)
        if did in seen:
            continue
        seen.add(did)
        cp = configparser.ConfigParser(interpolation=None, strict=False)
        try:
            cp.read(path, encoding="utf-8")
            e = cp["Desktop Entry"]
        except Exception:
            continue
        if e.get("NoDisplay", "").lower() == "true" or e.get("Hidden", "").lower() == "true":
            continue
        if not name_re.fullmatch(e.get("Name", "")):
            continue
        if shutil.which("gio"):
            os.execvp("gio", ["gio", "launch", path])
        if shutil.which("gtk-launch"):
            os.execvp("gtk-launch", ["gtk-launch", did])
        cmd = [a for a in shlex.split(e.get("Exec", "")) if not re.fullmatch(r"%[a-zA-Z]", a)]
        subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        sys.exit(0)

msg = f"No app named '{sys.argv[2]}' found (no matching .desktop file)"
print(msg, file=sys.stderr)
if shutil.which("notify-send"):
    subprocess.run(["notify-send", "-a", "niri", "Can't open app", msg])
sys.exit(1)
EOF
