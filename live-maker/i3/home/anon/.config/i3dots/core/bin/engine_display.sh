#!/usr/bin/env bash
# core/bin/engine_display.sh - Motor de gestión de resoluciones universal optimizado

# 1. Resolver Directorios y Fallbacks
export BASE_DIR="${BASE_DIR:-$HOME/.config/i3dots}"
export CORE_DIR="${CORE_DIR:-$BASE_DIR/core}"
export STATE_DIR="${STATE_DIR:-$CORE_DIR/state}"
export PACKAGES_DIR="${PACKAGES_DIR:-$BASE_DIR/packages}"
export CURRENT_ENV="${CURRENT_ENV:-i3dots}"
export PACKAGE_DIR="${PACKAGE_DIR:-$PACKAGES_DIR/$CURRENT_ENV}"
export HOOK_DIR="${HOOK_DIR:-$PACKAGE_DIR/hooks}"

if [ -f "$PACKAGE_DIR/config.env" ]; then
    source "$PACKAGE_DIR/config.env"
fi

# Ruta del hook de pantalla e importación
DISPLAY_HOOK="$HOOK_DIR/components/display.sh"
DISPLAY_STATE_DIR="$STATE_DIR/$CURRENT_ENV/display"
STATE_FILE="$DISPLAY_STATE_DIR/state.env"

if [ ! -f "$DISPLAY_HOOK" ]; then
    echo "Error: Hook de pantalla no encontrado en $DISPLAY_HOOK" >&2
    exit 1
fi
source "$DISPLAY_HOOK"

# Cargar estado si existe
[ -f "$STATE_FILE" ] && source "$STATE_FILE"

DISPLAY_SUPPORTED_OPTIONS=""
if [ -n "$DISPLAY_HOOK" ] && [ -f "$DISPLAY_HOOK" ]; then
    while IFS='=' read -r key val; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        case "$key" in
            supported_options) DISPLAY_SUPPORTED_OPTIONS="$val" ;;
        esac
    done < <(bash "$DISPLAY_HOOK" --query 2>/dev/null)
fi

# Configuración de UI, Glifos y Prompts
if [ -z "$DISP_SEL_BIN" ]; then
    echo "Error: DISP_SEL_BIN no configurado en entorno." >&2
    exit 1
fi

DISP_SEL_ARGS_ARR=($DISP_SEL_ARGS)
if [ -n "$DISP_CONF_ARGS" ]; then
    DISP_CONF_ARGS_ARR=($DISP_CONF_ARGS)
else
    DISP_CONF_ARGS_ARR=("${DISP_SEL_ARGS_ARR[@]}")
fi

GLYPH_MONITOR="${DISP_GLYPH_MONITOR:-}"
GLYPH_RESOLUTION="${DISP_GLYPH_RESOLUTION:-}"
GLYPH_RATE="${DISP_GLYPH_RATE:-}"
GLYPH_SCALE="${DISP_GLYPH_SCALE:-}"
GLYPH_ROTATION="${DISP_GLYPH_ROTATION:-}"
GLYPH_BRIGHTNESS="${DISP_GLYPH_BRIGHTNESS:-}"
GLYPH_FILTER="${DISP_GLYPH_FILTER:-}"
GLYPH_CONFIRM="${DISP_GLYPH_CONFIRM:-}"

PROM_MAIN="${DISP_PROM_MAIN:-Configuración de Pantalla}"
PROM_TIMEOUT="${DISP_PROM_TIMEOUT:-Tiempo de Confirmación}"
PROM_MONITOR="${DISP_PROM_MONITOR:-Pantalla}"
PROM_RESOLUTION="${DISP_PROM_RESOLUTION:-Resolución}"
PROM_RATE="${DISP_PROM_RATE:-Frecuencia}"
PROM_SCALE="${DISP_PROM_SCALE:-Escala}"
PROM_ROTATION="${DISP_PROM_ROTATION:-Rotación}"
PROM_BRIGHTNESS="${DISP_PROM_BRIGHTNESS:-Brillo}"
PROM_FILTER="${DISP_PROM_FILTER:-Nitidez}"
PROM_CONFIRM="${DISP_PROM_CONFIRM:-¿Mantener resolución?}"
PROM_MSG="${DISP_PROM_MSG:-Se revertirá automáticamente tras %s segundos de inactividad.}"

