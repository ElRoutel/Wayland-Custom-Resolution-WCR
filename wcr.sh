#!/usr/bin/env bash
# ==============================================================================
# WCR v5 — Wayland Custom Resolution
# Parchea el EDID del monitor (solo el modo preferido, DTD 1) con un modo
# VESA CVT-RBv2 y lo carga al arrancar con drm.edid_firmware.
#
# Uso:
#   wcr.sh --dry [--port DP-1] [--res 1920x1080] [--hz 144]   genera y valida el .bin, NO toca el sistema
#   sudo wcr.sh  [--port DP-1] [--res 1920x1080] [--hz 144]   instala (initramfs + GRUB)
#   sudo wcr.sh --uninstall                                   revierte todo lo que instaló WCR
#
# Opciones: --force (permite modos fuera del rango que declara el monitor; puede dejar la
#           pantalla en negro), --yes (no pregunta), --lang es|en
#
# Seguridad:
#   - Conserva los bloques de extensión (HDR, colorimetría, audio) y el tamaño físico.
#   - Rechaza modos fuera de los límites del monitor (Hz, kHz, pixel clock) salvo --force.
#   - Valida el EDID generado con edid-decode si está instalado.
#   - Respalda /etc/default/grub antes de tocarlo.
#   Recuperación si queda en negro: en GRUB pulsa "e", borra drm.edid_firmware=... y video=...
#   de la línea "linux", arranca con Ctrl+X y ejecuta: sudo wcr.sh --uninstall
# ==============================================================================
set -euo pipefail

VERSION="5.0"
ROOT="${WCR_ROOT:-}"                 # solo para pruebas: prefijo de rutas del sistema
FW_DIR="$ROOT/usr/lib/firmware/edid"
MKINIT_D="$ROOT/etc/mkinitcpio.conf.d"
MKINIT_CONF="$MKINIT_D/wcr-edid.conf"
GRUB_DEFAULT="$ROOT/etc/default/grub"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; BLUE=$'\033[0;34m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; NC=$'\033[0m'

MODE=install; PORT=""; RES=""; HZ=""; FORCE=0; YES=0
LANG_SEL=""; case "${LANG:-}" in es*) LANG_SEL=es ;; *) LANG_SEL=en ;; esac

while [ $# -gt 0 ]; do
    case "$1" in
        --dry) MODE=dry ;;
        --uninstall) MODE=uninstall ;;
        --port) shift; PORT="${1:-}" ;;
        --res) shift; RES="${1:-}" ;;
        --hz) shift; HZ="${1:-}" ;;
        --force) FORCE=1 ;;
        --yes|-y) YES=1 ;;
        --lang) shift; LANG_SEL="${1:-en}" ;;
        -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

t() { # t "english" "español"
    if [ "$LANG_SEL" = es ]; then printf '%s' "$2"; else printf '%s' "$1"; fi
}
info() { echo "${BLUE}[*]${NC} $*"; }
ok()   { echo "${GREEN}[✔]${NC} $*"; }
warn() { echo "${YELLOW}[!]${NC} $*"; }
die()  { echo "${RED}[✘]${NC} $*" >&2; exit 1; }
confirm() { # confirm "pregunta" → 0 si sí
    [ "$YES" = 1 ] && return 0
    local a; read -r -p "$1 $(t '[y/N]' '[s/N]') " a
    [[ "$a" =~ ^[YySs]$ ]]
}
need_root() { [ -n "$ROOT" ] || [ "$EUID" -eq 0 ] || die "$(t 'Run as root (sudo)' 'Ejecuta como root (sudo)')"; }
run() { # ejecuta comandos del sistema; con WCR_ROOT solo los muestra
    if [ -n "$ROOT" ]; then echo "  (test) $*"; else "$@"; fi
}

echo "${CYAN}${BOLD}WCR v$VERSION${NC} — Wayland Custom Resolution"
echo

