# WCR: Wayland Custom Resolution

![Versión](https://img.shields.io/badge/versi%C3%B3n-3.0--gold-blue)
![Licencia](https://img.shields.io/badge/licencia-MIT-green)
![Plataforma](https://img.shields.io/badge/plataforma-Arch%20Linux-informational)

**Parcheador Universal EDID para Desbloquear Tasas de Refresco en Linux Wayland**

---

## ⚠️ **ADVERTENCIA CRÍTICA DE SEGURIDAD**

### **LEE ESTO ANTES DE USAR WCR - ES POSIBLE DAÑAR EL HARDWARE**

> **WCR modifica temporizaciones de pantalla de bajo nivel. Usarlo incorrectamente puede DAÑAR PERMANENTEMENTE tu monitor.**

#### **Debes:**

1. **Conocer los Límites Seguros de Tu Monitor**
   - Investiga el modelo de tu panel (no el modelo de la marca)
   - Paneles IPS 1080p@60Hz comúnmente soportan 75-90Hz de forma segura
   - Paneles VA pueden soportar 75Hz
   - Paneles TN a veces soportan hasta 100Hz
   - **Ir más allá de límites seguros puede quemar píxeles, dañar el backlight o destruir el panel**

2. **Probar Incrementalmente**
   - Comienza con +5Hz sobre el stock (ej: 60Hz → 65Hz)
   - Observa parpadeos, artefactos, bandas de color o pantalla en negro
   - Aumenta de 5Hz en 5Hz
   - **La primera señal de inestabilidad es tu límite duro - regresa 5-10Hz**

3. **Acepta Total Responsabilidad**
   - Proporcionamos esta herramienta con fines educativos
   - **Eres 100% responsable de cualquier daño al hardware**
   - NO hay GARANTÍA de ningún tipo

#### **Síntomas de Daño:**
- Parpadeo permanente de pantalla
- Píxeles muertos/atascados
- Distorsión de color
- Fallo del backlight
- Fallo completo de la pantalla

**Si no te sientes cómodo con estos riesgos, NO USES ESTA HERRAMIENTA.**

---

## 🎯 ¿Qué es WCR?

WCR (Wayland Custom Resolution) es un parcheador EDID (Extended Display Identification Data) que te permite desbloquear tasas de refresco personalizadas en monitores limitados artificialmente por el firmware del fabricante. Muchos monitores de 60Hz usan paneles capaces de 75Hz o más, pero el EDID los restringe por segmentación de mercado.

### Características Principales

- ✅ **Cumple VESA CVT-RBv2**: Cálculos estándar de la industria con blanking reducido
- ✅ **Detección Automática**: Escanea todas las pantallas conectadas
- ✅ **Copias de Seguridad**: Auto-crea archivos `.wcr.bak` antes de modificar configs
- ✅ **Validación de Entradas**: Previene configuraciones peligrosas (verificaciones de rango 30-500Hz)
- ✅ **Multi-Componente**: Configura initramfs, GRUB e Hyprland
- ✅ **Bilingüe**: Soporte en inglés y español

---

## 📋 Requisitos Previos

### Requisitos del Sistema

- **SO**: Arch Linux (o basado en Arch: Manjaro, EndeavourOS, etc.)
- **Servidor de Pantalla**: Wayland (Hyprland, Sway, etc.)
- **Gestor de Arranque**: GRUB2
- **Init**: systemd con mkinitcpio

### Dependencias

```bash
sudo pacman -S python3 base-devel grub
```

---

## 🚀 Instalación

### 1. Clonar el Repositorio

```bash
git clone https://github.com/yourrepo/wcr.git
cd wcr
chmod +x install_wcr.sh
```

### 2. Ejecutar como Root

```bash
sudo ./install_wcr.sh
```

### 3. Seguir los Prompts Interactivos

```
Selecciona idioma [1/2]: 2
[*] Detectando monitores...
1) DP-1
2) HDMI-A-1
Selecciona el monitor a desbloquear:
> 1
Refresco deseado (Hz) [rango: 30-500]: 75
Resolución detectada: 1920x1080. ¿Correcta? (s/n): s
¿Configurar Hyprland auto? (s/n): s
[✔] LISTO. Reinicia para aplicar.
```

### 4. Reiniciar

```bash
sudo reboot
```

---

## 📖 Ejemplos de Uso

### Ejemplo 1: Estándar 1080p@75Hz

**Escenario**: Tienes un monitor 1920x1080@60Hz con panel IPS verificado que soporta 75Hz.

```bash
sudo ./install_wcr.sh
# Seleccionar monitor → Ingresar 75 → Confirmar resolución → Reiniciar
```

### Ejemplo 2: Ultrawide 2560x1080@100Hz

**Escenario**: Resolución personalizada ultrawide.

```bash
sudo ./install_wcr.sh
# Seleccionar monitor → Ingresar 100
# Resolución detectada: 1920x1080. ¿Correcta? (s/n): n
# Introduce Ancho y Alto: 2560 1080
```

---

## 🛠️ Cómo Funciona

### Visión Técnica General

WCR parchea el EDID usando el estándar VESA CVT Reduced Blanking v2:

1. **Lee el EDID existente** desde `/sys/class/drm/card*/edid`
2. **Calcula nuevas temporizaciones** usando el algoritmo CVT-RBv2
3. **Inyecta DTD modificado** (Detailed Timing Descriptor) en offset 54
4. **Corrige checksum EDID** (byte 127)
5. **Instala en initramfs** vía mkinitcpio
6. **Añade parámetros del kernel** a GRUB:
   ```
   drm.edid_firmware=DP-1:edid/custom_res.bin
   video=DP-1:1920x1080@75
   ```

### Archivos Modificados

| Archivo | Propósito | Ubicación Backup |
|---------|-----------|------------------|
| `/etc/mkinitcpio.conf` | Carga EDID en initramfs | `.wcr.bak` |
| `/etc/default/grub` | Parámetros de arranque del kernel | `.wcr.bak` |
| `/usr/lib/firmware/edid/custom_res.bin` | Binario EDID parcheado | N/A |
| `~/.config/hypr/hyprland.conf` | Config de pantalla (opcional) | `.wcr.bak` |

---

## 🔧 Solución de Problemas

### Pantalla No Funciona Después del Reinicio

**Causa**: Tasa de refresco muy alta o EDID incompatible.

**Solución**: Inicia en modo recuperación y restaura backups:

```bash
# Mantén presionado Shift durante GRUB para entrar a recuperación
sudo cp /etc/default/grub.wcr.bak /etc/default/grub
sudo cp /etc/mkinitcpio.conf.wcr.bak /etc/mkinitcpio.conf
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo mkinitcpio -P
sudo reboot
```

### Parpadeo de Pantalla o Artefactos

**Causa**: Tasa de refresco excede las capacidades del panel.

**Solución**: Reduce 5-10Hz y reinstala.

### "Sin Señal" en el Monitor

**Causa**: Monitor rechazó el EDID.

**Solución**: Restaura backups (ver arriba).

---

## 🗑️ Desinstalación

Para eliminar completamente WCR:

```bash
# Restaurar GRUB
sudo cp /etc/default/grub.wcr.bak /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Restaurar mkinitcpio
sudo cp /etc/mkinitcpio.conf.wcr.bak /etc/mkinitcpio.conf
sudo mkinitcpio -P

# Eliminar EDID
sudo rm /usr/lib/firmware/edid/custom_res.bin

# Reiniciar
sudo reboot
```

---

## ❓ Preguntas Frecuentes

**P: ¿Puede esto dañar mi monitor?**  
R: **Sí**, si excedes los límites seguros de operación. Siempre investiga tu panel primero.

**P: ¿Funciona en X11?**  
R: Esta versión está optimizada para Wayland. X11 requiere configuración diferente.

**P: Mi monitor ya soporta 144Hz. ¿Necesito esto?**  
R: No. WCR es para desbloquear pantallas limitadas artificialmente.

**P: ¿Soporte para GPU NVIDIA?**  
R: Sí. WCR añade automáticamente `nvidia-drm.modeset=1` a GRUB.

**P: ¿Puedo usar esto en otras distros?**  
R: Solo distros basadas en Arch con mkinitcpio están soportadas actualmente.

---

## 📄 Licencia

```
Licencia MIT

Se concede permiso, de forma gratuita, a cualquier persona que obtenga una 
copia de este software y archivos de documentación asociados (el "Software"),
para tratar el Software sin restricciones...

EL SOFTWARE SE PROPORCIONA "TAL CUAL", SIN GARANTÍA DE NINGÚN TIPO, EXPRESA O
IMPLÍCITA, INCLUYENDO PERO NO LIMITADO A LAS GARANTÍAS DE COMERCIABILIDAD,
IDONEIDAD PARA UN PROPÓSITO PARTICULAR Y NO INFRACCIÓN.
```

**Al usar WCR, aceptas total responsabilidad por cualquier daño al hardware o pérdida de datos.**

---

## 🙏 Créditos

- **Autor**: Routel
- **Estándares**: VESA CVT v1.2, EDID v1.4
- **Comunidad**: Arch Linux Wiki, Hyprland Discord

---

## ⚖️ Recordatorio Final

> **Siempre haz overclock responsablemente. Conoce los límites de tu hardware. En caso de duda, NO LO HAGAS.**

Si dañas tu monitor, asumes las consecuencias. Esta herramienta se proporciona para usuarios avanzados que comprenden los riesgos.

---

**¡Dale estrella ⭐ a este repo si WCR te ayudó a desbloquear tu monitor de forma segura!**
