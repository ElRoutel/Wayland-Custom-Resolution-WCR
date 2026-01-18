
# WCR - Wayland Custom Resolution Patcher 🖥️⚡

![Version](https://img.shields.io/badge/version-5.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Linux-orange)

**Production-grade EDID patcher for unlocking custom refresh rates on Linux.**

Bypass monitor refresh rate limitations by patching EDID firmware at boot time. Perfect for overclocking monitors beyond their stock 60Hz limit on Wayland/X11.

## ✨ Features

- **🎯 Zero Dependencies**: GPU detection via sysfs (no `pciutils` required)
- **🔒 Safe & Reversible**: Automatic backups of all modified configs
- **🧠 Intelligent**: Auto-detects NVIDIA/AMD/Intel and only injects required parameters
- **🌐 Universal**: Arch, Manjaro, Debian, Ubuntu, EndeavourOS compatible
- **📦 Modular**: Uses modern `.conf.d/` directories when available
- **🛡️ Robust**: Full error logging, validated backups, no silent failures
- **🌍 Bilingual**: English and Spanish interface

## 🔧 Technical Highlights

This script leverages Linux kernel's EDID override mechanism and VESA CVT timing specifications to:

- Preserve CEA-861 extension blocks (HDR, HDMI audio, advanced features)
- Use VESA CVT-RBv2 timing calculations for accurate pixel clocks
- Detect GRUB vs systemd-boot automatically
- Only modify EDID Block 0 (detailed timings), leaving extension blocks intact
- Validate GRUB.d/ sourcing before using modular configs (Arch Linux compatible)

## 📋 Requirements

- **OS**: Linux with kernel 4.15+ (supports `drm.edid_firmware`)
- **Bootloader**: GRUB or systemd-boot
- **Python**: 3.6+
- **Privileges**: Root access (for initramfs/bootloader modification)

### Tested Distributions

| Distribution | Status | Notes |
|--------------|--------|-------|
| Arch Linux   | ✅ | Fully supported (mkinitcpio + GRUB) |
| Manjaro      | ✅ | Fully supported |
| EndeavourOS  | ✅ | Fully supported |
| Debian 11+   | ✅ | Supports GRUB.d/ modular configs |
| Ubuntu 20.04+| ✅ | Supports GRUB.d/ modular configs |

## 🚀 Installation

### Quick Install

```bash
# Download script
curl -LO https://raw.githubusercontent.com/YOUR_USERNAME/wcr/main/wcr.sh
chmod +x wcr.sh

# Run as root
sudo ./wcr.sh
```

### Manual Installation

```bash
git clone https://github.com/YOUR_USERNAME/wcr.git
cd wcr
chmod +x wcr.sh
sudo ./wcr.sh
```

## 📖 Usage

### Basic Workflow

1. Run the script as root

```bash
sudo ./wcr.sh
```

2. Select language (English/Español)

3. Choose your monitor from the detected list

```
1) DP-1
2) HDMI-1
3) eDP-1
```

4. Enter target refresh rate

```
Refresh Rate (Hz) [30-500]: 75
```

5. Confirm or modify resolution

```
Detected: 1920x1080. Correct? (y/n): y
```

6. Optional: Let script configure bootloader (GRUB/systemd-boot)

7. Reboot to apply changes

```bash
reboot
```

### Advanced Usage

#### Manual Bootloader Configuration (systemd-boot)

If using systemd-boot, add to your kernel parameters in `/boot/loader/entries/*.conf`:

```
options ... drm.edid_firmware=DP-1:edid/DP-1_1920x1080_75hz.bin video=DP-1:1920x1080@75
```

#### Custom Resolution

```bash
# Example: 2560x1440 at 144Hz
sudo ./wcr.sh
# Select monitor → Enter 144 → Enter 'n' → Enter 2560 1440
```

#### Multi-Monitor Setup

Run the script multiple times, once per monitor. Each EDID is named uniquely by port:

```
/usr/lib/firmware/edid/
├── DP-1_1920x1080_75hz.bin
├── HDMI-1_1920x1080_60hz.bin
└── eDP-1_2560x1440_165hz.bin
```

## 🔍 How It Works

### Architecture

```
┌─────────────────┐
│  Original EDID  │  Read from /sys/class/drm/card*/edid
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Python CVT-RBv2 │  Calculate new timing parameters
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Patched EDID   │  Modify Block 0, preserve extensions
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│/usr/lib/firmware│ Install patched EDID
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  mkinitcpio     │  Embed in initramfs
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  GRUB Config    │  Add kernel parameters
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     Reboot      │  Kernel loads patched EDID at boot
└─────────────────┘
```

### EDID Modification Details

The script modifies only the first Detailed Timing Descriptor (DTD) at offset 54-71 in EDID Block 0, preserving:

- ✅ CEA-861 Extension Blocks (HDR metadata)
- ✅ HDMI/DisplayPort audio capabilities
- ✅ Manufacturer-specific quirks
- ✅ Color space definitions

## 🐛 Troubleshooting

### Monitor Still Shows Old Refresh Rate

**Check kernel parameters are applied:**

```bash
cat /proc/cmdline | grep drm.edid_firmware
```

**Verify EDID is in initramfs:**

```bash
lsinitcpio /boot/initramfs-linux.img | grep edid
```

**Force EDID reload (Wayland):**

```bash
# Hyprland
hyprctl reload

# Sway
swaymsg reload
```

### mkinitcpio Fails

**Check disk space:**

```bash
df -h /boot
```

**Manually verify FILES entry:**

```bash
grep FILES /etc/mkinitcpio.conf
# Or check modular config:
cat /etc/mkinitcpio.conf.d/wcr-edid.conf
```

### GRUB Changes Not Applied

**Verify grub.d/ sourcing (Arch Linux issue):**

```bash
grep -E "for.*grub\.d|source.*grub\.d" /etc/default/grub
```

If no output, the script will use direct injection instead.

**Regenerate GRUB manually:**

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Black Screen After Reboot

1. Boot into recovery/live USB

2. Restore backups:

```bash
sudo mount /dev/sdXY /mnt
sudo cp /mnt/etc/default/grub.wcr.bak /mnt/etc/default/grub
sudo cp /mnt/etc/mkinitcpio.conf.wcr.bak /mnt/etc/mkinitcpio.conf
sudo arch-chroot /mnt
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg
exit
reboot
```

## 🔐 Backups

All backups are created automatically with `.wcr.bak` extension:

```
/etc/mkinitcpio.conf.wcr.bak
/etc/default/grub.wcr.bak
~/.config/hypr/hyprland.conf.wcr.bak  (if Hyprland configured)
```

**Restore a backup:**

```bash
sudo cp /etc/default/grub.wcr.bak /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

## ⚠️ Limitations

- Does NOT work on proprietary drivers (Wayland limitation, not script)
- Refresh rate must be within monitor's physical capabilities (no magic, electronics still apply)
- NVIDIA + Wayland: Requires `nvidia-drm.modeset=1` (script handles automatically)
- Laptop panels: Some eDP panels ignore custom EDIDs

## 🤝 Contributing

Contributions welcome! Please:

- Test on your distribution
- Report compatibility issues
- Submit pull requests with clear descriptions


Star ⭐ this repo if it helped you achieve buttery smooth refresh rates!
