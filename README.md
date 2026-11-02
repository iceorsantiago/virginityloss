# loq-dots

Debian 13 (trixie) installed **without a desktop** → **niri + Noctalia v5** with the look of
[amane](https://github.com/MystiaFin/amane) / [suzuha](https://github.com/MystiaFin/suzuha), with a single script.

Made for the **Lenovo LOQ 15ARP9** (83JC): Ryzen 5 7235HS, RTX 4050 Laptop **with no integrated GPU**,
Realtek RTL8852BE Wi-Fi/BT, 1920×1080 at 144 Hz and Secure Boot on.
Based on [xMane13/dotfiles](https://github.com/xMane13/dotfiles), adapted to this machine.

## The look

| | |
|---|---|
| Colors | Catppuccin Mocha, blue accent `#89b4fa` (suzuha's default) |
| Bar | 40 px, at the top, full width, stuck to the edge. Its bottom corners curve and blend into the screen, like suzuha's "liquid" bar |
| Widgets | Rounded pills: launcher and workspaces · clock and media · tray, CPU, volume, network, BT, brightness, battery |
| Panels | Launcher, control center, wallpapers and session come out attached to the bar |
| Fonts | Poppins (UI), JetBrainsMono Nerd Font (terminal), Symbols Nerd Font |
| Windows | 16 px corners, gaps of 6, no border or focus ring, soft shadow, they slide in and out |
| Terminal | Translucent kitty (0.75) with blur, fish and starship in Catppuccin |
| Cursor | Catppuccin Mocha Dark |
| Wallpaper | `snowcapped-mountains.jpg` from [ML4W](https://github.com/mylinuxforwork/wallpaper), the one from the r/unixporn post; amane's stays as an alternative under `Super+Shift+W` (downloaded at install time; not included in the repo) |

> amane is a Rust *framework* for building shells. It isn't a theme. The look comes from
> **suzuha**, the shell its author uses every day. Here it's recreated with **Noctalia** instead of building suzuha.

## Installation (dual boot: Debian main + Windows for games)

Debian is the everyday system. Windows stays small and is only for what Linux can't run:
downloaded Game Pass games, EA FC 26 (anti-cheat), Safe Exam Browser. The Windows games live on the
**external SSD D:**, so Windows doesn't need much space.

| Disk | Partition | Size |
|---|---|---|
| Internal SSD (512 GB) | EFI (created by Windows and shared by both) | ~100 MB |
| Internal SSD | Windows 11 | **120 GB** |
| Internal SSD | Debian 13 (the installer creates it in the free space) | the rest, ~350 GB |
| External SSD D: (NTFS) | Windows games (`D:\XboxGames`, EA) and the backup | 512 GB |

> ⚠️ **Before you start:** the backup must be **verified**.
> **Unplug the external SSD D:** during both installs, so you don't wipe it by mistake.

### 0. Fresh Windows (goes first; if installed later, it wipes the Linux bootloader)
1. Make the USB with Microsoft's *Media Creation Tool* and boot from it with **F12**.
2. *Custom install*. On the **internal disk** (the ~476 GB one), **delete all partitions**,
   create **one of 122880 MB** (120 GB) and install there. Leave the rest as *unallocated space*.
3. Once in Windows, copy this repo's `windows/` folder and run as administrator:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\prepare-windows.ps1
   ```
   It turns off *Fast Startup* (otherwise Linux can only read D:), sets the clock to UTC and shows you
   whether **BitLocker** is on. If it is, save the recovery key before going on.
4. Plug in D:. In the Xbox app, go to *Settings → Install options* and pick **D:**.
   Games already in `D:\WindowsApps` belonged to the previous Windows: use *Manage → Repair*,
   or reinstall them. Do the same with the EA app's games folder.

### 1. Debian 13
Unplug D: again and use the **netinst amd64** image:
- **Root password: leave it empty.** That way your user gets `sudo` automatically.
- Connect to Wi-Fi during the install. The Realtek firmware is already in the image.
- Partitioning: **"Guided - use the largest continuous free space"**. It only uses the unallocated space,
  doesn't touch Windows and reuses the EFI partition. Before confirming, check that Windows (NTFS, 120 GB) shows up **unformatted**.
- In *Software selection*, **uncheck every desktop** and leave only "standard system utilities".
- **Don't disable Secure Boot.** The script handles it.

### 2. One command
Log in to the terminal with your user:

```bash
sudo apt install -y git curl
git clone https://github.com/iceorsantiago/virginityloss.git
cd virginityloss
./install.sh
```

The script does all of this:
1. Enables `contrib non-free non-free-firmware`.
2. Adds the **Noctalia** repo (the official one from its docs) and **DankLinux** (for niri). Both are *pinned*: they can't replace Debian packages.
3. Installs the desktop: niri, Noctalia, the login screen (noctalia-greeter, or tuigreet if it isn't available), PipeWire, NetworkManager, Bluetooth and firmware. Moves your installer Wi-Fi to NetworkManager.
4. **Dual boot:** if it finds Windows, it enables `os-prober` so *Windows Boot Manager* stays in the GRUB menu (Debian is the default, with 5 s to choose). Installs NTFS support to open D: from the file manager.
5. Installs the **NVIDIA driver** from NVIDIA's official repo (595 branch, *open* modules) and signs the modules for Secure Boot. **This is where it asks you for a one-time password.**
6. Applies the LOQ tweaks (battery conservation mode) and the dots: fonts, cursor, wallpaper and configs, backing up what you already had.

### 3. Reboot
```bash
sudo reboot
```
A **blue screen (MokManager)** will show up. Choose **Enroll MOK → Continue → Yes**, type the password from step 5 and then **Reboot**.
Then you'll see the GRUB menu: **Debian** boots by itself; to play, pick **Windows Boot Manager** (or press **F12** at power-on).
After that, log in from the login screen and run:

```bash
./install.sh --verify
```

### Options
| | |
|---|---|
| `./install.sh --apps` | Also offers Brave, VS Code, Docker, development tools, OBS, Flatpak and games (Steam, Heroic, Greenlight) |
| `./install.sh --dots-only` | Only re-applies the config |
| `./install.sh --classes` | Only the class stuff: Node 24 (fnm) + pnpm, Edge, Wireshark, nmap, picocom, LaTeX, Typst, SQL clients, Java, port 8081 for Expo Go and Packet Tracer (if its `.deb` is in `~/Downloads`) |
| `./install.sh --no-nvidia` | Skips the NVIDIA driver (not recommended on this machine) |
| `./install.sh --force` | Repeats steps already done |
| `NVIDIA_BRANCH=615 ./install.sh` | Uses another driver branch |

The old Spanish flags (`--sin-nvidia`, `--solo-dots`, `--clases`, `--verificar`, `--forzar`) and `NVIDIA_RAMA` still work.

If something fails, fix it and run `./install.sh` again: it resumes from the pending step.
The full log is in `~/.local/state/loq-dots/`.

## Main keybindings
| Key | Action |
|---|---|
| `Super+Enter` | Terminal · `Super+T` floating terminal (press again to hide it; it keeps running) |
| `Super+Space` / `Ctrl+Space` | Launcher |
| `Super+S` | Control center |
| `Super+Shift+W` | Wallpapers |
| `Super+.` | Clipboard |
| `Super+N` | Noctalia settings |
| `Super+X` | Power / session |
| `Super+Q` · `Super+Z` | Close window |
| `Super+V` | Browser: open Brave, or jump to it if it's already open |
| `Super+Alt+V` | Float the window / put it back in line |
| `Super+1..9` · `Super+Shift+1..9` | Go to / move to workspace |
| `Super+H/J/K/L` · arrows | Move focus |
| `Super+Shift+←/→` (or `H/L`) | Go to the other monitor |
| `Super+Shift+Ctrl+←/→` (or `H/L`) | Move the window to the other monitor |
| `Super` + two fingers up/down on the touchpad | Volume up / down |
| `Super+R` · `Super+F` · `Super+Shift+F` | Width · maximize · fullscreen |
| `Super+O` | Overview |
| `Super+Shift+S` / `Print` | Screenshot |
| `Super+Shift+Space` | Switch keyboard us ↔ latam |
| `Super+Shift+/` | All keybindings |

In fish, `battery on|off|status` controls conservation mode (charge cap ~80%).

## What changed from xMane13's repo
| Original (Acer Nitro V 15, Intel) | loq-dots (Lenovo LOQ, AMD with no iGPU) |
|---|---|
| Debian's NVIDIA 550 driver, which no longer builds as open and doesn't run current PyTorch | NVIDIA's official repo, 595 branch pinned, open modules |
| Doesn't handle Secure Boot | DKMS MOK key generated and enrolled |
| `arreglar-nvidia.sh` patches the 550 source code | Removed |
| Acer battery module + `chmod 666` on `/sys` | The kernel's `ideapad_laptop` + `sudo loq-battery` |
| `fixaudio` for Intel audio | Removed (the ALC257 uses standard HDA) |
| `APT::Install-Recommends false` system-wide | `--no-install-recommends` only for the desktop |
| External repos without pinning | DankLinux and Noctalia pinned |
| Edits `/etc/apt/sources.list` and `/etc/default/grub` with sed | Supports deb822, makes backups, and GRUB goes in `/etc/default/grub.d/` |
| Wi-Fi stays on ifupdown | Copied to NetworkManager |
| Claude Code via `curl \| bash` | Left out of the script |
| Red "Spike" look | Catppuccin / amane |
| Unverified `latest` downloads | Pinned versions with SHA-256 |

## Troubleshooting
- **Black screen or text only at boot.** The NVIDIA driver didn't load and this machine has no other GPU.
  1. Switch to a TTY with `Ctrl+Alt+F2`.
  2. Run `sudo mokutil --test-key /var/lib/dkms/mok.pub`. If it says it isn't enrolled: `sudo mokutil --import /var/lib/dkms/mok.pub` and reboot.
  3. Run `sudo dkms status`. If the module is missing: `sudo dkms autoinstall`.
  4. To get to a TTY without the driver: in GRUB press `e` and add `nomodeset`.
- **Brightness doesn't change.** Check `ls /sys/class/backlight`. If it's empty or doesn't respond, try adding `acpi_backlight=nvidia_wmi_ec` (or `native`) in `/etc/default/grub.d/90-loq-nvidia.cfg`, then `sudo update-grub`.
- **Wi-Fi keeps dropping.** Uncomment the lines in `/etc/modprobe.d/rtw89-loq.conf` and reboot.
- **niri doesn't start after an update.** Run `niri validate`. The `>>> blur` block needs niri ≥ 26.04.
- **No desktop after a kernel update.** Run `sudo dkms autoinstall` and reboot. Don't use the backports kernel until the driver supports it.
- **Windows doesn't show up in the GRUB menu.** Run `sudo os-prober && sudo update-grub`. Meanwhile you can get in with **F12** at power-on.
- **After a Windows update it boots straight into Windows.** In the BIOS (F2) → *Boot*, put **debian** first, or in Windows (admin): `bcdedit /set {fwbootmgr} displayorder {bootmgr} /remove`.
- **D: opens read-only in Linux.** Windows didn't fully shut down: run `prepare-windows.ps1` (turns off Fast Startup) and shut Windows down with *Shut down*, not *Sleep*.
- **The time is wrong in Windows or Linux.** `windows/utc-time.reg` is missing on Windows.
- **Undo:** system files have `*.bak-loq-dots`, and your previous configs are in `~/.config/loq-dots-backup-*` (older installs named them `~/.config/loq-dots-respaldo-*`).

## Games
- **Xbox Game Pass:** on Linux it only works **through the cloud** (Greenlight or xbox.com/play), with a monthly hour limit since November 2026. Game Pass games can't be downloaded.
- **EA SPORTS FC 26:** **doesn't run** on Linux; its anti-cheat (Javelin) blocks it. It's only playable through the cloud with Game Pass Ultimate, or on Windows.
- **Batman Arkham:** works with Steam + Proton (Arkham Knight is Verified on Steam Deck), and it's also on Game Pass (cloud) and GeForce NOW.
- **Naruto Storm:** mixed with Proton. Check ProtonDB.
- For FC 26 locally, Safe Exam Browser or games with kernel anti-cheat: keep Windows in dual boot.

## Credits and licenses
- Script base, keybindings and structure: [xMane13/dotfiles](https://github.com/xMane13/dotfiles) (MIT, © Manuel M. Muñoz Cárdenas).
- Look: [amane](https://github.com/MystiaFin/amane) and [suzuha](https://github.com/MystiaFin/suzuha) by MystiaFin. The appearance is recreated; no code is copied.
  The wallpapers come from [mylinuxforwork/wallpaper](https://github.com/mylinuxforwork/wallpaper) (`snowcapped-mountains.jpg`) and from `amane/examples/wallpaper.png`.
  They're third-party art with no clear license for the image, so they're downloaded for personal use and not redistributed here.
- [Catppuccin](https://catppuccin.com) (MIT). Fonts: Poppins (OFL), Nerd Fonts (OFL/MIT).
