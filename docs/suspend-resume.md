# Lid-close suspend → black screen on resume (LOQ 15ARP9)

## Symptom
Closing the lid suspends normally. On opening it, the keyboard responds (Caps Lock LED toggles)
but the screen stays black; only a hard power-off recovers it.

## Root cause (from the journal, boot of 2026-11-09 13:51)
The NVIDIA GPU fails to come back from **GC6**, the low-power state the driver uses when
**S0ix power management** is enabled. This laptop has no integrated GPU, so the GPU drives the only
screen. If the GPU is dead, the display is dead while the kernel keeps running.

```
13:56:25 systemd-logind: Lid closed.
13:56:27 nvidia-suspend.service (ok)
13:56:29 kernel: PM: suspend entry (s2idle)
15:16:11 systemd-logind: Lid opened.
15:16:11 kernel: PM: suspend exit
15:16:11 NVRM: s_executeBooterUcode_TU102: Booter failed with non-zero error code: 0x89
15:16:11 NVRM: kgspBootstrap_TU102: failed to execute Booter Load (ucode for initial boot): 0xffff
15:16:11 NVRM: gpuPowerManagementResume: GSP boot failed at resume (bootMode 0x2): 0xffff
15:16:11 nvidia 0000:01:00.0: AMD-Vi: Event logged [IO_PAGE_FAULT domain=0x000e address=0x0]
15:16:11 NVRM: _gpuGc6ExitStateLoad: GPU is unable to transition from GC6 to D0 state.
15:16:11 WARNING ... nv_set_system_power_state ... (Comm: nvidia-sleep.sh)
```

Configuration at the time (driver 595.112.07 open, kernel 6.12.115, BIOS PQCN26WW, s2idle only):
`EnableS0ixPowerManagement: 1` (set by the package's `/etc/modprobe.d/nvidia.conf` **and** by the
2026-11-05 attempt), `PreserveVideoMemoryAllocations: 1`, `DynamicPowerManagement: 0`,
`pcie_aspm=off`, `nvme_core.default_ps_max_latency_us=0`.

The 2026-11-05 attempt therefore never changed the failing path. S0ix was already on, and turning
it on was part of that attempt.

Ruled out as the cause of this failure: logind/sleep configuration (lid → suspend works, both NVIDIA
services ran), niri (no crash; it only reacted to the lid event), backlight (`nvidia_0` at 100),
VRAM backup space (`/var/tmp` on ext4, 331 GB free).

## Fix
`/etc/modprobe.d/zz-nvidia-loq-suspend.conf`: `options nvidia NVreg_EnableS0ixPowerManagement=0`.
The name sorts after `nvidia.conf`, so its value wins. The S0ix line was removed from
`nvidia-loq.conf`.

With S0ix off, the GPU is not parked in GC6. `nvidia-suspend.service` saves VRAM to `/var/tmp` and the
GPU does a normal full GSP boot on resume, which is the same boot that works at every power-on.
Trade-off: somewhat higher battery drain while asleep and a few seconds slower suspend/resume.

Apply: `sudo bash tools/apply-suspend-fix.sh`, then reboot.
Test: `sudo bash tools/suspend-test.sh 5 60`, then real lid-close tests, including one long (≥ 30 min) sleep.
Rollback: `sudo bash tools/rollback-suspend-fix.sh`, then reboot.

## Not yet verified
- Whether `pcie_aspm=off` and the NVMe option are still needed. They were added alongside S0ix and
  were not isolated. Remove them one at a time only after the fix is confirmed.
- Whether the failure needs a long sleep to trigger (the logged failure followed 80 min asleep).
