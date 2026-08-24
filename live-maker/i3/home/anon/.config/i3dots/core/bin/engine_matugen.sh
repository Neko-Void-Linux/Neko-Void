#!/usr/bin/env bash

# engine_matugen.sh - Motor de colores Matugen
# Origen: core/bin/engine_matugen.sh
# Uso: engine_matugen.sh [-L|-D] [-T type] [-I index] [-P preference]

# 0. Asegurar que matugen esté en el PATH (especialmente para ejecuciones desde i3/cron)
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# 1. Parsear únicamente la imagen e identificar si se pide promedio
ARGS=()
IMG_PATH=""
USE_AVERAGE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--image) IMG_PATH="$2"; shift 2 ;;
        --average)  USE_AVERAGE=true; shift ;;
        *) ARGS+=("$1"); shift ;;
    esac
done

# 2. Obtener imagen a procesar de forma dinámica
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR_VAL="${STATE_DIR:-$ROOT_DIR/core/state}"
if [ -z "$CURRENT_ENV" ]; then
    # Intentar detectar el primer paquete disponible en packages/
    for dir in "$ROOT_DIR/packages"/*; do
        if [ -d "$dir" ] && [ -f "$dir/config.env" ]; then
            export CURRENT_ENV="${dir##*/}"
            break
        fi
    done
fi
CUR_ENV="${CURRENT_ENV}"

if [ -z "$CUR_ENV" ]; then
    echo "Error [engine_matugen]: No se pudo detectar CURRENT_ENV" >&2
    exit 1
fi

WP_STATE_DIR="$STATE_DIR_VAL/$CUR_ENV/wallpaper"
COLOR_SOURCE="$WP_STATE_DIR/color_source"

if [[ -z "$IMG_PATH" ]]; then
    if [[ -f "$COLOR_SOURCE" ]]; then
        IMG_PATH=$(readlink -f "$COLOR_SOURCE")
    else
        IMG_PATH=$(readlink -f "$CURRENT_WALLPAPER_LINK")
    fi
fi

if [[ ! -f "$IMG_PATH" ]]; then
    echo "Error [engine_matugen]: No hay imagen válida a procesar en '$IMG_PATH'" >&2
    exit 1
fi

# 3. Localizar configuración de matugen en el paquete
MATUGEN_CONF="$PACKAGE_DIR/config/matugen/config.toml"
[[ ! -f "$MATUGEN_CONF" ]] && MATUGEN_CONF="$PACKAGE_DIR/matugen/config.toml"

# Cargar preferencias de Matugen desde el estado del wallpaper
WP_STATE_FILE="$WP_STATE_DIR/state.env"
if [ -f "$WP_STATE_FILE" ]; then
    source "$WP_STATE_FILE"
fi

MATUGEN_SCHEME_TYPE="${matugen_scheme_type:-scheme-tonal-spot}"
MATUGEN_CONTRAST="${matugen_contrast:-0.0}"
MATUGEN_PREFER="${matugen_prefer:-saturation}"
MATUGEN_COLOR_INDEX="${matugen_source_color_index:-0}"
MATUGEN_LIGHTNESS_DARK="${matugen_lightness_dark:-0.0}"
MATUGEN_RESIZE_FILTER="${matugen_resize_filter:-gaussian}"

# Cargar reglas específicas por wallpaper si existen
RULES_FILE="$WP_STATE_DIR/rules.env"
if [[ -f "$RULES_FILE" ]]; then
    DETECTED_MODE=""
    for ((i=0; i<${#ARGS[@]}; i++)); do
        if [[ "${ARGS[i]}" == "-m" || "${ARGS[i]}" == "--mode" ]]; then
            DETECTED_MODE="${ARGS[i+1]}"
            break
        fi
    done
    [[ -z "$DETECTED_MODE" ]] && DETECTED_MODE="${active_mode:-dark}"
    [[ "$DETECTED_MODE" == "settings" ]] && DETECTED_MODE="${active_mode_real:-dark}"

    WP_BASE=$(basename "$IMG_PATH")
    WP_SAFE_NAME="${WP_BASE//[^a-zA-Z0-9]/_}"

    RULE_LINE=$(grep "^${WP_SAFE_NAME}\.${DETECTED_MODE}=" "$RULES_FILE" | cut -d= -f2-)
    RULE_LINE="${RULE_LINE%\"}"
    RULE_LINE="${RULE_LINE#\"}"

    if [[ -n "$RULE_LINE" ]]; then
        IFS='|' read -r r_scheme r_contrast r_prefer r_index r_ldark r_rfilter <<< "$RULE_LINE"
        [[ -n "$r_scheme" ]] && MATUGEN_SCHEME_TYPE="$r_scheme"
        [[ -n "$r_contrast" ]] && MATUGEN_CONTRAST="$r_contrast"
        [[ -n "$r_prefer" ]] && MATUGEN_PREFER="$r_prefer"
        [[ -n "$r_index" ]] && MATUGEN_COLOR_INDEX="$r_index"
        [[ -n "$r_ldark" ]] && MATUGEN_LIGHTNESS_DARK="$r_ldark"
        [[ -n "$r_rfilter" ]] && MATUGEN_RESIZE_FILTER="$r_rfilter"
    fi
fi


has_arg() {
    local search="$1"
    for arg in "${ARGS[@]}"; do
        if [[ "$arg" == "$search" ]]; then
            return 0
        fi
    done
    return 1
}

has_arg "-t" || has_arg "--type" || ARGS+=("-t" "$MATUGEN_SCHEME_TYPE")
has_arg "--contrast" || ARGS+=("--contrast" "$MATUGEN_CONTRAST")
has_arg "--source-color-index" || ARGS+=("--source-color-index" "$MATUGEN_COLOR_INDEX")
has_arg "--lightness-dark" || ARGS+=("--lightness-dark" "$MATUGEN_LIGHTNESS_DARK")
has_arg "-r" || has_arg "--resize-filter" || ARGS+=("--resize-filter" "$MATUGEN_RESIZE_FILTER")
if [[ "$MATUGEN_PREFER" != "default" && -n "$MATUGEN_PREFER" ]]; then
    has_arg "--prefer" || ARGS+=("--prefer" "$MATUGEN_PREFER")
fi

# Si no se pasó -m explícitamente, usar el modo del state
if ! has_arg "-m" && ! has_arg "--mode"; then
    ARGS+=("-m" "${active_mode:-dark}")
fi

# 4. Ejecución de Matugen
cmd=("matugen")

# Si existe un config.toml en el paquete, lo priorizamos
if [ -f "$MATUGEN_CONF" ]; then
    cmd+=("--config" "$MATUGEN_CONF")
fi

# 5. Determinar modo de ejecución (Imagen directa o Color promedio)
if [ "$USE_AVERAGE" = true ] && type magick &>/dev/null; then
    # Obtener el color promedio en hexadecimal usando ImageMagick
    COLOR_HEX=$(magick "$IMG_PATH" -scale 1x1! -format "%[hex:u]" info:)
    echo "Matugen: Procesando color promedio #$COLOR_HEX (extraído de $IMG_PATH) con argumentos: ${ARGS[*]}..."
    exec "${cmd[@]}" color hex "$COLOR_HEX" "${ARGS[@]}"
else
    echo "Matugen: Procesando $IMG_PATH con argumentos: ${ARGS[*]}..."
    exec "${cmd[@]}" image "$IMG_PATH" "${ARGS[@]}"
fi