# ── GRUB: quitar/poner parámetros ────────────────────────────────────────────
grub_strip() { # quita de GRUB_CMDLINE_LINUX_DEFAULT los parámetros de WCR
    [ -f "$GRUB_DEFAULT" ] || return 0
    sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/{
        s/ ?drm\.edid_firmware=[^" ]+//g
        s/ ?video=[A-Za-z]+-[A-Za-z0-9-]+:[0-9]+x[0-9]+@[0-9]+//g
        s/=" /="/
    }' "$GRUB_DEFAULT"
}
grub_update() {
    if command -v grub-mkconfig >/dev/null && [ -d "$ROOT/boot/grub" ]; then
        info "grub-mkconfig"; run grub-mkconfig -o /boot/grub/grub.cfg >/dev/null
    elif command -v update-grub >/dev/null; then
        info "update-grub"; run update-grub >/dev/null
    else
        warn "$(t 'Could not regenerate GRUB config: do it manually.' 'No pude regenerar la config de GRUB: hazlo a mano.')"
    fi
}
initramfs_update() {
    if command -v mkinitcpio >/dev/null; then info "mkinitcpio -P"; run mkinitcpio -P >/dev/null
    elif command -v update-initramfs >/dev/null; then info "update-initramfs -u"; run update-initramfs -u >/dev/null
    elif command -v dracut >/dev/null; then info "dracut --regenerate-all -f"; run dracut --regenerate-all -f >/dev/null
    else warn "$(t 'No initramfs tool found.' 'No encontré herramienta de initramfs.')"; fi
}

# ── Desinstalar ───────────────────────────────────────────────────────────────
if [ "$MODE" = uninstall ]; then
    need_root
    changed=0
    if [ -f "$MKINIT_CONF" ]; then rm -f "$MKINIT_CONF"; ok "$(t 'Removed' 'Borrado') $MKINIT_CONF"; changed=1; fi
    for f in "$FW_DIR"/wcr_*.bin; do [ -e "$f" ] || continue; rm -f "$f"; ok "$(t 'Removed' 'Borrado') $f"; changed=1; done
    if [ -f "$GRUB_DEFAULT" ] && grep -qE 'drm\.edid_firmware=|video=[A-Za-z]+-' "$GRUB_DEFAULT"; then
        cp -a "$GRUB_DEFAULT" "$GRUB_DEFAULT.wcr.bak"
        grub_strip; ok "$(t 'Kernel parameters removed from' 'Parámetros quitados de') $GRUB_DEFAULT"; changed=1
        grub_update
    fi
    if [ "$changed" = 1 ]; then initramfs_update; ok "$(t 'Uninstalled. Reboot to apply.' 'Desinstalado. Reinicia para aplicar.')"
    else ok "$(t 'Nothing to uninstall.' 'No había nada que desinstalar.')"; fi
    if [ -d "$ROOT/boot/loader/entries" ] && grep -rqs 'drm.edid_firmware' "$ROOT/boot/loader/entries"; then
        warn "$(t 'systemd-boot entries still contain drm.edid_firmware: remove it by hand in' 'Las entradas de systemd-boot aún tienen drm.edid_firmware: quítalo a mano en') /boot/loader/entries/"
    fi
    exit 0
fi

[ "$MODE" = install ] && need_root
command -v python3 >/dev/null || die "$(t 'python3 is required' 'Se necesita python3')"

# ── GPU ───────────────────────────────────────────────────────────────────────
GPU="unknown"
for v in /sys/class/drm/card*/device/vendor; do
    [ -r "$v" ] || continue
    case "$(cat "$v")" in 0x10de) GPU=nvidia; break ;; 0x1002) GPU=amd; break ;; 0x8086) GPU=intel ;; esac
done
info "GPU: $GPU"

# ── Monitor ───────────────────────────────────────────────────────────────────
ports=(); edids=()
for s in /sys/class/drm/card*-*/status; do
    [ "$(cat "$s" 2>/dev/null)" = connected ] || continue     # exacto: "disconnected" no cuenta
    d=$(dirname "$s"); ports+=("${d##*/card[0-9]-}"); edids+=("$d/edid")
