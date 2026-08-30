#!/usr/bin/env bash
# hooks/components/display.sh - Backend de pantalla para X11 usando xrandr

# Variables de caché globales
XRANDR_CACHE=""
XRANDR_VERBOSE_CACHE=""

# Variables de retorno globales (para evitar subshells)
RET_OUT=""
RET_RES=""
RET_RATE=""
RET_SCALE=""
RET_ROTATION=""
RET_BRIGHTNESS=""
RET_LIST=""

hook_load_cache() {
    XRANDR_CACHE=$(xrandr --current 2>/dev/null)
    XRANDR_VERBOSE_CACHE=$(xrandr --current --verbose 2>/dev/null)
}

ensure_cache() {
    if [ -z "$XRANDR_CACHE" ]; then
        XRANDR_CACHE=$(xrandr --current 2>/dev/null)
    fi
}

ensure_verbose_cache() {
    if [ -z "$XRANDR_VERBOSE_CACHE" ]; then
        XRANDR_VERBOSE_CACHE=$(xrandr --current --verbose 2>/dev/null)
    fi
}

hook_query_outputs() {
    ensure_cache
    RET_LIST=""
    local line
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            RET_LIST+="${BASH_REMATCH[1]}"$'\n'
        fi
    done <<< "$XRANDR_CACHE"
    RET_LIST="${RET_LIST%$'\n'}"
}

hook_query_modes() {
    local output="$1"
    ensure_cache
    RET_LIST=""
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
                read -r res_name rates_str <<< "$line"
                if [ -n "$res_name" ]; then
                    RET_LIST+="$res_name"$'\n'
                fi
            fi
        fi
    done <<< "$XRANDR_CACHE"
    RET_LIST="${RET_LIST%$'\n'}"
}

hook_query_rates() {
    local output="$1"
    local resolution="$2"
    ensure_cache
    RET_LIST=""
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
                read -r res_name rates_str <<< "$line"
                if [ "$res_name" = "$resolution" ]; then
                    local rate
                    for rate in $rates_str; do
                        rate="${rate//[*+]/}"
                        RET_LIST+="$rate"$'\n'
                    done
                    break
                fi
            fi
        fi
    done <<< "$XRANDR_CACHE"
    RET_LIST="${RET_LIST%$'\n'}"
}

hook_get_current() {
    local output="$1"
    ensure_cache
    RET_RES=""
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
                read -r res_name rates_str <<< "$line"
                if [[ "$rates_str" == *"*"* ]]; then
                    RET_RES="$res_name"
                    break
                fi
            fi
        fi
    done <<< "$XRANDR_CACHE"
}

hook_get_current_rate() {
    local output="$1"
    ensure_cache
    RET_RATE=""
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
                read -r res_name rates_str <<< "$line"
                local rate
                for rate in $rates_str; do
                    if [[ "$rate" == *"*"* ]]; then
                        RET_RATE="${rate//[*+]/}"
                        break 2
                    fi
                done
            fi
        fi
    done <<< "$XRANDR_CACHE"
}

hook_get_current_all() {
    local output="$1"
    ensure_cache
    RET_RES=""
    RET_RATE=""
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
                read -r res_name rates_str <<< "$line"
                local rate
                for rate in $rates_str; do
                    if [[ "$rate" == *"*"* ]]; then
                        RET_RES="$res_name"
                        RET_RATE="${rate//[*+]/}"
                        break 2
                    fi
                done
            fi
        fi
    done <<< "$XRANDR_CACHE"
}

hook_query_default() {
    ensure_cache
    RET_OUT=""
    RET_RES=""
    RET_RATE=""
    local line current_out=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            current_out="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            current_out=""
        fi
        
        if [ -n "$current_out" ]; then
            if [[ "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
                read -r res_name rates_str <<< "$line"
                local rate
                for rate in $rates_str; do
                    if [[ "$rate" == *"*"* ]]; then
                        RET_OUT="$current_out"
                        RET_RES="$res_name"
                        RET_RATE="${rate//[*+]/}"
                        break 2
                    fi
                done
            fi
        fi
    done <<< "$XRANDR_CACHE"
}

hook_get_current_scale() {
    local output="$1"
    ensure_verbose_cache
    RET_SCALE="1.0"
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ [[:space:]]*Transform:[[:space:]]+([^[:space:]]+) ]]; then
                local scale="${BASH_REMATCH[1]}"
                if [ "$scale" = "1.000000" ] || [ -z "$scale" ]; then
                    RET_SCALE="1.0"
                else
                    RET_SCALE=$(awk -v s="$scale" 'BEGIN { printf "%.2f", 1/s }' 2>/dev/null)
                    RET_SCALE="${RET_SCALE%0}"
                    RET_SCALE="${RET_SCALE%.}"
                fi
                break
            fi
        fi
    done <<< "$XRANDR_VERBOSE_CACHE"
}

