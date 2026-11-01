# loq-dots

Debian 13 (trixie) instalado **sin escritorio** → **niri + Noctalia v5** con la estética de
[amane](https://github.com/MystiaFin/amane) / [suzuha](https://github.com/MystiaFin/suzuha), con un solo script.

Hecho para el **Lenovo LOQ 15ARP9** (83JC): Ryzen 5 7235HS, RTX 4050 Laptop **sin GPU integrada**,
Wi-Fi/BT Realtek RTL8852BE, 1920×1080 a 144 Hz y Secure Boot activo.
Parte de [xMane13/dotfiles](https://github.com/xMane13/dotfiles), adaptado a este equipo.

## La estética

| | |
|---|---|
| Colores | Catppuccin Mocha, acento azul `#89b4fa` (el que trae suzuha por defecto) |
| Barra | 40 px, arriba, a todo lo ancho, pegada al borde. Sus esquinas inferiores se curvan y se funden con la pantalla, como la barra "líquida" de suzuha |
| Widgets | Píldoras redondeadas: launcher y workspaces · reloj y media · bandeja, CPU, volumen, red, BT, brillo, batería |
| Paneles | Launcher, centro de control, wallpapers y sesión salen pegados a la barra |
| Fuentes | Poppins (interfaz), JetBrainsMono Nerd Font (terminal), Symbols Nerd Font |
| Ventanas | Esquinas de 16 px, gaps de 6, sin borde ni focus ring, sombra suave, entran y salen deslizándose |
| Terminal | kitty translúcido (0.75) con blur, fish y starship en Catppuccin |
| Cursor | Catppuccin Mocha Dark |
| Wallpaper | El de `examples/` de amane (se descarga al instalar; no se incluye en el repo) |

> amane es un *framework* en Rust para hacer shells. No es un tema. La apariencia viene de
> **suzuha**, el shell que su autora usa a diario. Aquí se recrea con **Noctalia** en lugar de compilar suzuha.

## Instalación

### 1. Debian 13
Usa la imagen **netinst amd64**:
- **Contraseña de root: déjala vacía.** Así tu usuario recibe `sudo` automáticamente.
- Conéctate al Wi-Fi durante la instalación. El firmware Realtek ya viene en la imagen.
- En *Selección de programas*, **desmarca todos los escritorios** y deja solo "utilidades estándar del sistema".
- **No desactives Secure Boot.** El script lo maneja.

### 2. Un comando
Entra en la terminal con tu usuario:

```bash
sudo apt install -y git
git clone https://github.com/<tu-usuario>/loq-dots.git
cd loq-dots
./install.sh
```

El script hace todo esto:
1. Activa `contrib non-free non-free-firmware`.
2. Agrega los repos de **Noctalia** (el oficial de su documentación) y **DankLinux** (para niri). Los dos quedan *pineados*: no pueden reemplazar paquetes de Debian.
3. Instala el escritorio: niri, Noctalia, el login (noctalia-greeter, o tuigreet si no está disponible), PipeWire, NetworkManager, Bluetooth y firmware. Pasa tu Wi-Fi del instalador a NetworkManager.
4. Instala el **driver NVIDIA** desde el repo oficial de NVIDIA (rama 595, módulos *open*) y firma los módulos para Secure Boot. **Aquí te pide una contraseña de un solo uso.**
5. Hace los ajustes del LOQ (modo conservación de batería) y aplica los dots: fuentes, cursor, wallpaper y configs, con respaldo de lo que ya tenías.

### 3. Reiniciar
```bash
sudo reboot
```
Aparecerá una **pantalla azul (MokManager)**. Elige **Enroll MOK → Continue → Yes**, escribe la contraseña del paso 4 y luego **Reboot**.
Después entra desde la pantalla de login y corre:

```bash
./install.sh --verificar
```

### Opciones
| | |
|---|---|
| `./install.sh --apps` | Además ofrece Brave, VS Code, Docker, herramientas de desarrollo, OBS, Flatpak y juegos (Steam, Heroic, Greenlight) |
| `./install.sh --solo-dots` | Solo vuelve a aplicar la configuración |
| `./install.sh --forzar` | Repite pasos ya hechos |
| `NVIDIA_RAMA=615 ./install.sh` | Usa otra rama del driver |

Si algo falla, corrígelo y vuelve a correr `./install.sh`: retoma desde el paso pendiente.
El registro completo queda en `~/.local/state/loq-dots/`.

## Atajos principales
| Tecla | Acción |
|---|---|
| `Super+Enter` | Terminal · `Super+T` terminal flotante |
| `Super+Space` / `Ctrl+Space` | Launcher |
| `Super+S` | Centro de control |
| `Super+Shift+W` | Wallpapers |
| `Super+.` | Portapapeles |
| `Super+N` | Ajustes de Noctalia |
| `Super+X` | Apagar / sesión |
| `Super+Q` | Cerrar ventana |
| `Super+1..9` · `Super+Shift+1..9` | Ir a / mover a workspace |
| `Super+H/J/K/L` · flechas | Mover el foco |
| `Super+R` · `Super+F` · `Super+Shift+F` | Ancho · maximizar · pantalla completa |
| `Super+O` | Vista general |
| `Super+Shift+S` / `Print` | Captura |
| `Super+Shift+Space` | Cambiar teclado us ↔ latam |
| `Super+Shift+/` | Todos los atajos |

En fish, `bateria on|off|estado` controla el modo conservación (tope de carga ~80%).

## Qué cambió respecto al repo de xMane13
| Original (Acer Nitro V 15, Intel) | loq-dots (Lenovo LOQ, AMD sin iGPU) |
|---|---|
| Driver NVIDIA 550 de Debian, que ya no compila en open y no corre PyTorch actual | Repo oficial de NVIDIA, rama 595 fijada, módulos open |
| No maneja Secure Boot | Llave MOK de DKMS generada y enrolada |
| `arreglar-nvidia.sh` parchea código fuente del 550 | Eliminado |
| Módulo de batería de Acer + `chmod 666` en `/sys` | `ideapad_laptop` del kernel + `sudo loq-bateria` |
| `fixaudio` para audio Intel | Eliminado (el ALC257 usa HDA estándar) |
| `APT::Install-Recommends false` para todo el sistema | `--no-install-recommends` solo en el escritorio |
| Repos externos sin pin | DankLinux y Noctalia pineados |
| Edita `/etc/apt/sources.list` y `/etc/default/grub` con sed | Soporta deb822, respalda, y GRUB va en `/etc/default/grub.d/` |
| Wi-Fi queda en ifupdown | Se copia a NetworkManager |
| Claude Code con `curl \| bash` | Fuera del script |
| Estética roja "Spike" | Catppuccin / amane |
| Descargas `latest` sin verificar | Versiones fijadas con SHA-256 |

## Problemas
- **Pantalla negra o solo texto al arrancar.** El driver NVIDIA no cargó y este equipo no tiene otra GPU.
  1. Entra a una TTY con `Ctrl+Alt+F2`.
  2. Corre `sudo mokutil --test-key /var/lib/dkms/mok.pub`. Si dice que no está enrolada: `sudo mokutil --import /var/lib/dkms/mok.pub` y reinicia.
  3. Corre `sudo dkms status`. Si falta el módulo: `sudo dkms autoinstall`.
  4. Para entrar a una TTY sin driver: en GRUB pulsa `e` y añade `nomodeset`.
- **El brillo no cambia.** Mira `ls /sys/class/backlight`. Si está vacío o no responde, prueba añadiendo `acpi_backlight=nvidia_wmi_ec` (o `native`) en `/etc/default/grub.d/90-loq-nvidia.cfg`, y luego `sudo update-grub`.
- **Se cae el Wi-Fi.** Descomenta las líneas de `/etc/modprobe.d/rtw89-loq.conf` y reinicia.
- **niri no arranca tras actualizarse.** Corre `niri validate`. El bloque `>>> blur` necesita niri ≥ 26.04.
- **Después de una actualización del kernel no hay escritorio.** Corre `sudo dkms autoinstall` y reinicia. No uses el kernel de backports hasta que el driver lo soporte.
- **Deshacer:** los archivos del sistema tienen `*.bak-loq-dots`, y tus configs anteriores están en `~/.config/loq-dots-respaldo-*`.

## Juegos
- **Xbox Game Pass:** en Linux solo funciona **por la nube** (Greenlight o xbox.com/play), con límite de horas al mes desde noviembre de 2026. No se pueden descargar juegos de Game Pass.
- **EA SPORTS FC 26:** **no corre** en Linux; su anti-cheat (Javelin) lo bloquea. Solo es jugable por la nube con Game Pass Ultimate, o en Windows.
- **Batman Arkham:** funciona con Steam + Proton (Arkham Knight es Verified en Steam Deck), y también está en Game Pass (nube) y GeForce NOW.
- **Naruto Storm:** mixto con Proton. Revisa ProtonDB.
- Para FC 26 en local, Safe Exam Browser o juegos con anti-cheat de kernel: conserva Windows en dual boot.

## Créditos y licencias
- Base de scripts, atajos y estructura: [xMane13/dotfiles](https://github.com/xMane13/dotfiles) (MIT, © Manuel M. Muñoz Cárdenas).
- Estética: [amane](https://github.com/MystiaFin/amane) y [suzuha](https://github.com/MystiaFin/suzuha) de MystiaFin. Se recrea la apariencia; no se copia código.
  El wallpaper viene de `amane/examples/wallpaper.png`. Es arte de terceros sin licencia clara, así que se descarga para uso personal y no se redistribuye aquí.
- [Catppuccin](https://catppuccin.com) (MIT). Fuentes: Poppins (OFL), Nerd Fonts (OFL/MIT).
