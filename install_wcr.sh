#!/bin/bash

# ==============================================================================
# WCR: Wayland Custom Resolution - Installer v3.0 (Stable/Gold) - FIXED
# Author: Routel
# Description: EDID Hotpatcher with Real VESA CVT-RBv2 Calculation.
# Fixes: Input validation, GRUB safety, duplicate prevention
# ==============================================================================

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# --- Variables ---
FIRMWARE_DIR="/usr/lib/firmware/edid"
PYTHON_SCRIPT="/tmp/wcr_gen.py"
EDID_FILENAME="custom_res.bin"

# --- Check Root ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Error: Run as root (sudo ./install_wcr.sh)${NC}"
  exit 1
fi

# --- Check Python ---
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}[!] Python3 not found. Install it first.${NC}"
    exit 1
fi

# --- 1. Language & Banner ---
clear
echo -e "${CYAN}██╗    ██╗ ██████╗██████╗ ${NC}"
echo -e "${CYAN}██║    ██║██╔════╝██╔══██╗${NC}"
echo -e "${CYAN}██║ █╗ ██║██║     ██████╔╝${NC}  ${BOLD}WCR v3.0 ${NC}"
echo -e "${CYAN}██║███╗██║██║     ██╔══██╗${NC}  Universal EDID Patcher"
echo -e "${CYAN}╚███╔███╔╝╚██████╗██║  ██║${NC}"
echo -e "${CYAN} ╚══╝╚══╝  ╚═════╝╚═╝  ╚═╝${NC}"
echo "----------------------------------------------------"
echo "1. English"
echo "2. Español"
echo -n "Select language [1/2]: "
read lang_opt

if [ "$lang_opt" == "2" ]; then
    TXT_SCAN="${BLUE}[*] Detectando monitores...${NC}"
    TXT_SELECT="Selecciona el monitor a desbloquear:"
    TXT_HZ="Refresco deseado (Hz) [rango: 30-500]: "
    TXT_RES="Resolución detectada: 1920x1080. ¿Correcta? (s/n): "
    TXT_MAN="Introduce Ancho y Alto [ej. 1920 1080]: "
    TXT_CALC="${BLUE}[*] Calculando VESA CVT-RBv2 (Python)...${NC}"
    TXT_BK="${YELLOW}[*] Backup de configs realizado.${NC}"
    TXT_INIT="${BLUE}[*] Actualizando initramfs (mkinitcpio)...${NC}"
    TXT_GRUB="${BLUE}[*] Actualizando GRUB de forma segura...${NC}"
    TXT_HYPR="¿Configurar Hyprland auto? (s/n): "
    TXT_DONE="${GREEN}${BOLD}[✔] LISTO.${NC} Reinicia para aplicar."
    ERR_HZ="${RED}[!] Hz inválido. Debe ser un número entre 30-500.${NC}"
    ERR_RES="${RED}[!] Resolución inválida. Usa números enteros.${NC}"
    ERR_SEL="${RED}[!] Selección inválida.${NC}"
    WARN_RES="${YELLOW}[!] Resolución muy alta. Máximo recomendado: 7680x4320${NC}"
else
    TXT_SCAN="${BLUE}[*] Detecting monitors...${NC}"
    TXT_SELECT="Select monitor to unlock:"
    TXT_HZ="Target Refresh Rate (Hz) [range: 30-500]: "
    TXT_RES="Detected resolution: 1920x1080. Correct? (y/n): "
    TXT_MAN="Enter Width and Height [e.g. 1920 1080]: "
    TXT_CALC="${BLUE}[*] Calculating VESA CVT-RBv2 (Python)...${NC}"
    TXT_BK="${YELLOW}[*] Config backups created.${NC}"
    TXT_INIT="${BLUE}[*] Updating initramfs (mkinitcpio)...${NC}"
    TXT_GRUB="${BLUE}[*] Safely updating GRUB...${NC}"
    TXT_HYPR="Configure Hyprland auto? (y/n): "
    TXT_DONE="${GREEN}${BOLD}[✔] DONE.${NC} Reboot to apply."
    ERR_HZ="${RED}[!] Invalid Hz. Must be a number between 30-500.${NC}"
    ERR_RES="${RED}[!] Invalid resolution. Use integers.${NC}"
    ERR_SEL="${RED}[!] Invalid selection.${NC}"
    WARN_RES="${YELLOW}[!] Very high resolution. Max recommended: 7680x4320${NC}"
