#!/usr/bin/env bash
# Current weather for a few cities, from Open-Meteo (free, no API key; same source Noctalia uses).
# Prints conky markup; called with ${execpi 1800 ...}.
cities=(
    "Urcuquí|0.4186|-78.1975"
    "Quito|-0.2202|-78.5123"
)
for c in "${cities[@]}"; do
    IFS='|' read -r name lat lon <<<"$c"
    curl -fsS --max-time 10 \
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&timezone=America%2FGuayaquil" |
    python3 -I -c '
import json, sys
name = sys.argv[1]
try:
    c = json.load(sys.stdin)["current"]
except Exception:
    print("${color #a6adc8}%s${alignr}${color #6c7086}no data" % name); sys.exit()
code = c["weather_code"]
sky = ("Clear" if code == 0 else "Mostly clear" if code in (1, 2) else "Cloudy" if code == 3
       else "Fog" if code in (45, 48) else "Drizzle" if 51 <= code <= 57 else "Rain" if 61 <= code <= 67 or 80 <= code <= 82
       else "Snow" if 71 <= code <= 77 or code in (85, 86) else "Storm" if code >= 95 else "—")
print("${color #a6adc8}%s${alignr}${color #cdd6f4}%.0f°C  %s" % (name, c["temperature_2m"], sky))
print("${color #6c7086}${alignr}humidity %d%%  ·  wind %.0f km/h" % (c["relative_humidity_2m"], c["wind_speed_10m"]))
' "$name"
done