PROM_MENU_OUTPUT="${DISP_PROM_MENU_OUTPUT:-1. Pantalla}"
PROM_MENU_RES="${DISP_PROM_MENU_RES:-2. Resolución}"
PROM_MENU_RATE="${DISP_PROM_MENU_RATE:-3. Frecuencia}"
PROM_MENU_SCALE="${DISP_PROM_MENU_SCALE:-4. Escala}"
PROM_MENU_ROTATION="${DISP_PROM_MENU_ROTATION:-5. Rotación}"
PROM_MENU_BRIGHTNESS="${DISP_PROM_MENU_BRIGHTNESS:-6. Brillo}"
PROM_MENU_FILTER="${DISP_PROM_MENU_FILTER:-7. Nitidez}"
PROM_MENU_TIME="${DISP_PROM_MENU_TIME:-8. Tiempo Confirmación}"
PROM_MENU_APPLY="${DISP_PROM_MENU_APPLY:-9. [ Aplicar y Probar ]}"
PROM_MENU_CANCEL="${DISP_PROM_MENU_CANCEL:-10. [ Cancelar y Salir ]}"

PROM_VAL_NONE="${DISP_PROM_VAL_NONE:-No seleccionada}"
PROM_VAL_AUTO="${DISP_PROM_VAL_AUTO:-Auto}"

VAL_CONFIRM="${DISP_VAL_CONFIRM:-Confirmar}"
VAL_REVERT="${DISP_VAL_REVERT:-Revertir}"

PROM_TIMES="${DISP_PROM_TIMES:-}"
PROM_SCALES="${DISP_PROM_SCALES:-}"
PROM_ROTATIONS="${DISP_PROM_ROTATIONS:-}"
PROM_BRIGHTNESSES="${DISP_PROM_BRIGHTNESSES:-}"
PROM_FILTERS="${DISP_PROM_FILTERS:-}"
UNIT_RATE="${DISP_UNIT_RATE:-}"
VAL_CUSTOM="${DISP_VAL_CUSTOM:-}"
VAL_CUSTOM_SCALE="${DISP_VAL_CUSTOM_SCALE:-}"

STATE_ENGINE=(bash "$CORE_DIR/bin/engine_state.sh" display)