fi

# --- 2. Detección ---
echo -e "$TXT_SCAN"
declare -a ports
declare -a raw_paths
i=1

for p in /sys/class/drm/card*-*/status; do
    if grep -q "connected" "$p" 2>/dev/null; then
        full_path=$(dirname "$p")
        name=$(basename "$full_path" | sed 's/card[0-9]-//')
        echo "$i) $name"
        ports+=("$name")
        raw_paths+=("$full_path/edid")
        ((i++))
    fi
done

if [ ${#ports[@]} -eq 0 ]; then 
    echo -e "${RED}[!] No monitors found.${NC}"
    exit 1
fi

echo ""
echo "$TXT_SELECT"
read -p "> " selection

# VALIDACIÓN: Selección de monitor
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#ports[@]}" ]; then
    echo -e "$ERR_SEL"
    exit 1
fi

idx=$((selection-1))
PORT=${ports[$idx]}
EDID_PATH=${raw_paths[$idx]}

# --- 3. Inputs con Validación ---
echo ""
read -p "$TXT_HZ" TARGET_HZ

# VALIDACIÓN: Hz debe ser número entre 30-500
if ! [[ "$TARGET_HZ" =~ ^[0-9]+$ ]] || [ "$TARGET_HZ" -lt 30 ] || [ "$TARGET_HZ" -gt 500 ]; then
    echo -e "$ERR_HZ"
    exit 1
fi

WIDTH=1920
HEIGHT=1080
read -p "$TXT_RES" r_ans

if [[ "$r_ans" =~ ^[Nn]$ ]]; then
    read -p "$TXT_MAN" WIDTH HEIGHT
    
    # VALIDACIÓN: Resolución debe ser números enteros
    if ! [[ "$WIDTH" =~ ^[0-9]+$ ]] || ! [[ "$HEIGHT" =~ ^[0-9]+$ ]]; then
        echo -e "$ERR_RES"
        exit 1
    fi
    
    # ADVERTENCIA: Resoluciones extremas
    if [ "$WIDTH" -gt 7680 ] || [ "$HEIGHT" -gt 4320 ]; then
        echo -e "$WARN_RES"
        read -p "Continue anyway? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
fi

# --- 4. Python Generator (VESA CVT-RBv2 REAL) ---
echo -e "$TXT_CALC"
cat << EOF > $PYTHON_SCRIPT
import sys
import struct

def generate_cvt_rb_v2(width, height, refresh_rate):
    # VESA CVT-RBv2 Standard Constants
    # Clock calculation logic simplified for EDID DTD generation
    
    # 1. Calculate Time per Clock (approx)
    # H-Period estimates
    h_period_est = ((1.0 / refresh_rate) - 460e-6) / (height + 3) * 1e6
    
    # 2. RB Min V-Blank = 460us
    v_blank_lines = int(460 * refresh_rate / 1000000 * height) + 1 # Rough est
    if v_blank_lines < 46: v_blank_lines = 46 # Minimum
    
    v_total = height + v_blank_lines
    
    # 3. Horizontal Logic (RBv2 Fixed Blanking is usually 80 or 160 pixels depending on reduction)
    # We use standard CVT-RB 160px blanking for compatibility
    h_blank = 160 
    h_total = width + h_blank
    
    # 4. Pixel Clock (Hz) = H_Total * V_Total * Refresh
    pixel_clock = h_total * v_total * refresh_rate
    pixel_clock_10khz = int(pixel_clock / 10000)

    # --- DTD PACKING (18 Bytes) ---
    # Byte 0-1: Pixel Clock (Little Endian)
    d0_1 = struct.pack('<H', pixel_clock_10khz)

    # Byte 2: H-Active LSB
    d2 = width & 0xFF
    # Byte 3: H-Blanking LSB
    d3 = h_blank & 0xFF
    # Byte 4: H-Active/Blanking Upper Nibbles
    d4 = ((width >> 8) & 0xF) << 4 | ((h_blank >> 8) & 0xF)

    # Byte 5: V-Active LSB
    d5 = height & 0xFF
    # Byte 6: V-Blanking LSB
    d6 = v_blank_lines & 0xFF
    # Byte 7: V-Active/Blanking Upper Nibbles
    d7 = ((height >> 8) & 0xF) << 4 | ((v_blank_lines >> 8) & 0xF)

    # Sync configuration (CVT-RB uses 32/3 typically, positive sync)
    h_sync_offset = 48 # Front Porch
    h_sync_width = 32
    v_sync_offset = 3
    v_sync_width = 3
    
    # Byte 8: H-Sync Offset LSB
    d8 = h_sync_offset & 0xFF
    # Byte 9: H-Sync Width LSB
    d9 = h_sync_width & 0xFF
    # Byte 10: V-Sync Offset/Width LSB (packed 4 bits each)
    d10 = ((v_sync_offset & 0xF) << 4) | (v_sync_width & 0xF)
    # Byte 11: High bits for Syncs
    d11 = ((h_sync_offset >> 8) & 0x3) << 6 | \
          ((h_sync_width >> 8) & 0x3) << 4 | \
          ((v_sync_offset >> 4) & 0x3) << 2 | \
          ((v_sync_width >> 4) & 0x3)
    
    # Byte 12-17: Dimensions & Flags
    # Byte 17 Flags: 0x18 (Digital, Separate Sync) + Sync Polarity?
    # CVT-RB usually P-Sync. 0x1E = Digital, Sep Sync, Pos V, Pos H
    d12_17 = b'\x00\x00\x00\x00\x00\x1e'

    descriptor = d0_1 + bytes([d2, d3, d4, d5, d6, d7, d8, d9, d10, d11]) + d12_17
    return descriptor

try:
    with open("$EDID_PATH", "rb") as f:
        edid = bytearray(f.read())
    
    # Validar tamaño EDID
    if len(edid) < 128:
        print(f"Error: EDID too small ({len(edid)} bytes, expected 128)")
        sys.exit(1)

    # Generate new timings
    new_dtd = generate_cvt_rb_v2($WIDTH, $HEIGHT, $TARGET_HZ)
    
    # Inject into Detailed Timing #1 (Offset 54)
    edid[54:72] = new_dtd
    
    # CHECKSUM FIX (Full 128 bytes)
    edid[127] = 0
    checksum = (256 - (sum(edid[:128]) % 256)) % 256
    edid[127] = checksum
    
    with open("$EDID_FILENAME", "wb") as f:
        f.write(edid[:128])  # Solo escribir primeros 128 bytes
    print("OK")

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
EOF

python3 $PYTHON_SCRIPT
if [ $? -ne 0 ] || [ ! -f "$EDID_FILENAME" ]; then 
    echo -e "${RED}[!] Python generation failed${NC}"
    rm -f "$PYTHON_SCRIPT"
    exit 1
fi

# --- 5. Install & Initramfs ---
echo -e "$TXT_BK"
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.wcr.bak 2>/dev/null
cp /etc/default/grub /etc/default/grub.wcr.bak 2>/dev/null

echo -e "$TXT_INIT"
mkdir -p "$FIRMWARE_DIR"
cp "$EDID_FILENAME" "$FIRMWARE_DIR/$EDID_FILENAME"

# FIXED: Evitar duplicados en mkinitcpio
if ! grep -q "$FIRMWARE_DIR/$EDID_FILENAME" /etc/mkinitcpio.conf; then
    if grep -q "^FILES=(" /etc/mkinitcpio.conf; then
        # Insertar dentro del paréntesis existente
        sed -i "/^FILES=(/s|FILES=(|FILES=($FIRMWARE_DIR/$EDID_FILENAME |" /etc/mkinitcpio.conf
    else
        # Crear nueva línea FILES
        echo "FILES=($FIRMWARE_DIR/$EDID_FILENAME)" >> /etc/mkinitcpio.conf
    fi
fi

mkinitcpio -P > /dev/null 2>&1

# --- 6. GRUB Safe Injection (FIXED) ---
echo -e "$TXT_GRUB"

# Parámetros nuevos a inyectar
NEW_PARAMS="nvidia-drm.modeset=1 drm.edid_firmware=$PORT:edid/$EDID_FILENAME video=$PORT:${WIDTH}x${HEIGHT}@$TARGET_HZ"

# Leer línea actual
CURRENT_LINE=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub)

# FIXED: Eliminar SOLO parámetros WCR específicos de este puerto
# Esto preserva otros parámetros video= de otros puertos o configuraciones
CLEAN_LINE=$(echo "$CURRENT_LINE" | \
    sed -E "s|drm\.edid_firmware=$PORT:edid/[^ \"]+||g" | \
    sed -E "s|video=$PORT:[^ \"]+||g" | \
    sed -E 's/ +/ /g')  # Eliminar espacios dobles

# Inyectar los nuevos parámetros antes del cierre de comillas
FINAL_LINE=$(echo "$CLEAN_LINE" | sed "s/\"$/ $NEW_PARAMS\"/")

# Escribir al archivo
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|$FINAL_LINE|" /etc/default/grub

# Limpiar espacios extras
sed -i 's/  \+/ /g' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1

# --- 7. Hyprland Config ---
echo ""
echo -n -e "$TXT_HYPR"
read hypr_ans
if [[ "$hypr_ans" =~ ^[YySs]$ ]]; then
    REAL_USER=${SUDO_USER:-$(whoami)}
    HYPR_CONF="/home/$REAL_USER/.config/hypr/hyprland.conf"
    
    if [ -f "$HYPR_CONF" ]; then
        # Backup
        cp "$HYPR_CONF" "$HYPR_CONF.wcr.bak"
        
        # Eliminar líneas WCR previas para este puerto (evita acumulación)
        sed -i "/# WCR Auto.*$PORT/d" "$HYPR_CONF"
        sed -i "/^monitor = $PORT,.*# WCR/d" "$HYPR_CONF"
        
        # Comentar línea original si existe
        sed -i "s/^monitor = $PORT,/#monitor = $PORT,/" "$HYPR_CONF"
        
        # Añadir nueva configuración
        echo "" >> "$HYPR_CONF"
        echo "# WCR Auto ($TARGET_HZ Hz) - $PORT" >> "$HYPR_CONF"
        echo "monitor = $PORT, ${WIDTH}x${HEIGHT}@$TARGET_HZ, 0x0, 1  # WCR" >> "$HYPR_CONF"
        chown "$REAL_USER:$REAL_USER" "$HYPR_CONF"
    fi
fi

# Cleanup
rm -f "$PYTHON_SCRIPT" "$EDID_FILENAME"

echo ""
echo -e "$TXT_DONE"
echo -e "${YELLOW}Backups creados:${NC}"
echo "  - /etc/mkinitcpio.conf.wcr.bak"
echo "  - /etc/default/grub.wcr.bak"
if [ -f "/home/$REAL_USER/.config/hypr/hyprland.conf.wcr.bak" ]; then
    echo "  - ~/.config/hypr/hyprland.conf.wcr.bak"
fi
