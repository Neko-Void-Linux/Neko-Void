#!/usr/bin/env bash
# packages/i3dots/bin/wall_menu.sh - Menú interactivo y gestor de Wallpapers (Frontend)

# 1. Parseo de argumentos
USE_CLI=0
CACHE_NOW=0
CLEAN_CACHE=0
CLEAN_ARG=""
MANAGE_MODE=0

PRESETS_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -CT) USE_CLI=1; shift ;;
        -CN|--cache-now) CACHE_NOW=1; shift ;;
        -CC|--clean-cache) 
            CLEAN_CACHE=1
            CLEAN_ARG="$2"
            shift; [[ $# -gt 0 ]] && shift
            ;;
        -M|--manage) MANAGE_MODE=1; shift ;;
        -P|--presets-only) PRESETS_ONLY=1; MANAGE_MODE=1; shift ;;
        *) shift ;;
    esac
done

# 2. Cargar entorno y lógica compartida
BASE_DIR="${BASE_DIR:-$HOME/.config/i3dots}"
source "$BASE_DIR/packages/i3dots/bin/wp_shared.sh"

# Si habilitado, pero no hay vips, desactivar
if [[ "$THUMB_MODE" == "enabled" && "$HAS_VIPS" -eq 0 ]]; then
    THUMB_MODE="disabled"
        echo "Advertencia: Comando 'vipsthumbnail' no encontrado. Desactivando caché de miniaturas." >&2
fi

# Cargar traducciones e iconos del entorno con fallbacks
PROM_THUMBS="${WP_PROM_THUMBS:-Miniaturas en caché}"
PROM_QUALITY="${WP_PROM_QUALITY:-Calidad de Miniaturas}"
PROM_NO_THUMB="${WP_PROM_NO_THUMB:-Si falta miniatura}"
PROM_BG_GEN="${WP_PROM_BG_GEN:-Pre-caché}"
PROM_CLEAN="${WP_PROM_CLEAN:-Limpiar Caché de Miniaturas}"

# La función save_state ahora es provista por wp_shared.sh

# 4. Modo Headless: Delegar a wp_cache.sh
if [[ "$CACHE_NOW" -eq 1 ]]; then
    wp_cache.sh --cache-now
    exit $?
fi

if [[ "$CLEAN_CACHE" -eq 1 ]]; then
    wp_cache.sh --clean-cache "$CLEAN_ARG"
    exit $?
fi

