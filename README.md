# WCR — Wayland Custom Resolution 🖥️⚡

![Version](https://img.shields.io/badge/version-5.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Linux-orange)

*[Español abajo](#español)*

Patches your monitor's EDID so its **preferred mode** becomes a custom resolution/refresh rate (VESA CVT-RBv2 timings), and loads it at boot with the kernel's `drm.edid_firmware` override. Works on Wayland and X11.

## What it does (and doesn't)

- ✅ Replaces **only** the first Detailed Timing Descriptor (bytes 54–71) and fixes the checksum.
- ✅ Keeps every extension block intact: **HDR static metadata, BT.2020, HDMI/DP audio, extra modes**.
- ✅ Keeps the physical screen size (mm), so DPI stays correct.
- ✅ **Refuses modes the monitor says it can't take** (max Hz, max horizontal kHz, max pixel clock from its Range Limits descriptor). `--force` overrides this.
- ✅ Validates the generated EDID with `edid-decode` (if installed) and aborts if the patch adds new failures.
- ✅ `--dry` mode: generates and validates the `.bin` without touching the system.
- ✅ `--uninstall`: removes the firmware, the initramfs hook and the kernel parameters.
- ⚠️ **NVIDIA**: the proprietary/open NVIDIA driver reads the EDID itself and usually **ignores `drm.edid_firmware`**. WCR warns about it; the patch may simply have no effect.
- ⚠️ The override is tied to the connector name (e.g. `DP-3`). A different monitor plugged into that port gets the patched EDID too — run `--uninstall` before swapping monitors.

## Requirements

- Linux kernel with `drm.edid_firmware` (4.15+), `python3`
- initramfs: `mkinitcpio` (Arch), `update-initramfs` (Debian/Ubuntu) or `dracut`
- Bootloader: GRUB (automatic) or systemd-boot (prints the parameters to add)
- Optional: `edid-decode` for independent validation (`pacman -S edid-decode` / `apt install edid-decode`)

## Usage

```bash
git clone https://github.com/ElRoutel/Wayland-Custom-Resolution-WCR.git
cd Wayland-Custom-Resolution-WCR

./wcr.sh --dry --res 1920x1080 --hz 144          # 1. test: generate + validate, no changes
sudo ./wcr.sh --res 1920x1080 --hz 144           # 2. install (asks before changing anything)
sudo ./wcr.sh --uninstall                        # undo everything
```

Options: `--port DP-1` (if you have several monitors), `--force`, `--yes`, `--lang es|en`. Without arguments it asks interactively.

## Recovery (black screen)

1. In the GRUB menu, press **e** on your entry.
2. On the `linux` line delete `drm.edid_firmware=...` and `video=...`.
3. Boot with **Ctrl+X**, then run `sudo ./wcr.sh --uninstall`.

A copy of your previous GRUB config is kept at `/etc/default/grub.wcr.bak`.

## Files it touches

| File | What |
| :--- | :--- |
| `/usr/lib/firmware/edid/wcr_<PORT>_<W>x<H>_<Hz>hz.bin` | patched EDID |
| `/etc/mkinitcpio.conf.d/wcr-edid.conf` | `FILES+=(...)` so the EDID is in the initramfs |
| `/etc/default/grub` (+ `.wcr.bak`) | `drm.edid_firmware=<PORT>:edid/... video=<PORT>:<W>x<H>@<Hz>` |

---

## Español

Parchea el EDID del monitor para que su **modo preferido** sea una resolución/refresco personalizado (tiempos VESA CVT-RBv2) y lo carga al arrancar con `drm.edid_firmware`.

**Qué hace:** cambia solo el primer modo (bytes 54–71) y el checksum; conserva **HDR, BT.2020, audio y los demás modos**, y el tamaño físico. **Rechaza modos que el monitor declara que no soporta** (Hz, kHz o pixel clock máximos) salvo con `--force`. Valida con `edid-decode` y aborta si el parche añade fallos. Tiene `--dry` (prueba sin tocar nada) y `--uninstall` (revierte todo).

**Ojo:**
- Con **NVIDIA** el driver lee el EDID por su cuenta y normalmente **ignora** `drm.edid_firmware`; WCR lo avisa.
- El parche va ligado al nombre del puerto (`DP-3`): si cambias de monitor en ese puerto, ejecuta antes `--uninstall`.

```bash
./wcr.sh --dry --res 1920x1080 --hz 144      # prueba: genera y valida, no cambia nada
sudo ./wcr.sh --res 1920x1080 --hz 144       # instalar (pregunta antes)
sudo ./wcr.sh --uninstall                    # deshacer
```

**Si queda la pantalla en negro:** en GRUB pulsa **e**, borra `drm.edid_firmware=...` y `video=...` de la línea `linux`, arranca con **Ctrl+X** y ejecuta `sudo ./wcr.sh --uninstall`. Tu GRUB anterior queda en `/etc/default/grub.wcr.bak`.

## License

MIT
