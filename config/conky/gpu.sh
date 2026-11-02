#!/usr/bin/env bash
# VRAM / GPU block for conky (Conky's own ${nvidia} variables need X11; niri is Wayland).
# Prints conky markup; called with ${execpi 3 ...}.
IFS=',' read -r name drv mtot mused mfree temp util pdraw plimit cgr cmem < <(
    nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used,memory.free,temperature.gpu,utilization.gpu,power.draw,power.limit,clocks.gr,clocks.mem \
        --format=csv,noheader,nounits 2>/dev/null | sed 's/, /,/g'
) || { echo '${color #f38ba8}nvidia-smi unavailable'; exit 0; }

pct=$(( mtot > 0 ? mused * 100 / mtot : 0 ))
echo "\${color #cdd6f4}${name/NVIDIA GeForce /}\${alignr}\${color #6c7086}driver ${drv}"
echo "\${color #a6adc8}VRAM\${alignr}\${color #cdd6f4}${mused} / ${mtot} MiB  (${pct}%)"
echo "\${color #89b4fa}\${execbar 6 echo ${pct}}"
echo "\${color #a6adc8}Free\${alignr}\${color #cdd6f4}${mfree} MiB"
echo "\${color #a6adc8}Load\${alignr}\${color #cdd6f4}${util}%"
echo "\${color #a6adc8}Temp\${alignr}\${color #cdd6f4}${temp}°C"
# Laptop GPUs often report no fixed power limit ([N/A]); show the limit only when it's a number
if [[ "$plimit" =~ ^[0-9.]+$ ]]; then
    printf '${color #a6adc8}Power${alignr}${color #cdd6f4}%.0f / %.0f W\n' "$pdraw" "$plimit"
else
    printf '${color #a6adc8}Power${alignr}${color #cdd6f4}%.0f W\n' "$pdraw"
fi
echo "\${color #a6adc8}Clocks\${alignr}\${color #cdd6f4}core ${cgr} MHz · mem ${cmem} MHz"

echo "\${color #6c7086}Top VRAM users"
nvidia-smi --query-compute-apps=process_name,used_memory --format=csv,noheader,nounits 2>/dev/null |
    sort -t, -k2 -nr | head -4 | while IFS=',' read -r p m; do
        # Electron apps report their whole command line; keep just the program's name
        n="$(basename "${p%% *}")"
        printf '${color #cdd6f4}%s${alignr}%s MiB\n' "${n:0:22}" "${m// /}"
    done