# 2. Funciones de Flujo
init_display() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "Aviso: No hay estados de pantalla guardados."
        if [ "${DISP_INIT_POST_APPLY:-true}" = "true" ]; then
            hook_post_apply
        fi
        exit 0
    fi
    
    # Sincronizar variables
    source "$STATE_FILE"
    
    if [ -z "$outputs" ]; then
        echo "Aviso: Lista de salidas guardadas vacía."
        exit 0
    fi
    
    local applied=0
    for output in $outputs; do
        local monitor_clean="${output//-/_}"
        monitor_clean="${monitor_clean//./_}"
        
        local res_var="resolution_${monitor_clean}"
        local resolution="${!res_var}"
        [ -z "$resolution" ] && continue
        
        local rate_var="rate_${monitor_clean}"
        local rate="${!rate_var}"
        if [[ -z "$rate" || "$rate" == [Aa]uto || ! "$rate" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [ -n "$resolution" ]; then
            hook_query_rates "$output" "$resolution"
            rate=$(head -n 1 <<< "$RET_LIST" | tr -d '[:space:]')
        fi
        
        local scale_var="scale_${monitor_clean}"
        local scale="${!scale_var}"
        
        local rot_var="rotation_${monitor_clean}"
        local rotation="${!rot_var}"
        
        local bri_var="brightness_${monitor_clean}"
        local brightness="${!bri_var}"
        
        local extra_args=()
        if [ -n "$DISPLAY_SUPPORTED_OPTIONS" ]; then
            IFS='|' read -ra OPT_ARRAY <<< "$DISPLAY_SUPPORTED_OPTIONS"
            for opt in "${OPT_ARRAY[@]}"; do
                [ -z "$opt" ] && continue
                IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
                local opt_var="${opt_key}_${monitor_clean}"
                local opt_val="${!opt_var}"
                extra_args+=("${opt_val:-${opt_vals%%,*}}")
            done
        fi
        
        echo "Inicializando $output -> $resolution ${rate:+@ $rate} ${scale:+[x$scale]} ${rotation:+[$rotation]} ${brightness:+[brightness $brightness]} ${extra_args[*]:+[dynamic ${extra_args[*]}]}"
        hook_apply "$output" "$resolution" "$rate" "$scale" "$rotation" "$brightness" "${extra_args[@]}"
        applied=1
    done
    
    if [ "$applied" -eq 1 ] && [ "${DISP_INIT_POST_APPLY:-true}" = "true" ]; then
        hook_post_apply
    fi
}

select_display_interactive() {
    hook_load_cache
    hook_query_default
    local SEL_OUTPUT="$RET_OUT"
    local SEL_RES="$RET_RES"
    local SEL_RATE="$RET_RATE"
    
    if [ -z "$SEL_OUTPUT" ]; then
        echo "Error: No se detectaron salidas de pantalla activas." >&2
        exit 1
    fi
    
    if [[ -z "$SEL_RATE" || "$SEL_RATE" == [Aa]uto || ! "$SEL_RATE" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [ -n "$SEL_RES" ]; then
        hook_query_rates "$SEL_OUTPUT" "$SEL_RES"
        SEL_RATE=$(head -n 1 <<< "$RET_LIST" | tr -d '[:space:]')
    fi
    
    hook_get_current_scale "$SEL_OUTPUT"
    local SEL_SCALE="$RET_SCALE"
    SEL_SCALE="${SEL_SCALE:-1.0}"
    
    hook_get_current_rotation "$SEL_OUTPUT"
    local SEL_ROTATION="$RET_ROTATION"
    SEL_ROTATION="${SEL_ROTATION:-normal}"
    
    hook_get_current_brightness "$SEL_OUTPUT"
    local SEL_BRIGHTNESS="$RET_BRIGHTNESS"
    SEL_BRIGHTNESS="${SEL_BRIGHTNESS:-1.0}"
    
    local monitor_clean="${SEL_OUTPUT//-/_}"
    monitor_clean="${monitor_clean//./_}"
    
    # Inicializar opciones dinámicas en memoria
    declare -A DYNAMIC_VALS
    if [ -n "$DISPLAY_SUPPORTED_OPTIONS" ]; then
        IFS='|' read -ra OPT_ARRAY <<< "$DISPLAY_SUPPORTED_OPTIONS"
        for opt in "${OPT_ARRAY[@]}"; do
            [ -z "$opt" ] && continue
            IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
            local opt_var="${opt_key}_${monitor_clean}"
            local val="${!opt_var}"
            DYNAMIC_VALS["$opt_key"]="${val:-${opt_vals%%,*}}"
        done
    fi
    
    local SEL_TIMEOUT="${timeout:-15}"
    local tmp_choice=$(mktemp)
    
    while true; do
        local menu_options=""
        menu_options+="${PROM_MENU_OUTPUT}: $SEL_OUTPUT"$'\n'
        menu_options+="${PROM_MENU_RES}: ${SEL_RES:-$PROM_VAL_NONE}"$'\n'
        menu_options+="${PROM_MENU_RATE}: ${SEL_RATE:-$PROM_VAL_AUTO}${SEL_RATE:+${UNIT_RATE}}"$'\n'
        menu_options+="${PROM_MENU_SCALE}: ${SEL_SCALE}"$'\n'
        menu_options+="${PROM_MENU_ROTATION}: ${SEL_ROTATION}"$'\n'
        menu_options+="${PROM_MENU_BRIGHTNESS}: ${SEL_BRIGHTNESS}"$'\n'
        
        local menu_idx=7
        if [ -n "$DISPLAY_SUPPORTED_OPTIONS" ]; then
            for opt in "${OPT_ARRAY[@]}"; do
                [ -z "$opt" ] && continue
                IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
                menu_options+="${menu_idx}. ${opt_label}: ${DYNAMIC_VALS[$opt_key]}"$'\n'
                menu_idx=$((menu_idx+1))
            done
        fi
        
        local idx_time=$menu_idx
        local idx_apply=$((menu_idx+1))
        local idx_cancel=$((menu_idx+2))
        
        menu_options+="${idx_time}. ${PROM_TIMEOUT#*. }: ${SEL_TIMEOUT}s"$'\n'
        menu_options+="${idx_apply}. ${PROM_MENU_APPLY#*. }"$'\n'
        menu_options+="${idx_cancel}. ${PROM_MENU_CANCEL#*. }"
        
        "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "$PROM_MAIN" <<< "$menu_options" > "$tmp_choice"
        IFS= read -r choice < "$tmp_choice"
        [ -z "$choice" ] && break
        
        case "$choice" in
            *"$PROM_MENU_OUTPUT"*)
                hook_query_outputs
                local outputs_list="$RET_LIST"
                local op_list=""
                while IFS= read -r op; do
                    [ -z "$op" ] && continue
                    op_list+="${GLYPH_MONITOR}${op}"$'\n'
                done <<< "$outputs_list"
                
                op_list="${op_list%$'\n'}"
                
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_MONITOR}${PROM_MONITOR}" <<< "$op_list" > "$tmp_choice"
                IFS= read -r new_out < "$tmp_choice"
                
                if [ -n "$new_out" ]; then
                    new_out="${new_out#$GLYPH_MONITOR}"
                    new_out="${new_out//[[:space:]]/}"
                    SEL_OUTPUT="$new_out"
                    
                    monitor_clean="${new_out//-/_}"
                    monitor_clean="${monitor_clean//./_}"
                    
                    hook_get_current_all "$new_out"
                    SEL_RES="$RET_RES"
                    SEL_RATE="$RET_RATE"
                    if [[ -z "$SEL_RATE" || "$SEL_RATE" == [Aa]uto || ! "$SEL_RATE" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [ -n "$SEL_RES" ]; then
                        hook_query_rates "$new_out" "$SEL_RES"
                        SEL_RATE=$(head -n 1 <<< "$RET_LIST" | tr -d '[:space:]')
                    fi
                    
                    hook_get_current_scale "$new_out"
                    SEL_SCALE="$RET_SCALE"
                    SEL_SCALE="${SEL_SCALE:-1.0}"
                    
                    hook_get_current_rotation "$new_out"
                    SEL_ROTATION="$RET_ROTATION"
                    SEL_ROTATION="${SEL_ROTATION:-normal}"
                    
                    hook_get_current_brightness "$new_out"
                    SEL_BRIGHTNESS="$RET_BRIGHTNESS"
                    SEL_BRIGHTNESS="${SEL_BRIGHTNESS:-1.0}"
                    
                    if [ -n "$DISPLAY_SUPPORTED_OPTIONS" ]; then
                        for opt in "${OPT_ARRAY[@]}"; do
                            [ -z "$opt" ] && continue
                            IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
                            local opt_var="${opt_key}_${monitor_clean}"
                            local val="${!opt_var}"
                            DYNAMIC_VALS["$opt_key"]="${val:-${opt_vals%%,*}}"
                        done
                    fi
                fi
                ;;
                
            *"$PROM_MENU_RES"*)
                if [ -z "$SEL_OUTPUT" ]; then
                    continue
                fi
                hook_query_modes "$SEL_OUTPUT"
                local modes="$RET_LIST"
                local res_list=""
                while IFS= read -r res; do
                    [ -z "$res" ] && continue
                    res_list+="${GLYPH_RESOLUTION}${res}"$'\n'
                done <<< "$modes"
                
                res_list="${res_list%$'\n'}"
                
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_RESOLUTION}${PROM_RESOLUTION}" <<< "$res_list" > "$tmp_choice"
                IFS= read -r new_res < "$tmp_choice"
                
                if [ -n "$new_res" ]; then
                    new_res="${new_res#$GLYPH_RESOLUTION}"
                    new_res="${new_res//[[:space:]]/}"
                    SEL_RES="$new_res"
                    hook_query_rates "$SEL_OUTPUT" "$new_res"
                    SEL_RATE=$(head -n 1 <<< "$RET_LIST" | tr -d '[:space:]')
                fi
                ;;
                
            *"$PROM_MENU_RATE"*)
                if [ -z "$SEL_OUTPUT" ] || [ -z "$SEL_RES" ]; then
                    continue
                fi
                hook_query_rates "$SEL_OUTPUT" "$SEL_RES"
                local rates="$RET_LIST"
                if [ -z "$rates" ]; then
                    continue
                fi
                local rate_list=""
                while IFS= read -r r; do
                    [ -z "$r" ] && continue
                    rate_list+="${GLYPH_RATE}${r}${UNIT_RATE}"$'\n'
                done <<< "$rates"
                
                rate_list="${rate_list%$'\n'}"
                
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_RATE}${PROM_RATE}" <<< "$rate_list" > "$tmp_choice"
                IFS= read -r new_rate < "$tmp_choice"
                
                if [ -n "$new_rate" ]; then
                    new_rate="${new_rate#$GLYPH_RATE}"
                    new_rate="${new_rate%${UNIT_RATE}}"
                    new_rate="${new_rate//[[:space:]]/}"
                    SEL_RATE="$new_rate"
                fi
                ;;
                
            *"$PROM_MENU_SCALE"*)
                local scales_list
                printf -v scales_list "%b" "$PROM_SCALES"
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_SCALE}${PROM_SCALE}" <<< "$scales_list" > "$tmp_choice"
                IFS= read -r new_scale < "$tmp_choice"
                
                if [ -n "$new_scale" ]; then
                    new_scale="${new_scale//[[:space:]]/}"
                    
                    if [ "$new_scale" = "$VAL_CUSTOM_SCALE" ] || [ "$new_scale" = "personalizada" ] || [ "$new_scale" = "custom" ]; then
                        "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "Escala (ej: 1.3)" <<< "" > "$tmp_choice"
                        IFS= read -r custom_scale < "$tmp_choice"
                        custom_scale="${custom_scale//[[:space:]]/}"
                        custom_scale="${custom_scale//,/.}"
                        if [[ "$custom_scale" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [ $(awk -v cs="$custom_scale" 'BEGIN { print (cs > 0) }') -eq 1 ]; then
                            new_scale="$custom_scale"
                        else
                            continue
                        fi
                    fi
                    SEL_SCALE="$new_scale"
                fi
                ;;
                
            *"$PROM_MENU_ROTATION"*)
                local rotations_list
                printf -v rotations_list "%b" "$PROM_ROTATIONS"
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_ROTATION}${PROM_ROTATION}" <<< "$rotations_list" > "$tmp_choice"
                IFS= read -r new_rot < "$tmp_choice"
                
                if [ -n "$new_rot" ]; then
                    new_rot="${new_rot//[[:space:]]/}"
                    SEL_ROTATION="$new_rot"
                fi
                ;;
                
            *"$PROM_MENU_BRIGHTNESS"*)
                local brightnesses_list
                printf -v brightnesses_list "%b" "$PROM_BRIGHTNESSES"
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_BRIGHTNESS}${PROM_BRIGHTNESS}" <<< "$brightnesses_list" > "$tmp_choice"
                IFS= read -r new_bri < "$tmp_choice"
                
                if [ -n "$new_bri" ]; then
                    new_bri="${new_bri//[[:space:]]/}"
                    
                    if [ "$new_bri" = "$VAL_CUSTOM" ] || [ "$new_bri" = "personalizado" ] || [ "$new_bri" = "custom" ]; then
                        "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "Brillo (ej: 0.85)" <<< "" > "$tmp_choice"
                        IFS= read -r custom_bri < "$tmp_choice"
                        custom_bri="${custom_bri//[[:space:]]/}"
                        custom_bri="${custom_bri//,/.}"
                        if [[ "$custom_bri" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            new_bri="$custom_bri"
                        else
                            continue
                        fi
                    fi
                    SEL_BRIGHTNESS="$new_bri"
                fi
                ;;
                
            *)
                if [[ "$choice" == *"${PROM_TIMEOUT#*. }:"* ]] || [[ "$choice" == *"$PROM_TIMEOUT"* ]]; then
                    local times_list
                    printf -v times_list "%b" "$PROM_TIMES"
                    "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "$PROM_TIMEOUT" <<< "$times_list" > "$tmp_choice"
                    IFS= read -r new_time < "$tmp_choice"
                    
                    if [ -n "$new_time" ]; then
                        new_time="${new_time%s}"
                        new_time="${new_time//[[:space:]]/}"
                        SEL_TIMEOUT="$new_time"
                        
                        "${STATE_ENGINE[@]}" --set timeout "$new_time"
                    fi
                elif [[ "$choice" == *"[ Aplicar y Probar ]"* ]] || [[ "$choice" == *"${PROM_MENU_APPLY#*. }"* ]]; then
                    if [ -z "$SEL_OUTPUT" ] || [ -z "$SEL_RES" ]; then
                        rm -f "$tmp_choice"
                        exit 1
                    fi
                    
                    hook_get_current "$SEL_OUTPUT"
                    local old_res="${RET_RES//[[:space:]]/}"
                    
                    hook_get_current_rate "$SEL_OUTPUT"
                    local old_rate="${RET_RATE//[[:space:]]/}"
                    
                    hook_get_current_scale "$SEL_OUTPUT"
                    local old_scale="${RET_SCALE//[[:space:]]/}"
                    old_scale="${old_scale:-1.0}"
                    
                    hook_get_current_rotation "$SEL_OUTPUT"
                    local old_rotation="${RET_ROTATION//[[:space:]]/}"
                    old_rotation="${old_rotation:-normal}"
                    
                    hook_get_current_brightness "$SEL_OUTPUT"
                    local old_brightness="${RET_BRIGHTNESS//[[:space:]]/}"
                    old_brightness="${old_brightness:-1.0}"
                    
                    # Obtener viejos valores dinámicos desde memoria
                    local -A old_dynamic_vals
                    if [ -n "$DISPLAY_SUPPORTED_OPTIONS" ]; then
                        for opt in "${OPT_ARRAY[@]}"; do
                            [ -z "$opt" ] && continue
                            IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
                            local opt_var="${opt_key}_${monitor_clean}"
                            local old_val="${!opt_var}"
                            old_dynamic_vals["$opt_key"]="${old_val:-${opt_vals%%,*}}"
                        done
                    fi
                    
                    local extra_args=()
                    if [ -n "$DISPLAY_SUPPORTED_OPTIONS" ]; then
                        for opt in "${OPT_ARRAY[@]}"; do
                            [ -z "$opt" ] && continue
                            IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
                            extra_args+=("${DYNAMIC_VALS[$opt_key]}")
                        done
                    fi
                    
                    echo "Aplicando previsualización: $SEL_OUTPUT -> $SEL_RES ${SEL_RATE:+@ $SEL_RATE} ${SEL_SCALE:+[x$SEL_SCALE]} ${SEL_ROTATION:+[$SEL_ROTATION]} ${SEL_BRIGHTNESS:+[brightness $SEL_BRIGHTNESS]} ${extra_args[*]:+[dynamic ${extra_args[*]}]}"
                    hook_apply "$SEL_OUTPUT" "$SEL_RES" "$SEL_RATE" "$SEL_SCALE" "$SEL_ROTATION" "$SEL_BRIGHTNESS" "${extra_args[@]}"
                    hook_post_apply
                    
                    sleep 0.5
                    
                    local tmp_confirm=$(mktemp)
                    local confirmed=""
                    local prom_msg=$(printf "$PROM_MSG" "$SEL_TIMEOUT")
                    
                    "$DISP_SEL_BIN" "${DISP_CONF_ARGS_ARR[@]}" \
                        -p "${GLYPH_CONFIRM}${PROM_CONFIRM}" \
                        -mesg "$prom_msg" <<< "${VAL_CONFIRM}"$'\n'"${VAL_REVERT}" > "$tmp_confirm" &
                    local dialog_pid=$!
                    
                    local dialog_exited=0
                    for ((i=SEL_TIMEOUT; i>0; i--)); do
                        for ((s=1; s<=10; s++)); do
                            if ! kill -0 $dialog_pid 2>/dev/null; then
                                dialog_exited=1
                                break 2
                            fi
                            sleep 0.1
                        done
                    done
                    
                    if [ "$dialog_exited" -eq 1 ]; then
                        local choice_confirm
                        read -r choice_confirm < "$tmp_confirm"
                        choice_confirm="${choice_confirm//[[:space:]]/}"
                        if [ "$choice_confirm" = "$VAL_CONFIRM" ]; then
                            confirmed="yes"
                        else
                            confirmed="no"
                        fi
                    else
                        kill $dialog_pid 2>/dev/null
                        wait $dialog_pid 2>/dev/null
                        confirmed="no"
                    fi
                    rm -f "$tmp_confirm"
                    
                    if [ "$confirmed" = "yes" ]; then
                        local cur_outputs=$("${STATE_ENGINE[@]}" --get outputs)
                        if [[ ! " $cur_outputs " == *" $SEL_OUTPUT "* ]]; then
                            local new_outputs="${cur_outputs:+$cur_outputs }$SEL_OUTPUT"
                            "${STATE_ENGINE[@]}" --no-apply --set outputs "$new_outputs"
                        fi
                        
                        "${STATE_ENGINE[@]}" --no-apply --set "resolution_${monitor_clean}" "$SEL_RES"
                        "${STATE_ENGINE[@]}" --no-apply --set "rate_${monitor_clean}" "${SEL_RATE:-}"
                        "${STATE_ENGINE[@]}" --no-apply --set "scale_${monitor_clean}" "${SEL_SCALE:-}"
                        "${STATE_ENGINE[@]}" --no-apply --set "rotation_${monitor_clean}" "${SEL_ROTATION:-}"
                        "${STATE_ENGINE[@]}" --no-apply --set "brightness_${monitor_clean}" "${SEL_BRIGHTNESS:-}"
                        
                        if [ -n "$DISPLAY_SUPPORTED_OPTIONS" ]; then
                            for opt in "${OPT_ARRAY[@]}"; do
                                [ -z "$opt" ] && continue
                                IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
                                local val="${DYNAMIC_VALS[$opt_key]}"
                                "${STATE_ENGINE[@]}" --no-apply --set "${opt_key}_${monitor_clean}" "${val:-}"
                            done
                        fi
                        
                        hook_save
                        echo "Resolución guardada permanentemente."
                    else
                        local old_extra_args=()
                        if [ -n "$DISPLAY_SUPPORTED_OPTIONS" ]; then
                            for opt in "${OPT_ARRAY[@]}"; do
                                [ -z "$opt" ] && continue
                                IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
                                old_extra_args+=("${old_dynamic_vals[$opt_key]}")
                            done
                        fi
                        
                        echo "Acción cancelada o expirada. Revirtiendo..."
                        hook_apply "$SEL_OUTPUT" "$old_res" "$old_rate" "$old_scale" "$old_rotation" "$old_brightness" "${old_extra_args[@]}"
                        hook_post_apply
                    fi
                    break
                elif [[ "$choice" == *"[ Cancelar y Salir ]"* ]] || [[ "$choice" == *"${PROM_MENU_CANCEL#*. }"* ]]; then
                    break
                else
                    if [ -n "$DISPLAY_SUPPORTED_OPTIONS" ]; then
                        local found_opt=0
                        for opt in "${OPT_ARRAY[@]}"; do
                            [ -z "$opt" ] && continue
                            IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
                            if [[ "$choice" == *"$opt_label"* ]]; then
                                local opt_list=""
                                IFS=',' read -ra ADDR <<< "$opt_vals"
                                for val in "${ADDR[@]}"; do
                                    opt_list+="${val}"$'\n'
                                done
                                opt_list="${opt_list%$'\n'}"
                                
                                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${opt_label}" <<< "$opt_list" > "$tmp_choice"
                                IFS= read -r new_opt_val < "$tmp_choice"
                                [ -n "$new_opt_val" ] && DYNAMIC_VALS["$opt_key"]="${new_opt_val//[[:space:]]/}"
                                found_opt=1
                                break
                            fi
                        done
                        [ "$found_opt" -eq 1 ] && continue
                    fi
                    break
                fi
                ;;
        esac
    done
    
    rm -f "$tmp_choice"
    exit 0
}

# 3. Parseo de Argumentos principales
case "$1" in
    --init|--apply)
        init_display
        ;;
    *)
        select_display_interactive
        ;;
esac
