#!/usr/bin/env bash
# wp_select.sh - Backend de selección y aplicación de wallpaper

trap '' SIGHUP  # Sobrevivir al cierre de Rofi o terminal padre

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/wall}"
LAST_WP_FILE="${LAST_WALLPAPER_PATH_FILE:-$HOME/.config/i3/wall}"
CURRENT_WP_LINK="${CURRENT_WALLPAPER_LINK:-$HOME/.config/i3/current}"
WP_ENGINE="${WP_ENGINE:-}"
W_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -C) W_PATH="$2"; shift 2 ;;
        -L|--list)
            find -L "$WALLPAPER_DIR" -type f \(     \
                -iname "*.jpg"  -o -iname "*.jpeg"  \
                -o -iname "*.png"  -o -iname "*.gif"   \
                -o -iname "*.webp" -o -iname "*.mp4"   \
                -o -iname "*.webm" -o -iname "*.mkv" \) | sort
            exit 0
            ;;
        *) shift ;;
    esac
done

# Limpiar URI file:// (Thunar, Nautilus, etc.)
if [[ "$W_PATH" =~ ^file:// ]]; then
    W_PATH="${W_PATH#file://}"
    # Decodificar %XX URL encoding (ej. %20 → espacio)
    W_PATH=$(printf '%b' "${W_PATH//%/\\x}")
fi

[[ -z "$W_PATH" ]] && { echo "Uso: wp_select.sh -C <ruta>" >&2; exit 1; }

# Resolver ruta absoluta real
if [[ -f "$W_PATH" ]]; then
    FINAL_PATH=$(readlink -f "$W_PATH")
elif [[ -f "$WALLPAPER_DIR/$W_PATH" ]]; then
    FINAL_PATH=$(readlink -f "$WALLPAPER_DIR/$W_PATH")
else
    echo "Error: '$W_PATH' no encontrado." >&2
    exit 1
fi

# Autodetectar motor según tipo de archivo
if [[ -z "$WP_ENGINE" ]]; then
    mime=$(file -b --mime-type "$FINAL_PATH" 2>/dev/null)
    [[ "$mime" =~ ^video/ || "$FINAL_PATH" =~ \.(mp4|webm|mkv|gif)$ ]] \
        && WP_ENGINE="live" || WP_ENGINE="feh"
fi

# Guardar estado
mkdir -p "$(dirname "$LAST_WP_FILE")"
echo "$FINAL_PATH" > "$LAST_WP_FILE"
ln -sf "$FINAL_PATH" "$CURRENT_WP_LINK"

# Resolver directorio core y cargar motor
export BASE_DIR="${BASE_DIR:-$HOME/.config/i3dots}"
export CORE_DIR="${CORE_DIR:-$BASE_DIR/core}"

engine_file="$CORE_DIR/engines/${WP_ENGINE}.sh"
if [[ ! -f "$engine_file" ]]; then
    echo "Error: motor '$WP_ENGINE' no encontrado en $engine_file" >&2
    exit 1
fi

source "$engine_file"
engine_set "$FINAL_PATH"