done
[ ${#ports[@]} -gt 0 ] || die "$(t 'No connected monitors found' 'No hay monitores conectados')"

if [ -z "$PORT" ]; then
    if [ ${#ports[@]} -eq 1 ]; then PORT="${ports[0]}"
    else
        echo "$(t 'Connected monitors:' 'Monitores conectados:')"
        for i in "${!ports[@]}"; do echo "  $((i+1))) ${ports[$i]}"; done
        read -r -p "> " sel
        [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#ports[@]} ] || die "$(t 'Invalid selection' 'Selección inválida')"
        PORT="${ports[$((sel-1))]}"
    fi
fi
EDID_SRC=""
for i in "${!ports[@]}"; do [ "${ports[$i]}" = "$PORT" ] && EDID_SRC="${edids[$i]}"; done
[ -n "$EDID_SRC" ] || die "$(t 'Port not connected:' 'Puerto no conectado:') $PORT"

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cat "$EDID_SRC" > "$WORK/orig.bin"     # sysfs reporta tamaño 0, hay que leerlo
[ "$(stat -c %s "$WORK/orig.bin")" -ge 128 ] || die "$(t 'Could not read the EDID of' 'No pude leer el EDID de') $PORT"

# ── Parámetros del modo ───────────────────────────────────────────────────────
NATIVE=$(python3 -I - "$WORK/orig.bin" <<'PY'
import sys
e = open(sys.argv[1], 'rb').read()
d = e[54:72]
if d[0] | d[1]:
    print(f"{d[2] | (d[4] >> 4) << 8}x{d[5] | (d[7] >> 4) << 8}")
PY
)
[ -n "$RES" ] || { read -r -p "$(t 'Resolution' 'Resolución') [${NATIVE:-1920x1080}]: " RES; RES="${RES:-${NATIVE:-1920x1080}}"; }
[[ "$RES" =~ ^([0-9]{3,5})x([0-9]{3,5})$ ]] || die "$(t 'Invalid resolution (use WxH)' 'Resolución inválida (usa AnchoxAlto)')"
W=${BASH_REMATCH[1]}; H=${BASH_REMATCH[2]}
[ -n "$HZ" ] || read -r -p "$(t 'Refresh rate (Hz)' 'Refresco (Hz)'): " HZ
[[ "$HZ" =~ ^[0-9]+$ ]] && [ "$HZ" -ge 24 ] && [ "$HZ" -le 540 ] || die "$(t 'Invalid refresh rate (24-540)' 'Refresco inválido (24-540)')"

# ── Generar EDID (CVT-RBv2) y comprobar límites ───────────────────────────────
OUT="$WORK/wcr_${PORT}_${W}x${H}_${HZ}hz.bin"
set +e
python3 -I - "$WORK/orig.bin" "$W" "$H" "$HZ" "$OUT" "$FORCE" > "$WORK/report.txt" <<'PY'
import sys, math
src, w, h, hz, out, force = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5], sys.argv[6] == "1"
e = bytearray(open(src, 'rb').read())

# VESA CVT 1.2, Reduced Blanking v2
RB_MIN_VBLANK_US = 460.0
H_BLANK, H_FRONT, H_SYNC = 80, 8, 32
V_SYNC, V_BACK_MIN, V_FRONT_MIN = 8, 6, 1
h_period_est = (1e6 / hz - RB_MIN_VBLANK_US) / h                    # µs por línea
vbi = max(math.floor(RB_MIN_VBLANK_US / h_period_est) + 1, V_FRONT_MIN + V_SYNC + V_BACK_MIN)
v_front = vbi - V_SYNC - V_BACK_MIN
h_total, v_total = w + H_BLANK, h + vbi
pclk_10k = math.floor(hz * h_total * v_total / 10000)                # resolución de 10 kHz del DTD
pclk = pclk_10k * 10000
real_hz = pclk / (h_total * v_total)
h_khz = pclk / h_total / 1000

# Límites que declara el propio monitor (descriptor 0xFD del bloque base)
lim = None
for off in (54, 72, 90, 108):
    d = e[off:off + 18]
    if d[0] == 0 and d[1] == 0 and d[3] == 0xFD:
        f = d[4]
        vmin = d[5] + (255 if f & 0x03 == 0x03 else 0)
        vmax = d[6] + (255 if f & 0x02 else 0)
        hmin = d[7] + (255 if f & 0x0C == 0x0C else 0)
        hmax = d[8] + (255 if f & 0x08 else 0)
        lim = dict(vmin=vmin, vmax=vmax, hmin=hmin, hmax=hmax, pmax=d[9] * 10)
        break

problems = []
if pclk_10k > 0xFFFF:
    problems.append(f"pixel clock {pclk/1e6:.2f} MHz > 655.35 MHz (EDID DTD limit)")
if lim:
    if not lim['vmin'] <= hz <= lim['vmax']: problems.append(f"{hz} Hz outside monitor range {lim['vmin']}-{lim['vmax']} Hz")
    # Solo el máximo horizontal: muchos monitores declaran mal el mínimo (p. ej. "300-300 kHz")
    # y lo que deja la pantalla en negro es pasarse por arriba, no por abajo.
    if h_khz > lim['hmax']: problems.append(f"{h_khz:.1f} kHz > monitor max {lim['hmax']} kHz")
    if pclk / 1e6 > lim['pmax']: problems.append(f"pixel clock {pclk/1e6:.2f} MHz > monitor max {lim['pmax']} MHz")

print(f"MODE   {w}x{h} @ {real_hz:.3f} Hz  (CVT-RBv2)")
print(f"TIMING pixel clock {pclk/1e6:.2f} MHz, H {h_khz:.2f} kHz, total {h_total}x{v_total}")
print("LIMITS " + (f"{lim['vmin']}-{lim['vmax']} Hz, {lim['hmin']}-{lim['hmax']} kHz, max {lim['pmax']} MHz" if lim else "monitor declares no range limits"))
for p in problems: print("PROBLEM " + p)
if pclk_10k > 0xFFFF or (problems and not force):
    sys.exit(3)

old = e[54:72]
dtd = bytearray(18)
dtd[0:2] = pclk_10k.to_bytes(2, 'little')
dtd[2] = w & 0xFF;  dtd[3] = H_BLANK & 0xFF; dtd[4] = (w >> 8 & 0xF) << 4 | (H_BLANK >> 8 & 0xF)
dtd[5] = h & 0xFF;  dtd[6] = vbi & 0xFF;     dtd[7] = (h >> 8 & 0xF) << 4 | (vbi >> 8 & 0xF)
dtd[8] = H_FRONT & 0xFF; dtd[9] = H_SYNC & 0xFF
dtd[10] = (v_front & 0xF) << 4 | (V_SYNC & 0xF)
dtd[11] = (H_FRONT >> 8 & 3) << 6 | (H_SYNC >> 8 & 3) << 4 | (v_front >> 4 & 3) << 2 | (V_SYNC >> 4 & 3)
dtd[12:17] = old[12:17] if (old[0] | old[1]) else bytes(5)       # tamaño físico (mm) y bordes del original
dtd[17] = 0x1A                                                    # digital separado, H+ V- (CVT-RB)
assert len(dtd) == 18
e[54:72] = dtd
e[127] = (256 - sum(e[:127]) % 256) % 256
assert len(e) == len(open(src, 'rb').read())
open(out, 'wb').write(e)
PY
rc=$?
set -e
sed -e "s/^MODE/  $(t 'Mode   ' 'Modo   ')/" -e "s/^TIMING/  Timing/" -e "s/^LIMITS/  $(t 'Monitor' 'Monitor')/" \
    -e "s/^PROBLEM/  ${RED}✘${NC}/" "$WORK/report.txt"
if [ $rc -eq 3 ]; then
    die "$(t 'Mode outside what the monitor accepts. Use --force only if you know it works (risk: black screen).' 'El modo está fuera de lo que acepta el monitor. Usa --force solo si sabes que funciona (riesgo: pantalla negra).')"
elif [ $rc -ne 0 ]; then die "$(t 'EDID generation failed' 'Falló la generación del EDID')"; fi
grep -q '^PROBLEM' "$WORK/report.txt" && warn "$(t '--force: installing a mode outside the monitor limits' '--force: se instalará un modo fuera de los límites del monitor')"

# Validación independiente: el parche no debe AÑADIR fallos (muchos monitores ya traen alguno de fábrica)
failures() { edid-decode --check "$1" 2>&1 | sed -n '/^Failures:/,$p' | grep -E '^ +[A-Z]' | sort -u || true; }
if command -v edid-decode >/dev/null; then
    failures "$WORK/orig.bin" > "$WORK/f_orig.txt"; failures "$OUT" > "$WORK/f_new.txt"
    new=$(comm -13 "$WORK/f_orig.txt" "$WORK/f_new.txt")
    if [ -n "$new" ]; then echo "$new" | head -10; die "$(t 'The patch introduces new EDID failures' 'El parche introduce fallos nuevos en el EDID')"; fi
    if [ -s "$WORK/f_orig.txt" ]; then
        ok "edid-decode: $(t 'no new failures (the original EDID already had' 'sin fallos nuevos (el EDID original ya traía') $(wc -l < "$WORK/f_orig.txt") $(t 'from factory)' 'de fábrica)')"
    else ok "edid-decode: $(t 'valid EDID' 'EDID válido')"; fi
    if edid-decode "$OUT" 2>/dev/null | grep -q 'HDR Static Metadata'; then ok "$(t 'HDR metadata preserved' 'Metadatos HDR conservados')"; fi
else
    warn "$(t 'edid-decode not installed: skipping independent validation' 'edid-decode no está instalado: no se valida aparte')"
fi

if [ "$MODE" = dry ]; then
    cp "$OUT" "./$(basename "$OUT")"
    ok "$(t 'Dry run: nothing installed. EDID saved to' 'Prueba: no se instaló nada. EDID guardado en') ./$(basename "$OUT")"
    exit 0
fi

# ── Instalar ──────────────────────────────────────────────────────────────────
if [ "$GPU" = nvidia ]; then
    warn "$(t 'NVIDIA driver: it reads the EDID itself and usually IGNORES drm.edid_firmware. The patch may have no effect.' 'Driver NVIDIA: lee el EDID por su cuenta y normalmente IGNORA drm.edid_firmware. Puede que el parche no tenga efecto.')"
fi
warn "$(t 'If the screen stays black after reboot: in GRUB press e, delete drm.edid_firmware=... and video=..., boot with Ctrl+X, then run: sudo wcr.sh --uninstall' 'Si la pantalla queda negra al reiniciar: en GRUB pulsa e, borra drm.edid_firmware=... y video=..., arranca con Ctrl+X y ejecuta: sudo wcr.sh --uninstall')"
confirm "$(t "Install ${W}x${H}@${HZ} on $PORT?" "¿Instalar ${W}x${H}@${HZ} en $PORT?")" || { echo "$(t 'Cancelled.' 'Cancelado.')"; exit 0; }

NAME=$(basename "$OUT")
mkdir -p "$FW_DIR"
rm -f "$FW_DIR"/wcr_"${PORT}"_*.bin
install -m 644 "$OUT" "$FW_DIR/$NAME"; ok "$FW_DIR/$NAME"

if command -v mkinitcpio >/dev/null || [ -n "$ROOT" ]; then
    mkdir -p "$MKINIT_D"
    printf '# Generado por WCR v%s — quitar con: wcr.sh --uninstall\nFILES+=(/usr/lib/firmware/edid/%s)\n' "$VERSION" "$NAME" > "$MKINIT_CONF"
    ok "$MKINIT_CONF"
fi
initramfs_update

PARAMS="drm.edid_firmware=$PORT:edid/$NAME video=$PORT:${W}x${H}@$HZ"
if [ -f "$GRUB_DEFAULT" ]; then
    cp -a "$GRUB_DEFAULT" "$GRUB_DEFAULT.wcr.bak"; ok "$(t 'Backup' 'Respaldo'): $GRUB_DEFAULT.wcr.bak"
    grub_strip
    sed -i -E "s|^(GRUB_CMDLINE_LINUX_DEFAULT=\")(.*)\"|\1\2 $PARAMS\"|; s|=\" |=\"|" "$GRUB_DEFAULT"
    grep -q "drm.edid_firmware=$PORT:edid/$NAME" "$GRUB_DEFAULT" || die "$(t 'Could not edit' 'No pude editar') $GRUB_DEFAULT"
    grub_update
elif [ -d "$ROOT/boot/loader/entries" ]; then
    warn "systemd-boot: $(t 'add these kernel parameters to your entry in' 'añade estos parámetros a tu entrada en') /boot/loader/entries/"
    echo "  $PARAMS"
else
    warn "$(t 'Bootloader not detected. Add these kernel parameters:' 'No detecté el gestor de arranque. Añade estos parámetros:')"
    echo "  $PARAMS"
fi

echo
ok "${BOLD}$(t 'Done. Reboot to apply.' 'Listo. Reinicia para aplicar.')${NC}"
echo "  $(t 'Undo' 'Deshacer'): sudo $0 --uninstall"
