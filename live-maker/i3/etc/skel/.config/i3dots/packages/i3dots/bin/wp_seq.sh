#!/usr/bin/env bash
# packages/i3dots/bin/wp_seq.sh - Selector de Wallpapers con temas integrados y optimizado

# 1. Cargar entorno y lógica compartida
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wp_shared.sh"

# Nombres de las pestañas/botones superiores
L_DARK="Modo Oscuro"
L_LIGHT="Claro"

# 2. Control de Flujo Rofi
if [[ $# -eq 0 ]]; then
    # Fase 1: Lanzar Rofi (arranque inicial)
    active_mode=$(get_state "active_mode" "dark")

    show_mode="$L_DARK"
    [[ "$active_mode" == "light" ]] && show_mode="$L_LIGHT"

    show_names_mode=$(get_state "show_names_mode" "selected-invisible")
    card_style=$(get_state "card_style" "true")
    join_text=$(get_state "join_text" "false")
    card_round_border=$(get_state "card_round_border" "false")
    
    ind_text=$(get_state "ind_text" "false")
    ind_block=$(get_state "ind_block" "true")
    ind_border=$(get_state "ind_border" "false")
    ind_underline=$(get_state "ind_underline" "false")
    ind_halo=$(get_state "ind_halo" "false")

    icon_size_css="element-icon{size:450px;}"
    indicator_css=""

    if [[ "$ind_text" == "true" ]]; then
        indicator_css+="element selected{text-color:var(selected);} element-text selected{background-color:transparent;text-color:var(selected);} "
    fi
    if [[ "$ind_block" == "true" ]]; then
        indicator_css+="element-text selected{background-color:var(selected);text-color:var(background);border-radius:0px;padding:4px 8px;} "
    fi
    
    border_width=""
    if [[ "$ind_border" == "true" && "$ind_underline" == "true" ]]; then
        border_width="3px 3px 6px 3px"
    elif [[ "$ind_border" == "true" ]]; then
        border_width="3px"
    elif [[ "$ind_underline" == "true" ]]; then
        border_width="0px 0px 6px 0px"
    fi

    if [[ -n "$border_width" ]]; then
        indicator_css+="element selected{border:$border_width;border-color:var(selected);"
        if [[ "$ind_underline" == "true" ]]; then
            indicator_css+="text-color:var(selected);"
        fi
        indicator_css+="} "
    fi

    if [[ "$ind_halo" == "true" ]]; then
        indicator_css+="element selected{background-color:var(selected-neutral);text-color:var(selected);} "
    fi

    names_css=""
    case "$show_names_mode" in
        "all")
            names_css="element-text{enabled:true;text-color:inherit;} "
            ;;
        "selected")
            names_css="element-text{enabled:true;text-color:transparent;} element-text selected{enabled:true;} "
            ;;
        "selected-invisible")
            names_css="element-text{enabled:true;text-color:transparent;} element-text selected{enabled:true;text-color:transparent;} "
            ;;
        "disabled")
            names_css="element-text{enabled:false;} element-text selected{enabled:false;} "
            ;;
    esac

    card_css=""
    if [[ "$card_style" == "true" ]]; then
        card_radius="0px"
        [[ "$card_round_border" == "true" ]] && card_radius="${WP_CARD_BORDER_RADIUS:-12px}"
        card_css="element{background-color:var(card-background);border:1px;border-color:var(card-border);border-radius:$card_radius;padding:12px;} element normal.normal{background-color:var(card-background);} element alternate.normal{background-color:var(card-background);} element selected{background-color:var(card-selected);border-radius:$card_radius;} element selected.normal{background-color:var(card-selected);} "
    fi

    join_css=""
    if [[ "$join_text" == "true" ]]; then
        join_css="element{spacing:0px;padding:0px;} element-icon{margin:14px;} element-text{padding:6px 4px;margin:0px;} "
        if [[ "$card_style" == "true" ]]; then
            join_css+="element-text selected{background-color:var(card-selected);text-color:var(selected);} "
        else
            join_css+="element-text selected{background-color:var(card-background);text-color:var(selected);} "
        fi
    fi

    extra_invisible_css=""
    if [[ "$show_names_mode" == "selected-invisible" ]]; then
        extra_invisible_css="element-text selected{text-color:transparent;} element-text{text-color:transparent;} "
    fi

    # Limpiar temporales acumulados de sesiones pasadas antes de lanzar Rofi
    rm -f /tmp/gdk-pixbuf-glycin-tmp.* 2>/dev/null

    export ROFI_LIST_MODE=1
    exec rofi -show "$show_mode" \
        -modi "$L_DARK:$0 --mode-dark,$L_LIGHT:$0 --mode-light" \
        -theme "$WALL_SEL_THEME" \
        -theme-str "$icon_size_css element-text{horizontal-align:0.5;} $card_css $join_css $names_css $indicator_css $extra_invisible_css"

