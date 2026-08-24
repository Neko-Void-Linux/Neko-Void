#!/usr/bin/env bash
# packages/i3dots/hooks/components/bar_menu.sh - Rofi Frontend para engine_state.sh bar

# 1. Configurar Variables y Directorios de Forma Dinámica
if [ -z "$PROJECT_ROOT" ]; then
    SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
    export PROJECT_ROOT=$(cd "$(dirname "$SCRIPT_PATH")/../../.." && pwd)
fi
export CORE_DIR="${CORE_DIR:-$PROJECT_ROOT/core}"
export STATE_DIR="${STATE_DIR:-$PROJECT_ROOT/core/state}"
export CURRENT_ENV="${CURRENT_ENV:-i3dots}"
STATE_FILE="$STATE_DIR/$CURRENT_ENV/bar/state.env"
[ -f "$STATE_FILE" ] && source "$STATE_FILE"

ENGINE_CMD=(bash "$CORE_DIR/bin/engine_state.sh" bar)
CHOICE_FILE="/dev/shm/bar_menu_${UID}.choice"

# Si se pasó argumentos que no requieren menús (ej: --next, --prev, --set, --get, -L, --list)
HEADLESS=0
for arg in "$@"; do
    case "$arg" in
        --next|--prev|--set|--get|--list-themes|--list-options|--list-presets|-L|--list|--apply-preset)
            HEADLESS=1
            break
            ;;
    esac
done

if [ "$HEADLESS" -eq 1 ]; then
    # Delegación directa al backend
    exec "${ENGINE_CMD[@]}" "$@"
fi

# Cargar configuraciones de visualización
BAR_SEL_BIN="${BAR_SEL_BIN:-rofi}"
BAR_SEL_PROMPT_FLAG="${BAR_SEL_PROMPT_FLAG:--p}"
read -ra BAR_ARGS_ARR <<< "${BAR_SEL_ARGS:--dmenu}"
if [[ "$BAR_SEL_BIN" == *"rofi"* ]] && [ -n "$BAR_SEL_THEME" ] && [[ "${BAR_SEL_ARGS}" != *"-theme"* ]]; then
    BAR_ARGS_ARR+=("-theme" "$BAR_SEL_THEME")
fi

notify_applied() {
    # Notificaciones desactivadas para evitar spam visual al cambiar de tema
    :
}

# --- Lógica de Menús con Rofi ---

DO_SELECT=0
DO_MANAGE=0
for arg in "$@"; do
    [[ "$arg" == "--select" ]] && DO_SELECT=1
    [[ "$arg" == "--manage" ]] && DO_MANAGE=1
done

if [ $# -eq 0 ]; then
    DO_SELECT=1
fi

# A. Selector de Presets (--select)
if [ "$DO_SELECT" -eq 1 ]; then
    presets=$("${ENGINE_CMD[@]}" --list-presets)
    if [ -z "$presets" ]; then
        echo "Error: No se encontraron presets de barra." >&2
        exit 1
    fi
    
    "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Presets de Barra" <<< "$presets" > "$CHOICE_FILE"
    IFS= read -r choice < "$CHOICE_FILE"
    [[ -z "$choice" ]] && exit 0
    
    notify_applied "$choice"
    exec "${ENGINE_CMD[@]}" --apply-preset "$choice"
fi

# B. Configurar opciones (--manage)
if [ "$DO_MANAGE" -eq 1 ]; then
    CUR_TYPE="${type:-polybar_antigua}"
    
    opts_raw=$("${ENGINE_CMD[@]}" --list-options)
    
    options=""
    declare -A OPT_LABELS
    declare -A OPT_VALUES
    
    IFS='|' read -ra OPT_ARRAY <<< "$opts_raw"
    for opt in "${OPT_ARRAY[@]}"; do
        IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
        OPT_LABELS["$opt_key"]="$opt_label"
        OPT_VALUES["$opt_key"]="$opt_vals"
        
        cur_val="${!opt_key}"
        [[ -z "$cur_val" ]] && cur_val="${opt_vals%%,*}"
        
        options="$options$opt_label: $cur_val"$'\n'
    done
    
    "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Ajustes: $CUR_TYPE" <<< "$options" > "$CHOICE_FILE"
    IFS= read -r choice < "$CHOICE_FILE"
    [[ -z "$choice" ]] && exit 0
    
    choice_label="${choice%%:*}"
    choice_label="${choice_label##[[:space:]]}"
    choice_label="${choice_label%%[[:space:]]}"
    for opt_key in "${!OPT_LABELS[@]}"; do
        if [ "${OPT_LABELS[$opt_key]}" == "$choice_label" ]; then
            val_options="${OPT_VALUES[$opt_key]//,/$'\n'}"
            
            "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Elegir $choice_label" <<< "$val_options" > "$CHOICE_FILE"
            IFS= read -r NEW_VAL < "$CHOICE_FILE"
            
            if [ -n "$NEW_VAL" ]; then
                if [ "$NEW_VAL" == "custom" ]; then
                    "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Nuevo $choice_label" <<< "" > "$CHOICE_FILE"
                    IFS= read -r NEW_VAL < "$CHOICE_FILE"
                    [[ -z "$NEW_VAL" ]] && exit 0
                fi
                exec "${ENGINE_CMD[@]}" --set "$opt_key" "$NEW_VAL"
            fi
        fi
    done
    exit 0
fi

# C. Menú interactivo general (sin argumentos)
# Mostrar lista de temas y opciones en una sola lista
themes=$("${ENGINE_CMD[@]}" --list-themes)
opts_raw=$("${ENGINE_CMD[@]}" --list-options)

options=""
if [ -n "$themes" ]; then
    for theme in $themes; do
        options+="Tema: $theme"$'\n'
    done
fi

declare -A OPT_LABELS
declare -A OPT_VALUES
if [ -n "$opts_raw" ]; then
    IFS='|' read -ra OPT_ARRAY <<< "$opts_raw"
    for opt in "${OPT_ARRAY[@]}"; do
        IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
        OPT_LABELS["$opt_key"]="$opt_label"
        OPT_VALUES["$opt_key"]="$opt_vals"
        
        IFS=',' read -ra VALS_ARR <<< "$opt_vals"
        for val in "${VALS_ARR[@]}"; do
            options+="$opt_label: $val"$'\n'
        done
    done
fi

"$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Configuración de Barra" <<< "$options" > "$CHOICE_FILE"
IFS= read -r choice < "$CHOICE_FILE"
[[ -z "$choice" ]] && exit 0

if [[ "$choice" == Tema:* ]]; then
    selected_theme="${choice#Tema: }"
    exec "${ENGINE_CMD[@]}" --set type "$selected_theme"
else
    choice_label="${choice%%:*}"
    choice_label="${choice_label##[[:space:]]}"
    choice_label="${choice_label%%[[:space:]]}"
    
    choice_val="${choice#*:}"
    choice_val="${choice_val##[[:space:]]}"
    choice_val="${choice_val%%[[:space:]]}"
    for opt_key in "${!OPT_LABELS[@]}"; do
        if [ "${OPT_LABELS[$opt_key]}" == "$choice_label" ]; then
            if [ "$choice_val" == "custom" ]; then
                "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Nuevo $choice_label" <<< "" > "$CHOICE_FILE"
                IFS= read -r choice_val < "$CHOICE_FILE"
                [[ -z "$choice_val" ]] && exit 0
            fi
            exec "${ENGINE_CMD[@]}" --set "$opt_key" "$choice_val"
        fi
    done
fi
