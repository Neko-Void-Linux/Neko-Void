#!/usr/bin/env bash
# packages/i3dots/hooks/components/show_cheatsheet.sh - Visor de Atajos Dinámico en feh

TITLE="i3-cheatsheet"

# 1. Si ya está corriendo, cerrarlo (Toggle)
if pkill -f "feh --title $TITLE" 2>/dev/null; then
    exit 0
fi

# 2. Localizar Imagen
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG_PATH="$SCRIPT_DIR/../assets/cheatsheet.png"


if [ ! -f "$IMG_PATH" ]; then
    echo "Error: Imagen de atajos no encontrada en $IMG_PATH" >&2
    exit 1
fi

# 3. Detectar resolución de pantalla activa
read -r W H < <(xrandr | awk '/\*/ {print $1; exit}' | tr 'x' ' ')

# Fallback si xrandr falla
[[ -z "$W" || -z "$H" ]] && { W=1920; H=1080; }

# 4. Calcular geometría proporcional al 70% del monitor
w=$(( W * 70 / 100 ))
h=$(( H * 70 / 100 ))

# 5. Ejecutar feh en primer plano con exec para evitar que Polybar lo mate al salir
exec feh --title "$TITLE" -g "${w}x${h}" --auto-zoom "$IMG_PATH"