elif [[ $# -eq 1 ]]; then
    # Fase 2: Rofi solicita lista (stdout)
    generate_rofi_list '%f\x00icon\x1f%p'
    exit 0

elif [[ $# -eq 2 ]]; then
    # Fase 3: Rofi devuelve selección ($2) y modo ($1)
    MODE_FLAG="$1"
    SELECTION="$2"
    [[ -z "$SELECTION" ]] && exit 1

    # Registrar el modo seleccionado
    case "$MODE_FLAG" in
        "--mode-dark")   ACTIVE_MODE="dark"   ;;
        "--mode-light")  ACTIVE_MODE="light"  ;;
        *)               ACTIVE_MODE="dark"   ;;
    esac
    set_theme_mode "$ACTIVE_MODE"

    if [[ -f "$SELECTION" ]]; then
        FINAL_PATH="$SELECTION"
    elif [[ "$LIVE_ONLY" -eq 1 ]]; then
        FINAL_PATH="$WALLPAPER_DIR/live/$SELECTION"
    else
        FINAL_PATH="$WALLPAPER_DIR/$SELECTION"
    fi
    FINAL_PATH=$(readlink -f "$FINAL_PATH")


    color_src="$FINAL_PATH"
    temp_to_clean=""
    
    # Si es video o gif, forzar el uso de miniaturas para Matugen
    force_thumb=0
    if [[ "$FINAL_PATH" =~ \.(mp4|webm|mkv|mov|gif)$ ]]; then
        force_thumb=1
    fi


    if [[ "$MATUGEN_USE_THUMB" == "true" || "$force_thumb" -eq 1 ]]; then
        if [[ "$THUMB_CROP_MODE" == "crop" && "$MATUGEN_USE_FIT" == "true" ]]; then
            safe_name="${FINAL_PATH//\//_}"
            get_thumb_path "$FINAL_PATH" "fit"
            fit_thumb="$RET_THUMB"
            
            if [[ -f "$fit_thumb" ]]; then
                color_src="$fit_thumb"
            else
                if [[ "$force_thumb" -eq 1 ]]; then
                    # Generar miniatura de video on-the-fly si no existe
                    if command -v ffmpegthumbnailer &>/dev/null; then
                        fit_dir="$WP_STATE_DIR/thumbs/${THUMB_SIZE}_fit"
                        [[ -d "$fit_dir" ]] || mkdir -p "$fit_dir"
                        ffmpegthumbnailer -i "$FINAL_PATH" -o "$fit_thumb" -s "$THUMB_SIZE" 2>/dev/null
                        color_src="$fit_thumb"
                    fi
                else
                    if [[ "$MATUGEN_CLEAN_TEMP" == "true" ]]; then
                        color_src="/tmp/matugen_fit_${safe_name}.jpg"
                        temp_to_clean="$color_src"
                        vipsthumbnail -s "$THUMB_SIZE" -o "$color_src" "$FINAL_PATH" 2>/dev/null
                    else
                        fit_dir="$WP_STATE_DIR/thumbs/${THUMB_SIZE}_fit"
                        [[ -d "$fit_dir" ]] || mkdir -p "$fit_dir"
                        color_src="$fit_thumb"
                        vipsthumbnail -s "$THUMB_SIZE" -o "$color_src" "$FINAL_PATH" 2>/dev/null
                    fi
                fi
            fi
        else
            safe_name="${FINAL_PATH//\//_}"
            get_thumb_path "$FINAL_PATH"
            normal_thumb="$RET_THUMB"
            
            if [[ -f "$normal_thumb" ]]; then
                color_src="$normal_thumb"
            else
                if [[ "$force_thumb" -eq 1 ]]; then
                    # Generar miniatura de video on-the-fly si no existe
                    if command -v ffmpegthumbnailer &>/dev/null; then
                        crop_dir="$WP_STATE_DIR/thumbs/${THUMB_SIZE}_${THUMB_CROP_MODE}"
                        [[ -d "$crop_dir" ]] || mkdir -p "$crop_dir"
                        ffmpegthumbnailer -i "$FINAL_PATH" -o "$normal_thumb" -s "$THUMB_SIZE" 2>/dev/null
                        color_src="$normal_thumb"
                    fi
                else
                    if [[ "$MATUGEN_CLEAN_TEMP" == "true" ]]; then
                        color_src="/tmp/matugen_thumb_${safe_name}.jpg"
                        temp_to_clean="$color_src"
                        if [[ "$THUMB_CROP_MODE" == "crop" ]]; then
                            vipsthumbnail -s "${THUMB_SIZE}x${THUMB_SIZE}" -m centre -o "$color_src" "$FINAL_PATH" 2>/dev/null
                        else
                            vipsthumbnail -s "$THUMB_SIZE" -o "$color_src" "$FINAL_PATH" 2>/dev/null
                        fi
                    else
                        crop_dir="$WP_STATE_DIR/thumbs/${THUMB_SIZE}_${THUMB_CROP_MODE}"
                        [[ -d "$crop_dir" ]] || mkdir -p "$crop_dir"
                        color_src="$normal_thumb"
                        if [[ "$THUMB_CROP_MODE" == "crop" ]]; then
                            vipsthumbnail -s "${THUMB_SIZE}x${THUMB_SIZE}" -m centre -o "$color_src" "$FINAL_PATH" 2>/dev/null
                        else
                            vipsthumbnail -s "$THUMB_SIZE" -o "$color_src" "$FINAL_PATH" 2>/dev/null
                        fi
                    fi
                fi
            fi
        fi
    fi

    ln -sf "$color_src" "$WP_STATE_DIR/color_source"
    ln -sf "$color_src" "$HOME/.config/i3/current_static"


    (
        "$BASE_DIR/core/bin/wp_select.sh" -C "$FINAL_PATH"
        (polybar-msg cmd hide ; pkill -u $UID -x polybar) &>/dev/null &
        
        if [[ "$ACTIVE_MODE" == "light" ]]; then
            engine_matugen.sh -m light
        else
            engine_matugen.sh -m dark
        fi
        
        [[ -n "$temp_to_clean" && -f "$temp_to_clean" ]] && rm -f "$temp_to_clean"
        rm -f /tmp/gdk-pixbuf-glycin-tmp.* 2>/dev/null
        export NO_WALLPAPER="true"
        apply_dots.sh
    ) &>/dev/null &
    exit 0
fi