# 5. Menú Dedicado de Ajustes de Rofi (--manage)
if [[ "$MANAGE_MODE" -eq 1 ]]; then
    # Cargar variables de visualización de Rofi para configuración
    SEL_BIN="${WP_SEL_BIN:-rofi}"
    LAUNCHER_THEME="${WP_MANAGE_THEME:-${ROFI_THEME:-$HOME/.config/rofi/themes/launcher.rasi}}"
    SEL_ARGS_ARR=("-dmenu" "-theme" "$LAUNCHER_THEME")

    # Función genérica para solicitar selección en Rofi/dmenu
    ask_selection() {
        local prompt="$1"
        local options="$2"
        local choice_tmp="/dev/shm/wall_menu_ask_${UID}.choice"
        if [[ "$SEL_BIN" == *"rofi"* ]]; then
            eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$prompt\" -format 's' <<< \"\$options\"" > "$choice_tmp"
        else
            eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$prompt\" <<< \"\$options\"" > "$choice_tmp"
        fi
        local choice=""
        [[ -f "$choice_tmp" ]] && read -r choice < "$choice_tmp"
        rm -f "$choice_tmp"
        echo "$choice"
    }


    toggle_state_val() {
        local state_key="$1"
        local cur_val_var_name="$2"
        local new_val="true"
        [[ "${!cur_val_var_name}" == "true" ]] && new_val="false"
        save_state "$state_key" "$new_val"
        printf -v "$cur_val_var_name" "%s" "$new_val"
    }

    ask_and_apply_loop() {
        local prompt="$1"
        local options="$2"
        local state_key="$3"
        local var_name="$4"
        local prefix="$5"

        while true; do
            local sel=$(ask_selection "$prompt" "$options")
            [[ -z "$sel" || "$sel" == "Atrás" ]] && break

            local val="$sel"
            if [[ "$val" == "Ninguna (Por defecto)" ]]; then
                val="default"
            elif [[ "$state_key" == "matugen_resize_filter" || "$state_key" == "matugen_lightness_dark" ]]; then
                val="${sel%% *}"
            elif [[ "$state_key" == "matugen_source_color_index" ]]; then
                val="${sel:0:1}"
            elif [[ "$state_key" == "show_names_mode" ]]; then
                case "$sel" in
                    "Todos") val="all" ;;
                    "Solo en seleccionada") val="selected" ;;
                    "Solo en seleccionada (Invisible)") val="selected-invisible" ;;
                    "Desactivados") val="disabled" ;;
                esac
            elif [[ "$state_key" == "thumb_size" ]]; then
                val="${sel#*\(}"
                val="${val%px\)}"
            elif [[ "$state_key" == "thumb_crop_mode" ]]; then
                case "$sel" in
                    "Cuadrado (Crop)") val="crop" ;;
                    "Completo (Fit)") val="fit" ;;
                esac
            elif [[ "$state_key" == "no_thumb" ]]; then
                case "$sel" in
                    "Cargar imagen original") val="original" ;;
                    "Usar icono genérico") val="icon" ;;
                esac
            fi

            local final_val="${prefix}${val}"
            save_state "$state_key" "$final_val"
            printf -v "$var_name" "%s" "$final_val"

            if [[ "$state_key" == matugen_* || "$state_key" == "bg_generation" ]]; then
                reload_matugen_preview
            fi
        done
    }

    lbl_bool() {
        [[ "$1" == "true" || "$1" == "enabled" ]] && echo "activado" || echo "desactivado"
    }

    get_wp_rule_key() {
        local cur_wall
        cur_wall=$(cat "$HOME/.config/i3/wall" 2>/dev/null)
        [[ -f "$cur_wall" ]] || return 1
        local wp_base=$(basename "$cur_wall")
        local wp_safe="${wp_base//[^a-zA-Z0-9]/_}"
        local mode=$(get_state "active_mode" "dark")
        [[ "$mode" == "settings" ]] && mode=$(get_state "active_mode_real" "dark")
        echo "${wp_safe}.${mode}"
    }

    # Carga e inicialización unificada de variables locales del estado
    load_wp_config
    cur_show_names_mode=$(get_state "show_names_mode" "selected-invisible")
    cur_card_style=$(get_state "card_style" "true")
    cur_card_round_border=$(get_state "card_round_border" "false")
    cur_join_text=$(get_state "join_text" "false")
    cur_ind_text=$(get_state "ind_text" "false")
    cur_ind_block=$(get_state "ind_block" "true")
    cur_ind_border=$(get_state "ind_border" "false")
    cur_ind_underline=$(get_state "ind_underline" "false")
    cur_ind_halo=$(get_state "ind_halo" "false")
    cur_thumb_mode="$THUMB_MODE"
    cur_thumb_size="$THUMB_SIZE"
    cur_no_thumb="$NO_THUMB_MODE"
    cur_bg_gen="$BG_GENERATION"
    cur_matugen_thumb="$MATUGEN_USE_THUMB"
    cur_thumb_crop_mode="$THUMB_CROP_MODE"
    cur_matugen_clean_temp="$MATUGEN_CLEAN_TEMP"
    cur_matugen_use_fit="$MATUGEN_USE_FIT"
    cur_matugen_scheme=$(get_state "matugen_scheme_type" "scheme-tonal-spot")
    cur_matugen_contrast=$(get_state "matugen_contrast" "0.0")
    cur_matugen_prefer=$(get_state "matugen_prefer" "saturation")
    cur_source_color_index=$(get_state "matugen_source_color_index" "0")
    cur_matugen_lightness_dark=$(get_state "matugen_lightness_dark" "0.0")
    cur_matugen_resize_filter=$(get_state "matugen_resize_filter" "gaussian")

    menu_indicadores() {
        while true; do
            local sub_opts=""
            sub_opts+="Texto coloreado: $(lbl_bool "$cur_ind_text")"$'\n'
            sub_opts+="Bloque de texto: $(lbl_bool "$cur_ind_block")"$'\n'
            sub_opts+="Borde de imagen: $(lbl_bool "$cur_ind_border")"$'\n'
            sub_opts+="Subrayado de imagen: $(lbl_bool "$cur_ind_underline")"$'\n'
            sub_opts+="Halo de fondo: $(lbl_bool "$cur_ind_halo")"$'\n'
            sub_opts+="Atrás"

            local sub_choice=$(ask_selection "Indicadores" "$sub_opts")
            [[ -z "$sub_choice" || "$sub_choice" == "Atrás" ]] && break

            case "$sub_choice" in
                "Texto coloreado"*)     toggle_state_val "ind_text" "cur_ind_text" ;;
                "Bloque de texto"*)     toggle_state_val "ind_block" "cur_ind_block" ;;
                "Borde de imagen"*)     toggle_state_val "ind_border" "cur_ind_border" ;;
                "Subrayado de imagen"*) toggle_state_val "ind_underline" "cur_ind_underline" ;;
                "Halo de fondo"*)       toggle_state_val "ind_halo" "cur_ind_halo" ;;
            esac
        done
    }

    menu_visualizacion() {
        while true; do
            local mode_lbl="Todos"
            case "$cur_show_names_mode" in
                "all") mode_lbl="Todos" ;;
                "selected") mode_lbl="Solo en seleccionada" ;;
                "selected-invisible") mode_lbl="Solo en seleccionada (Invisible)" ;;
                "disabled") mode_lbl="Desactivados" ;;
            esac
            
            local vis_opts=""
            vis_opts+="Nombres de wallpapers: $mode_lbl"$'\n'
            vis_opts+="Estilo tarjeta (Card): $(lbl_bool "$cur_card_style")"$'\n'
            if [[ "$cur_card_style" == "true" ]]; then
                vis_opts+="Bordes redondos en tarjeta: $(lbl_bool "$cur_card_round_border")"$'\n'
            fi
            vis_opts+="Unir texto a tarjeta: $(lbl_bool "$cur_join_text")"$'\n'
            vis_opts+="Personalizar indicador de selección..."$'\n'
            vis_opts+="Atrás"

            local vis_choice=$(ask_selection "Visualización" "$vis_opts")
            [[ -z "$vis_choice" || "$vis_choice" == "Atrás" ]] && break

            if [[ "$vis_choice" == "Nombres de wallpapers"* ]]; then
                local modes=$'Todos\nSolo en seleccionada\nSolo en seleccionada (Invisible)\nDesactivados\nAtrás'
                ask_and_apply_loop "Nombres" "$modes" "show_names_mode" "cur_show_names_mode" ""

            elif [[ "$vis_choice" == "Estilo tarjeta (Card)"* ]]; then
                toggle_state_val "card_style" "cur_card_style"

            elif [[ "$vis_choice" == "Bordes redondos en tarjeta"* ]]; then
                toggle_state_val "card_round_border" "cur_card_round_border"

            elif [[ "$vis_choice" == "Unir texto a tarjeta"* ]]; then
                toggle_state_val "join_text" "cur_join_text"

            elif [[ "$vis_choice" == "Personalizar indicador de selección..." ]]; then
                menu_indicadores
            fi
        done
    }

    menu_miniaturas() {
        while true; do
            local mode_lbl="desactivado"
            [[ "$cur_thumb_mode" == "enabled" ]] && mode_lbl="activado"

            local fallback_lbl="Usar icono genérico"
            [[ "$cur_no_thumb" == "original" ]] && fallback_lbl="Cargar imagen original"

            local size_lbl="$cur_thumb_size px"
            case "$cur_thumb_size" in
                300) size_lbl="Baja (300px)" ;;
                450) size_lbl="Media (450px)" ;;
                600) size_lbl="Alta (600px)" ;;
            esac

            local crop_lbl="Completo (Fit)"
            [[ "$cur_thumb_crop_mode" == "crop" ]] && crop_lbl="Cuadrado (Crop)"

            local thumb_opts=""
            thumb_opts+="$PROM_THUMBS: $mode_lbl"$'\n'
            if [[ "$cur_thumb_mode" == "enabled" ]]; then
                thumb_opts+="$PROM_QUALITY: $size_lbl"$'\n'
                thumb_opts+="Recorte de miniatura: $crop_lbl"$'\n'
                thumb_opts+="$PROM_NO_THUMB: $fallback_lbl"$'\n'
            fi
            thumb_opts+="Atrás"

            local thumb_choice=$(ask_selection "Miniaturas" "$thumb_opts")
            [[ -z "$thumb_choice" || "$thumb_choice" == "Atrás" ]] && break

            if [[ "$thumb_choice" == "$PROM_THUMBS"* ]]; then
                local next_mode="enabled"
                [[ "$cur_thumb_mode" == "enabled" ]] && next_mode="disabled"
                save_state "thumbnail_mode" "$next_mode"
                cur_thumb_mode="$next_mode"
                if [[ "$cur_thumb_mode" == "enabled" ]] && [[ "$HAS_VIPS" -eq 0 ]]; then
                    cur_thumb_mode="disabled"
                fi

            elif [[ "$thumb_choice" == "$PROM_QUALITY"* ]]; then
                local sizes=$'Baja (300px)\nMedia (450px)\nAlta (600px)'
                local custom_sizes_file="$WP_STATE_DIR/custom_sizes"
                if [[ -f "$custom_sizes_file" ]]; then
                    while IFS= read -r custom_sz; do
                        [[ -z "$custom_sz" ]] && continue
                        if [[ "$custom_sz" != "300" && "$custom_sz" != "450" && "$custom_sz" != "600" ]]; then
                            sizes+=$'\n'"${custom_sz}px"
                        fi
                    done < "$custom_sizes_file"
                fi
                sizes+=$'\n'"Nueva calidad personalizada..."
                sizes+=$'\n'"Atrás"

                while true; do
                    local selected_sz=$(ask_selection "$PROM_QUALITY" "$sizes")
                    [[ -z "$selected_sz" || "$selected_sz" == "Atrás" ]] && break

                    if [[ "$selected_sz" == "Nueva calidad personalizada..." ]]; then
                        local custom_sz=$(ask_selection "Resolución (px)" "")
                        custom_sz="${custom_sz//[[:space:]]/}"
                        if [[ "$custom_sz" =~ ^[0-9]+$ ]] && [ "$custom_sz" -gt 0 ]; then
                            cur_thumb_size="$custom_sz"
                            save_state "thumbnail_size" "$cur_thumb_size"
                            echo "$custom_sz" >> "$custom_sizes_file"
                            mapfile -t history < <(sort -u "$custom_sizes_file" 2>/dev/null)
                            printf "%s\n" "${history[@]}" > "$custom_sizes_file"
                        fi
                        break
                    else
                        local size_num="${selected_sz//[!0-9]/}"
                        if [[ -n "$size_num" ]]; then
                            cur_thumb_size="$size_num"
                            save_state "thumbnail_size" "$cur_thumb_size"
                        fi
                        break
                    fi
                done

            elif [[ "$thumb_choice" == "Recorte de miniatura"* ]]; then
                local crops=$'Cuadrado (Crop)\nCompleto (Fit)\nAtrás'
                ask_and_apply_loop "Recorte de Miniatura" "$crops" "thumbnail_crop_mode" "cur_thumb_crop_mode" ""

            elif [[ "$thumb_choice" == "$PROM_NO_THUMB"* ]]; then
                local fallbacks=$'Cargar imagen original\nUsar icono genérico\nAtrás'
                ask_and_apply_loop "$PROM_NO_THUMB" "$fallbacks" "no_thumb" "cur_no_thumb" ""
            fi
        done
    }

    write_preset_file() {
        local path="$1"
        cat <<EOF > "$path"
matugen_scheme_type="$2"
matugen_contrast="$3"
matugen_prefer="$4"
matugen_source_color_index="$5"
matugen_lightness_dark="$6"
matugen_resize_filter="$7"
EOF
    }

    menu_presets() {
        local standalone="$1"
        local presets_dir="$WP_STATE_DIR/presets"
        mkdir -p "$presets_dir"

        if [[ ! -f "$presets_dir/Default (Tonal Spot).env" ]]; then
            local defaults=(
                "Default (Tonal Spot)|scheme-tonal-spot|0.0|saturation|0|0.0|gaussian"
                "Centro Oscuro (Acento)|scheme-tonal-spot|0.0|saturation|1|0.0|gaussian"
                "Alto Contraste|scheme-fidelity|0.5|saturation|0|0.0|gaussian"
                "Monocromático|scheme-monochrome|0.0|default|0|0.0|gaussian"
                "Muted (Suave)|scheme-neutral|-0.3|less-saturation|0|0.0|gaussian"
                "Amoled (Negro Puro)|scheme-tonal-spot|0.0|saturation|0|-0.5|gaussian"
                "Píxel Puro (Vivos)|scheme-fidelity|0.3|saturation|0|0.0|nearest"
            )
            for p in "${defaults[@]}"; do
                IFS='|' read -r name type contrast prefer index ldark rfilter <<< "$p"
                write_preset_file "$presets_dir/$name.env" "$type" "$contrast" "$prefer" "$index" "$ldark" "$rfilter"
            done
        fi

        while true; do
            local opts=""
            for f in "$presets_dir"/*.env; do
                if [[ -f "$f" ]]; then
                    local name
                    name=$(basename "$f" .env)
                    opts+="$name"$'\n'
                fi
            done
            opts+="Guardar Preset Actual..."$'\n'
            opts+="Eliminar Preset..."$'\n'
            
            if [[ "$standalone" -ne 1 ]]; then
                opts+="Atrás"
            fi

            local choice
            choice=$(ask_selection "Presets" "$opts")
            [[ -z "$choice" || "$choice" == "Atrás" ]] && break

            if [[ "$choice" == "Guardar Preset Actual..." ]]; then
                local name
                name=$(rofi -dmenu -p "Nombre Preset" -theme "${BAR_SEL_THEME:-$HOME/.config/rofi/themes/shared/menu_generic.rasi}")
                name=$(echo "$name" | xargs)
                if [[ -n "$name" ]]; then
                    local cur_type=$(get_state "matugen_scheme_type" "scheme-tonal-spot")
                    local cur_contrast=$(get_state "matugen_contrast" "0.0")
                    local cur_prefer=$(get_state "matugen_prefer" "saturation")
                    local cur_index=$(get_state "matugen_source_color_index" "0")
                    local cur_ldark=$(get_state "matugen_lightness_dark" "0.0")
                    local cur_rfilter=$(get_state "matugen_resize_filter" "gaussian")

                    write_preset_file "$presets_dir/$name.env" "$cur_type" "$cur_contrast" "$cur_prefer" "$cur_index" "$cur_ldark" "$cur_rfilter"

                fi

            elif [[ "$choice" == "Eliminar Preset..." ]]; then
                local del_opts=""
                for f in "$presets_dir"/*.env; do
                    if [[ -f "$f" ]]; then
                        local name
                        name=$(basename "$f" .env)
                        del_opts+="$name"$'\n'
                    fi
                done
                del_opts+="Atrás"

                local del_choice
                del_choice=$(ask_selection "Eliminar Preset" "$del_opts")
                if [[ -n "$del_choice" && "$del_choice" != "Atrás" ]]; then
                    rm -f "$presets_dir/$del_choice.env"

                fi

            else
                local preset_file="$presets_dir/$choice.env"
                if [[ -f "$preset_file" ]]; then
                    source "$preset_file"
                    save_state "matugen_scheme_type" "$matugen_scheme_type"
                    save_state "matugen_contrast" "$matugen_contrast"
                    save_state "matugen_prefer" "$matugen_prefer"
                    save_state "matugen_source_color_index" "$matugen_source_color_index"
                    save_state "matugen_lightness_dark" "$matugen_lightness_dark"
                    save_state "matugen_resize_filter" "$matugen_resize_filter"

                    cur_matugen_scheme="$matugen_scheme_type"
                    cur_matugen_contrast="$matugen_contrast"
                    cur_matugen_prefer="$matugen_prefer"
                    cur_source_color_index="$matugen_source_color_index"
                    cur_matugen_lightness_dark="$matugen_lightness_dark"
                    cur_matugen_resize_filter="$matugen_resize_filter"

                    local cur_wall
                    cur_wall=$(cat "$HOME/.config/i3/wall" 2>/dev/null)
                    if [[ -f "$cur_wall" ]]; then
                        local cur_active_mode
                        cur_active_mode=$(get_state "active_mode" "dark")
                        (
                            if [[ "$cur_active_mode" == "light" ]]; then
                                engine_matugen.sh -m light
                            else
                                engine_matugen.sh -m dark
                            fi
                            apply_dots.sh
                        ) &>/dev/null &
                    fi



                    if [[ "$standalone" -eq 1 ]]; then
                        exit 0
                    fi
                fi
            fi
        done
    }

    reload_matugen_preview() {
        local cur_wall
        cur_wall=$(cat "$HOME/.config/i3/wall" 2>/dev/null)
        if [[ -f "$cur_wall" ]]; then
            local cur_active_mode
            cur_active_mode=$(get_state "active_mode" "dark")
            [[ "$cur_active_mode" == "settings" ]] && cur_active_mode=$(get_state "active_mode_real" "dark")

            (
                engine_matugen.sh -m "$cur_active_mode"
                apply_dots.sh
            ) &>/dev/null &
        fi

    }

    menu_color_advanced() {
        while true; do
            local adv_opts=""
            adv_opts+="Preferencia: $cur_matugen_prefer"$'\n'
            adv_opts+="Filtro de redimensión: $cur_matugen_resize_filter"$'\n'
            if [[ "$cur_thumb_crop_mode" == "crop" ]]; then
                adv_opts+="Usar imagen completa: $(lbl_bool "$cur_matugen_use_fit")"$'\n'
            fi
            adv_opts+="Atrás"

            local adv_choice=$(ask_selection "Color Avanzado" "$adv_opts")
            [[ -z "$adv_choice" || "$adv_choice" == "Atrás" ]] && break

            local trigger_reload=0

            if [[ "$adv_choice" == "Preferencia:"* ]]; then
                local prefers=$'Ninguna (Por defecto)\nsaturation\nless-saturation\ndarkness\nlightness\nvalue\nclosest-to-fallback\nAtrás'
                ask_and_apply_loop "Preferencias" "$prefers" "matugen_prefer" "cur_matugen_prefer" ""

            elif [[ "$adv_choice" == "Filtro de redimensión:"* ]]; then
                local filters=$'gaussian (Suave)\nnearest (Pixel Puro)\nlanczos3 (Detalle alto)\ntriangle (Medio)\ncatmull-rom\nAtrás'
                ask_and_apply_loop "Filtro de Redimensión" "$filters" "matugen_resize_filter" "cur_matugen_resize_filter" ""

            elif [[ "$adv_choice" == "Usar imagen completa:"* ]]; then
                toggle_state_val "matugen_use_fit" "cur_matugen_use_fit"
                trigger_reload=1
            fi

            if [[ "$trigger_reload" -eq 1 ]]; then
                reload_matugen_preview
            fi
        done
    }

    menu_color_engine() {
        while true; do
            local eng_opts=""
            eng_opts+="$PROM_BG_GEN: $(lbl_bool "$cur_bg_gen")"$'\n'
            eng_opts+="Generación rápida (Thumb): $(lbl_bool "$cur_matugen_thumb")"$'\n'
            if [[ "$cur_thumb_crop_mode" == "crop" ]]; then
                eng_opts+="Limpieza de temporales: $(lbl_bool "$cur_matugen_clean_temp")"$'\n'
            fi
            eng_opts+="Atrás"

            local eng_choice=$(ask_selection "Ajustes del Motor" "$eng_opts")
            [[ -z "$eng_choice" || "$eng_choice" == "Atrás" ]] && break

            local trigger_reload=0

            if [[ "$eng_choice" == "$PROM_BG_GEN"* ]]; then
                toggle_state_val "bg_generation" "cur_bg_gen"
                trigger_reload=1

            elif [[ "$eng_choice" == "Generación rápida"* ]]; then
                toggle_state_val "matugen_use_thumb" "cur_matugen_thumb"
                trigger_reload=1

            elif [[ "$eng_choice" == "Limpieza de temporales"* ]]; then
                toggle_state_val "matugen_clean_temp" "cur_matugen_clean_temp"
                trigger_reload=1
            fi

            if [[ "$trigger_reload" -eq 1 ]]; then
                reload_matugen_preview
            fi
        done
    }

    menu_color() {
        while true; do
            local scheme_display="${cur_matugen_scheme#scheme-}"

            local color_opts=""
            color_opts+="Presets de Matugen..."$'\n'
            color_opts+="Esquema: $scheme_display"$'\n'
            color_opts+="Índice de color base: $cur_source_color_index"$'\n'
            color_opts+="Contraste: $cur_matugen_contrast"$'\n'
            color_opts+="Luminosidad (Oscuro): $cur_matugen_lightness_dark"$'\n'
            color_opts+="Ajustes de color avanzados..."$'\n'
            color_opts+="Ajustes técnicos del motor..."$'\n'

            local has_rule=0
            local rule_key
            rule_key=$(get_wp_rule_key)
            if [[ -n "$rule_key" ]]; then
                local rules_file="$WP_STATE_DIR/rules.env"
                [[ -f "$rules_file" ]] && grep -q "^${rule_key}=" "$rules_file" && has_rule=1
            fi

            color_opts+="Fijar para este wallpaper"$'\n'
            if [[ "$has_rule" -eq 1 ]]; then
                color_opts+="Desfijar de este wallpaper"$'\n'
            fi
            color_opts+="Atrás"

            local color_choice=$(ask_selection "Colores" "$color_opts")
            [[ -z "$color_choice" || "$color_choice" == "Atrás" ]] && break

            local trigger_reload=0

            if [[ "$color_choice" == "Presets de Matugen..." ]]; then
                menu_presets

            elif [[ "$color_choice" == "Esquema:"* ]]; then
                local schemes=$'tonal-spot\nfidelity\ncontent\nneutral\nmonochrome\nexpressive\nAtrás'
                ask_and_apply_loop "Esquemas" "$schemes" "matugen_scheme_type" "cur_matugen_scheme" "scheme-"

            elif [[ "$color_choice" == "Índice de color base:"* ]]; then
                local indices=$'0 (Dominante)\n1 (Secundario/Centro)\n2 (Terciario)\n3\n4\nAtrás'
                ask_and_apply_loop "Índice de Color" "$indices" "matugen_source_color_index" "cur_source_color_index" ""

            elif [[ "$color_choice" == "Contraste:"* ]]; then
                local contrasts=$'0.0\n0.3\n0.5\n-0.3\nAtrás'
                ask_and_apply_loop "Contraste" "$contrasts" "matugen_contrast" "cur_matugen_contrast" ""

            elif [[ "$color_choice" == "Luminosidad (Oscuro):"* ]]; then
                local lightnesses=$'0.0 (Predeterminado)\n-0.5 (Amoled)\n-0.3 (Ultra Oscuro)\n-0.1 (Oscuro suave)\n0.2 (Gris claro)\n0.5 (Gris muy claro)\nAtrás'
                ask_and_apply_loop "Luminosidad" "$lightnesses" "matugen_lightness_dark" "cur_matugen_lightness_dark" ""

            elif [[ "$color_choice" == "Ajustes de color avanzados..." ]]; then
                menu_color_advanced

            elif [[ "$color_choice" == "Ajustes técnicos del motor..." ]]; then
                menu_color_engine

            elif [[ "$color_choice" == "Fijar para este wallpaper" ]]; then
                if [[ -n "$rule_key" ]]; then
                    local rule_val="${cur_matugen_scheme}|${cur_matugen_contrast}|${cur_matugen_prefer}|${cur_source_color_index}|${cur_matugen_lightness_dark}|${cur_matugen_resize_filter}"
                    local rules_file="$WP_STATE_DIR/rules.env"
                    touch "$rules_file"
                    if grep -q "^${rule_key}=" "$rules_file"; then
                        sed -i "s|^${rule_key}=.*|${rule_key}=\"${rule_val}\"|" "$rules_file"
                    else
                        echo "${rule_key}=\"${rule_val}\"" >> "$rules_file"
                    fi

                fi

            elif [[ "$color_choice" == "Desfijar de este wallpaper" ]]; then
                if [[ -n "$rule_key" ]]; then
                    local rules_file="$WP_STATE_DIR/rules.env"
                    if [[ -f "$rules_file" ]]; then
                        sed -i "/^${rule_key}=/d" "$rules_file"
                    fi

                    trigger_reload=1
                fi
            fi

            if [[ "$trigger_reload" -eq 1 ]]; then
                reload_matugen_preview
            fi
        done
    }

    menu_cache() {
        while true; do
            local cache_opts=""
            cache_opts+="Generar Caché de Miniaturas Ahora"$'\n'
            cache_opts+="$PROM_CLEAN"$'\n'
            cache_opts+="Atrás"

            local cache_choice=$(ask_selection "Caché" "$cache_opts")
            [[ -z "$cache_choice" || "$cache_choice" == "Atrás" ]] && break

            if [[ "$cache_choice" == "Generar Caché de Miniaturas Ahora" ]]; then

                wp_cache.sh --cache-now &

            elif [[ "$cache_choice" == "$PROM_CLEAN"* ]]; then
                local cleans=$'Borrar huérfanos\nActiva actual ('"${cur_thumb_size}"$'px)\nBaja (300px)\nMedia (450px)\nAlta (600px)\nTodo excepto la calidad activa\nToda la caché\nAtrás'
                local selected_cl=$(ask_selection "$PROM_CLEAN" "$cleans")
                if [[ -n "$selected_cl" && "$selected_cl" != "Atrás" ]]; then
                    local clean_opt="orphans"
                    case "$selected_cl" in
                        "Borrar huérfanos") clean_opt="orphans" ;;
                        "Baja (300px)") clean_opt="300" ;;
                        "Media (450px)") clean_opt="450" ;;
                        "Alta (600px)") clean_opt="600" ;;
                        "Activa actual"*) clean_opt="$cur_thumb_size" ;;
                        "Todo excepto la calidad activa") clean_opt="keep-active" ;;
                        "Toda la caché") clean_opt="full" ;;
                    esac
                    
                    wp_cache.sh --clean-cache "$clean_opt"

                fi
            fi
        done
    }

    configure_wallpaper() {
        while true; do
            local main_opts=""
            main_opts+="Personalizar visualización..."$'\n'
            main_opts+="Ajustes de miniaturas..."$'\n'
            main_opts+="Ajustes de color (Matugen)..."$'\n'
            main_opts+="Mantenimiento de caché..."$'\n'
            main_opts+="Salir"

            local choice=$(ask_selection "Ajustes de Wallpaper" "$main_opts")
            [[ -z "$choice" || "$choice" == "Salir" || "$choice" == "Atrás" ]] && break

            case "$choice" in
                "Personalizar visualización...") menu_visualizacion ;;
                "Ajustes de miniaturas...") menu_miniaturas ;;
                "Ajustes de color (Matugen)...") menu_color ;;
                "Mantenimiento de caché...") menu_cache ;;
            esac
        done
    }

    if [[ "$PRESETS_ONLY" -eq 1 ]]; then
        menu_presets 1
    else
        configure_wallpaper
    fi
    exit 0
fi

# 6. Selector Principal de Wallpapers (Grid de Imágenes o Consola)
wallpapers_found=$(list_wallpapers)

if [[ -z "$wallpapers_found" ]]; then
    echo "Error: No se encontraron wallpapers en $WALLPAPER_DIR" >&2
    exit 1
fi

if [[ "$USE_CLI" -eq 1 ]]; then
    # Modo Consola (CLI)
    mapfile -t wallpapers <<< "$wallpapers_found"
    for i in "${!wallpapers[@]}"; do
        printf "%3d) %s\n" "$((i+1))" "${wallpapers[$i]##*/}" >&2
    done
    while true; do
        read -p "Numero (q salir): " choice >&2
        if [[ "$choice" == "q" || "$choice" == "Q" ]]; then exit 1; fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#wallpapers[@]}" ]; then
            SELECTION="${wallpapers[$((choice-1))]}"
            break
        fi
    done