hook_get_current_rotation() {
    local output="$1"
    ensure_cache
    RET_ROTATION="normal"
    local line
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                if [[ "$line" =~ [[:space:]]+(normal|left|right|inverted)[[:space:]]+\( ]]; then
                    RET_ROTATION="${BASH_REMATCH[1]}"
                fi
                break
            fi
        fi
    done <<< "$XRANDR_CACHE"
}

hook_get_current_brightness() {
    local output="$1"
    ensure_verbose_cache
    RET_BRIGHTNESS="1.0"
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ [[:space:]]*Brightness:[[:space:]]+([^[:space:]]+) ]]; then
                RET_BRIGHTNESS="${BASH_REMATCH[1]}"
                break
            fi
        fi
    done <<< "$XRANDR_VERBOSE_CACHE"
}

hook_get_current_filter() {
    local output="$1"
    RET_FILTER=""
    if [ -f "$DISPLAY_STATE_DIR/${output}.filter" ]; then
        RET_FILTER=$(cat "$DISPLAY_STATE_DIR/${output}.filter" | tr -d '[:space:]')
    fi
    RET_FILTER="${RET_FILTER:-ninguno}"
}

hook_get_current_scale_method() {
    local output="$1"
    RET_SCALE_METHOD=""
    if [ -f "$DISPLAY_STATE_DIR/${output}.scale_method" ]; then
        RET_SCALE_METHOD=$(cat "$DISPLAY_STATE_DIR/${output}.scale_method" | tr -d '[:space:]')
    fi
    RET_SCALE_METHOD="${RET_SCALE_METHOD:-${DISP_SCALE_METHOD:-scale}}"
}

