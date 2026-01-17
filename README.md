# WCR: Wayland Custom Resolution

![Version](https://img.shields.io/badge/version-3.0--gold-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Arch%20Linux-informational)

**Universal EDID Patcher for Unlocking Monitor Refresh Rates on Linux Wayland**

---

## ⚠️ **CRITICAL SAFETY WARNING**

### **READ THIS BEFORE USING WCR - HARDWARE DAMAGE IS POSSIBLE**

> **WCR modifies low-level display timings. Using it incorrectly can PERMANENTLY DAMAGE your monitor.**

#### **You Must:**

1. **Know Your Monitor's Safe Limits**
   - Research your panel model (not brand model)
   - Common IPS 1080p@60Hz panels often support 75-90Hz safely
   - VA panels may support 75Hz
   - TN panels sometimes support up to 100Hz
   - **Going beyond safe limits can burn pixels, damage backlight, or destroy the panel**

2. **Test Incrementally**
   - Start with +5Hz above stock (e.g., 60Hz → 65Hz)
   - Watch for flickering, artifacts, color banding, or screen blanking
   - Increase by 5Hz at a time
   - **The first sign of instability is your hard limit - go back 5-10Hz**

3. **Accept Full Responsibility**
   - We provide this tool for educational purposes
   - **You are 100% responsible for any hardware damage**
   - There is NO WARRANTY of any kind

#### **Symptoms of Damage:**
- Permanent screen flickering
- Dead/stuck pixels
- Color distortion
- Backlight failure
- Complete display failure

**If you're not comfortable with these risks, DO NOT USE THIS TOOL.**

---

## 🎯 What is WCR?

WCR (Wayland Custom Resolution) is an EDID (Extended Display Identification Data) patcher that allows you to unlock custom refresh rates on monitors artificially limited by manufacturer firmware. Many 60Hz monitors use panels capable of 75Hz or higher, but the EDID restricts them for market segmentation.

### Key Features

- ✅ **VESA CVT-RBv2 Compliant**: Industry-standard reduced blanking calculations
- ✅ **Automatic Detection**: Scans all connected displays
- ✅ **Safe Backups**: Auto-creates `.wcr.bak` files before modifying configs
- ✅ **Input Validation**: Prevents dangerous configurations (30-500Hz range checks)
- ✅ **Multi-Component**: Configures initramfs, GRUB, and Hyprland
- ✅ **Bilingual**: English and Spanish support

---

## 📋 Prerequisites

### System Requirements

- **OS**: Arch Linux (or Arch-based: Manjaro, EndeavourOS, etc.)
- **Display Server**: Wayland (Hyprland, Sway, etc.)
- **Bootloader**: GRUB2
- **Init**: systemd with mkinitcpio

### Dependencies

```bash
sudo pacman -S python3 base-devel grub
```

---

## 🚀 Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourrepo/wcr.git
cd wcr
chmod +x install_wcr.sh
```

### 2. Run as Root

```bash
sudo ./install_wcr.sh
```

### 3. Follow Interactive Prompts

```
Select language [1/2]: 1
[*] Detecting monitors...
1) DP-1
2) HDMI-A-1
Select monitor to unlock:
> 1
Target Refresh Rate (Hz) [range: 30-500]: 75
Detected resolution: 1920x1080. Correct? (y/n): y
Configure Hyprland auto? (y/n): y
[✔] DONE. Reboot to apply.
```

### 4. Reboot

```bash
sudo reboot
```

---

## 📖 Usage Examples

### Example 1: Standard 1080p@75Hz

**Scenario**: You have a 1920x1080@60Hz monitor with IPS panel verified to support 75Hz.

```bash
sudo ./install_wcr.sh
# Select monitor → Enter 75 → Confirm resolution → Reboot
```

### Example 2: Ultrawide 2560x1080@100Hz

**Scenario**: Custom resolution ultrawide.

```bash
sudo ./install_wcr.sh
# Select monitor → Enter 100
# Detected resolution: 1920x1080. Correct? (y/n): n
# Enter Width and Height: 2560 1080
```

---

## 🛠️ How It Works

### Technical Overview

WCR patches the EDID using VESA CVT Reduced Blanking v2 standard:

1. **Reads existing EDID** from `/sys/class/drm/card*/edid`
2. **Calculates new timings** using CVT-RBv2 algorithm
3. **Injects modified DTD** (Detailed Timing Descriptor) at offset 54
4. **Fixes EDID checksum** (byte 127)
5. **Installs to initramfs** via mkinitcpio
6. **Adds kernel parameters** to GRUB:
   ```
   drm.edid_firmware=DP-1:edid/custom_res.bin
   video=DP-1:1920x1080@75
   ```

### Modified Files

| File | Purpose | Backup Location |
|------|---------|-----------------|
| `/etc/mkinitcpio.conf` | Loads EDID into initramfs | `.wcr.bak` |
| `/etc/default/grub` | Kernel boot parameters | `.wcr.bak` |
| `/usr/lib/firmware/edid/custom_res.bin` | Patched EDID binary | N/A |
| `~/.config/hypr/hyprland.conf` | Display config (optional) | `.wcr.bak` |

---

## 🔧 Troubleshooting

### Display Not Working After Reboot

**Cause**: Refresh rate too high or incompatible EDID.

**Solution**: Boot into recovery mode and restore backups:

```bash
# Hold Shift during GRUB to enter recovery
sudo cp /etc/default/grub.wcr.bak /etc/default/grub
sudo cp /etc/mkinitcpio.conf.wcr.bak /etc/mkinitcpio.conf
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo mkinitcpio -P
sudo reboot
```

### Screen Flickering or Artifacts

**Cause**: Refresh rate exceeds panel capabilities.

**Solution**: Reduce by 5-10Hz and reinstall.

### "No Signal" on Monitor

**Cause**: Monitor rejected the EDID.

**Solution**: Restore backups (see above).

---

## 🗑️ Uninstallation

To completely remove WCR:

```bash
# Restore GRUB
sudo cp /etc/default/grub.wcr.bak /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Restore mkinitcpio
sudo cp /etc/mkinitcpio.conf.wcr.bak /etc/mkinitcpio.conf
sudo mkinitcpio -P

# Remove EDID
sudo rm /usr/lib/firmware/edid/custom_res.bin

# Reboot
sudo reboot
```

---

## ❓ FAQ

**Q: Can this damage my monitor?**  
A: **Yes**, if you exceed safe operating limits. Always research your panel first.

**Q: Does this work on X11?**  
A: This version is optimized for Wayland. X11 requires different configuration.

**Q: My monitor already supports 144Hz. Do I need this?**  
A: No. WCR is for unlocking artificially limited displays.

**Q: NVIDIA GPU support?**  
A: Yes. WCR automatically adds `nvidia-drm.modeset=1` to GRUB.

**Q: Can I use this on other distros?**  
A: Only Arch-based distros with mkinitcpio are currently supported.

---

## 📄 License

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

**By using WCR, you accept full responsibility for any hardware damage or data loss.**

---

## 🙏 Credits

- **Author**: Routel
- **Standards**: VESA CVT v1.2, EDID v1.4
- **Community**: Arch Linux Wiki, Hyprland Discord

---

## ⚖️ Final Reminder

> **Always overclock responsibly. Know your hardware limits. When in doubt, DON'T.**

If you damage your monitor, you own the consequences. This tool is provided for advanced users who understand the risks.

---

**Star ⭐ this repo if WCR helped you unlock your monitor safely!**