else
    # Modo Gráfico (GUI - Rofi con Grid de Imágenes)
    SEL_BIN="${WP_SEL_BIN:-rofi}"
    SEL_ARGS=(${WP_SEL_ARGS:--dmenu -p "Wallpaper" -theme "${ROFI_THEME}"})
    LINE_TMPL="${WP_SEL_LINE_TMPL:-%f\x00icon\x1f%p}"

    [[ -d "$THUMB_DIR" ]] || mkdir -p "$THUMB_DIR"

    tmp_rofi_opts=$(mktemp)
    generate_rofi_list "$LINE_TMPL" > "$tmp_rofi_opts"

    # Lanzar Rofi de selección principal
    tmp_choice="/dev/shm/wall_menu_choice_${UID}.choice"
    if [[ "$SEL_BIN" == *"rofi"* ]]; then
        eval "\"\$SEL_BIN\" \"\${SEL_ARGS[@]}\" $WP_SEL_STYLE -format 's' < \"\$tmp_rofi_opts\"" > "$tmp_choice"
    else
        eval "\"\$SEL_BIN\" \"\${SEL_ARGS[@]}\" $WP_SEL_STYLE < \"\$tmp_rofi_opts\"" > "$tmp_choice"
    fi

    FINAL_NAME=""
    [[ -f "$tmp_choice" ]] && read -r FINAL_NAME < "$tmp_choice"
    rm -f "$tmp_choice" "$tmp_rofi_opts"

    [[ -z "$FINAL_NAME" ]] && exit 1
    SELECTION="$FINAL_NAME"