hook_apply() {
    local output="$1"
    local resolution="$2"
    local rate="$3"
    local scale="$4"
    local rotation="$5"
    local brightness="$6"
    local filter="$7"
    local scale_method="$8"
    
    local args=()
    if [ -n "$resolution" ]; then
        args+=(--mode "$resolution")
    fi
    if [[ -z "$rate" || "$rate" == [Aa]uto || ! "$rate" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [ -n "$resolution" ]; then
        hook_query_rates "$output" "$resolution"
        rate=$(head -n 1 <<< "$RET_LIST" | tr -d '[:space:]')
    fi
    if [[ "$rate" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        args+=(--rate "$rate")
    fi
    local scale_filter="${filter:-${DISP_SCALE_FILTER:-}}"
    if [ "$scale_filter" = "ninguno" ] || [ "$scale_filter" = "none" ]; then
        scale_filter=""
    fi
    
    # Determinar método de escala
    local scale_method="${scale_method:-${DISP_SCALE_METHOD:-scale}}"
    
    if [ -n "$scale" ] && [ "$scale" != "1" ] && [ "$scale" != "1.0" ]; then
        xrandr_scale=$(awk -v z="$scale" 'BEGIN { printf "%.3f", 1/z }')
        if [ -n "$scale_filter" ]; then
            args+=(--filter "$scale_filter")
        fi
        if [ "$scale_method" = "transform" ]; then
            args+=(--transform "${xrandr_scale},0,0,0,${xrandr_scale},0,0,0,1")
        else
            args+=(--scale "${xrandr_scale}x${xrandr_scale}")
        fi
    else
        args+=(--transform none)
    fi
    if [ -n "$rotation" ]; then
        args+=(--rotate "$rotation")
    fi
    if [ -n "$brightness" ]; then
        args+=(--brightness "$brightness")
    fi
    
    xrandr --output "$output" "${args[@]}"
}

hook_save() {
    export CURRENT_ENV="${CURRENT_ENV:-i3dots}"
    if [ -z "$DISPLAY_STATE_DIR" ]; then
        local BASE_DIR="${BASE_DIR:-$HOME/.config/i3dots}"
        local STATE_DIR="${STATE_DIR:-$BASE_DIR/core/state}"
        DISPLAY_STATE_DIR="$STATE_DIR/$CURRENT_ENV/display"
    fi
    local STATE_FILE="$DISPLAY_STATE_DIR/state.env"
    
    local I3_OUTPUT_CONF="$HOME/.config/i3/conf.d/output.conf"
    mkdir -p "$(dirname "$I3_OUTPUT_CONF")"
    
    echo "# Configuración de Pantalla Generada Dinámicamente" > "$I3_OUTPUT_CONF"
    echo "# NO EDITAR ESTE ARCHIVO DIRECTAMENTE" >> "$I3_OUTPUT_CONF"
    
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        
        for output in $outputs; do
            local monitor_clean="${output//-/_}"
            monitor_clean="${monitor_clean//./_}"
            
            local res_var="resolution_${monitor_clean}"
            local resolution="${!res_var}"
            [ -z "$resolution" ] && continue
            
            local rate_var="rate_${monitor_clean}"
            local rate="${!rate_var}"
            
            local scale_var="scale_${monitor_clean}"
            local scale="${!scale_var}"
            
            local rot_var="rotation_${monitor_clean}"
            local rotation="${!rot_var}"
            
            local bri_var="brightness_${monitor_clean}"
            local brightness="${!bri_var}"
            
            local filter_var="filter_${monitor_clean}"
            local filter="${!filter_var}"
            
            local scale_method_var="scale_method_${monitor_clean}"
            local scale_method="${!scale_method_var}"
            scale_method="${scale_method:-${DISP_SCALE_METHOD:-scale}}"
            
            local cmd="xrandr --output $output"
            cmd="$cmd --mode $resolution"
            
            if [[ -z "$rate" || "$rate" == [Aa]uto || ! "$rate" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [ -n "$resolution" ]; then
                hook_query_rates "$output" "$resolution"
                rate=$(head -n 1 <<< "$RET_LIST" | tr -d '[:space:]')
            fi
            if [[ "$rate" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                cmd="$cmd --rate $rate"
            fi
            
            local scale_filter="${filter:-${DISP_SCALE_FILTER:-}}"
            if [ "$scale_filter" = "ninguno" ] || [ "$scale_filter" = "none" ]; then
                scale_filter=""
            fi
            
            if [ -n "$scale" ] && [ "$scale" != "1" ] && [ "$scale" != "1.0" ]; then
                local xrandr_scale=$(awk -v z="$scale" 'BEGIN { printf "%.3f", 1/z }')
                if [ -n "$scale_filter" ]; then
                    cmd="$cmd --filter $scale_filter"
                fi
                if [ "$scale_method" = "transform" ]; then
                    cmd="$cmd --transform ${xrandr_scale},0,0,0,${xrandr_scale},0,0,0,1"
                else
                    cmd="$cmd --scale ${xrandr_scale}x${xrandr_scale}"
                fi
            else
                cmd="$cmd --transform none"
            fi
            
            [ -n "$rotation" ] && cmd="$cmd --rotate $rotation"
            [ -n "$brightness" ] && cmd="$cmd --brightness $brightness"
            
            echo "exec_always --no-startup-id $cmd" >> "$I3_OUTPUT_CONF"
        done
    fi
}

hook_query() {
    echo "supported_options=filter:Nitidez (Filtro):ninguno,nearest,bilinear|scale_method:Método Escala:scale,transform"
}

hook_post_apply() {
    # Ajustar wallpaper usando el motor activo (si no se pide omitir)
    if [ "$NO_WALLPAPER" != "true" ] && [ -f "$HOME/.config/i3/wall" ]; then
        ( wp_select.sh -C "$(cat "$HOME/.config/i3/wall")" & )
    fi
    
    # Relanzar Polybar de forma directa
    if [ -x "$HOME/.config/polybar/launch.sh" ]; then
        bash "$HOME/.config/polybar/launch.sh" >/tmp/polybar.log 2>&1 &
    fi
}

hook_init() {
    local BASE_DIR="${BASE_DIR:-$HOME/.config/i3dots}"
    bash "$BASE_DIR/core/bin/engine_display.sh" --init
}

# Ejecución directa si no se está importando (sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    action="$1"
    shift
    case "$action" in
        --query)
            hook_query
            ;;
        --query-outputs)
            hook_query_outputs "$@"
            echo "$RET_LIST"
            ;;
        --query-modes)
            hook_query_modes "$@"
            echo "$RET_LIST"
            ;;
        --query-rates)
            hook_query_rates "$@"
            echo "$RET_LIST"
            ;;
        --get-current)
            hook_get_current "$@"
            echo "$RET_RES"
            ;;
        --get-current-rate)
            hook_get_current_rate "$@"
            echo "$RET_RATE"
            ;;
        --get-current-all)
            hook_get_current_all "$@"
            echo "$RET_RES $RET_RATE"
            ;;
        --query-default)
            hook_query_default "$@"
            echo "$RET_OUT $RET_RES $RET_RATE"
            ;;
        --get-current-scale)
            hook_get_current_scale "$@"
            echo "$RET_SCALE"
            ;;
        --get-current-rotation)
            hook_get_current_rotation "$@"
            echo "$RET_ROTATION"
            ;;
        --get-current-brightness)
            hook_get_current_brightness "$@"
            echo "$RET_BRIGHTNESS"
            ;;
        --get-current-filter)
            hook_get_current_filter "$@"
            echo "$RET_FILTER"
            ;;
        --get-current-scale_method)
            hook_get_current_scale_method "$@"
            echo "$RET_SCALE_METHOD"
            ;;
        --apply) hook_apply "$@" ;;
        --save) hook_save "$@" ;;
        --post-apply) hook_post_apply "$@" ;;
        *) hook_init "$@" ;;
    esac
fi