fi

# 7. Invocar Backend y Helpers para aplicar y guardar estado
if [[ -n "$SELECTION" ]]; then
    FINAL_PATH=""
    if [[ -f "$SELECTION" ]]; then
        FINAL_PATH=$(readlink -f "$SELECTION")
    elif [[ -f "$WALLPAPER_DIR/$SELECTION" ]]; then
        FINAL_PATH=$(readlink -f "$WALLPAPER_DIR/$SELECTION")
    else
        FINAL_PATH="$SELECTION"
    fi
    
    # Actualizar origen de color para Matugen de forma local (evita fork de wp_color.sh)
    color_src="$FINAL_PATH"
    if [[ "$THUMB_MODE" == "enabled" && "$MATUGEN_USE_THUMB" == "true" ]]; then
        get_thumb_path "$FINAL_PATH"
        [[ -f "$RET_THUMB" ]] && color_src="$RET_THUMB"
    fi
    ln -sf "$color_src" "$WP_STATE_DIR/color_source"
    
    # Asegurar que BIN_DIR esté definida si se ejecuta de forma externa (Rofi/Gestores)
    [[ -z "$BIN_DIR" ]] && BIN_DIR="${BASE_DIR:-$HOME/.config/i3dots}/core/bin"

    # Aplicar wallpaper en pantalla de forma desvinculada para no morir por SIGHUP al cerrarse Rofi
    setsid "$BIN_DIR/wp_select.sh" -C "$FINAL_PATH" < /dev/null > /dev/null 2>&1 &
    exit 0
else
    exit 1
fi
