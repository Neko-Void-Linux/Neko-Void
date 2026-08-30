#!/usr/bin/env bash
# core/bin/engine_state.sh - Motor de persistencia y enrutador de estado genérico optimizado

# 1. Resolver Directorios Base
export BASE_DIR="${BASE_DIR:-$HOME/.config/i3dots}"
export CORE_DIR="${CORE_DIR:-$BASE_DIR/core}"
export BIN_DIR="${BIN_DIR:-$CORE_DIR/bin}"
export STATE_DIR="${STATE_DIR:-$CORE_DIR/state}"
export PACKAGES_DIR="${PACKAGES_DIR:-$BASE_DIR/packages}"
export CURRENT_ENV="${CURRENT_ENV:-i3dots}"

NO_APPLY=0
if [ "$1" = "--no-apply" ]; then
    NO_APPLY=1
    shift
fi

COMP="$1"
shift

if [ "$1" = "--no-apply" ]; then
    NO_APPLY=1
    shift
fi

ACTION="$1"

if [ -z "$COMP" ] || [ -z "$ACTION" ]; then
    echo "Uso: $0 <componente> --set <clave> <valor>" >&2
    echo "     $0 <componente> --get <clave>" >&2
    echo "     $0 <componente> --list" >&2
    exit 1
fi

COMP_STATE_DIR="$STATE_DIR/$CURRENT_ENV/$COMP"
mkdir -p "$COMP_STATE_DIR"
STATE_FILE="$COMP_STATE_DIR/state.env"

# Cargar config.env para obtener presets y rutas de hooks
export PACKAGE_DIR="${PACKAGE_DIR:-$BASE_DIR/packages/$CURRENT_ENV}"
CONFIG_ENV="$PACKAGE_DIR/config.env"
[ -f "$CONFIG_ENV" ] && source "$CONFIG_ENV"

# Auto-detectar Hook del Componente
COMP_HOOK=""
if [ -n "$HOOK_DIR" ]; then
    if [ -f "$HOOK_DIR/components/${COMP}.sh" ]; then
        COMP_HOOK="$HOOK_DIR/components/${COMP}.sh"
    elif [ -f "$HOOK_DIR/${COMP}.sh" ]; then
        COMP_HOOK="$HOOK_DIR/${COMP}.sh"
    else
        for mc in $MANAGED_COMPONENTS; do
            if [[ "$mc" == *"$COMP"* ]] && [ -f "$HOOK_DIR/components/${mc}.sh" ]; then
                COMP_HOOK="$HOOK_DIR/components/${mc}.sh"
                break
            fi
        done
    fi
fi

# 2. Gestionar Estado en Memoria (Evita múltiples I/O en disco)
declare -A STATE_MAP

load_state_to_map() {
    if [ -f "$STATE_FILE" ]; then
        while IFS='=' read -r k v; do
            [[ -z "$k" || "$k" =~ ^# ]] && continue
            v="${v#\"}"
            v="${v%\"}"
            STATE_MAP["$k"]="$v"
        done < "$STATE_FILE"
    fi
}

save_state_from_map() {
    local tmp_file=$(mktemp)
    for k in "${!STATE_MAP[@]}"; do
        echo "${k}=\"${STATE_MAP[$k]}\"" >> "$tmp_file"
    done
    mv "$tmp_file" "$STATE_FILE"
}

load_state_to_map

# Obtener metadata de identidad del hook
PRIMARY_KEY="type"
VARIANT_KEYS=""
if [ -n "$COMP_HOOK" ]; then
    query_output=$(bash "$COMP_HOOK" --query "${STATE_MAP[type]}" 2>/dev/null)
    while IFS='=' read -r k v; do
        [[ "$k" == "primary_key" ]] && PRIMARY_KEY="$v"
        [[ "$k" == "variant_keys" ]] && VARIANT_KEYS="${v//,/ }"
    done <<< "$query_output"
fi

get_identity_suffix() {
    local suffix=""
    local pk_val="${STATE_MAP[$PRIMARY_KEY]}"
    [[ -n "$pk_val" ]] && suffix="_$pk_val"
    for vk in $VARIANT_KEYS; do
        local vk_val="${STATE_MAP[$vk]}"
        [[ -n "$vk_val" ]] && suffix="${suffix}_$vk_val"
    done
    echo "$suffix"
}

# Variable para marcar si hubo cambios y requiere guardar en disco
STATE_CHANGED=0

set_state_value() {
    local KEY="$1"
    local VAL="$2"
    
    # Detectar si la llave es una llave de identidad
    local is_id_key=0
    [[ "$KEY" == "$PRIMARY_KEY" ]] && is_id_key=1
    for vk in $VARIANT_KEYS; do
        [[ "$KEY" == "$vk" ]] && is_id_key=1
    done

    if [ "$is_id_key" -eq 1 ] && [ -n "$COMP_HOOK" ]; then
        local old_suffix=$(get_identity_suffix)
        
        # 1. Guardar opciones actuales bajo la identidad vieja
        local query=$(bash "$COMP_HOOK" --query "${STATE_MAP[type]}" 2>/dev/null)
        local opts=""
        while IFS='=' read -r k v; do
            [ "$k" == "supported_options" ] && opts="$v"
        done <<< "$query"
        
        if [ -n "$opts" ]; then
            IFS='|' read -ra OPT_ARRAY <<< "$opts"
            for opt in "${OPT_ARRAY[@]}"; do
                IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
                local active_val="${STATE_MAP[$opt_key]}"
                # No guardar si es la misma llave de identidad que estamos cambiando
                [[ "$opt_key" == "$KEY" ]] && continue
                [[ -z "$active_val" ]] && active_val="${opt_vals%%,*}"
                STATE_MAP["${opt_key}${old_suffix}"]="$active_val"
            done
        fi
        
        # 2. Aplicar el cambio de identidad
        STATE_MAP["$KEY"]="$VAL"

        # 3. Cargar/Restaurar opciones bajo la nueva identidad
        local new_query=$(bash "$COMP_HOOK" --query "${STATE_MAP[type]}" 2>/dev/null)
        local new_opts=""
        PRIMARY_KEY="type"
        VARIANT_KEYS=""
        while IFS='=' read -r k v; do
            [[ "$k" == "primary_key" ]] && PRIMARY_KEY="$v"
            [[ "$k" == "variant_keys" ]] && VARIANT_KEYS="${v//,/ }"
            [[ "$k" == "supported_options" ]] && new_opts="$v"
        done <<< "$new_query"

        local new_suffix=$(get_identity_suffix)
        
        declare -A new_keys
        if [ -n "$new_opts" ]; then
            IFS='|' read -ra OPT_ARRAY <<< "$new_opts"
            for opt in "${OPT_ARRAY[@]}"; do
                IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
                new_keys["$opt_key"]=1
                
                # OMITIR si la opción es parte de la identidad (evita sobreescritura recursiva)
                [[ "$opt_key" == "$PRIMARY_KEY" ]] && continue
                local is_vk=0
                for vk in $VARIANT_KEYS; do [[ "$opt_key" == "$vk" ]] && is_vk=1; done
                [[ "$is_vk" -eq 1 ]] && continue
                
                # Preservar preferencia de transparency_type global para evitar revertir a real
                if [ "$opt_key" == "transparency_type" ] && [ -n "${STATE_MAP[transparency_type]}" ]; then
                    continue
                fi

                local saved_key="${opt_key}${new_suffix}"
                local saved_val="${STATE_MAP[$saved_key]}"
                if [ -n "$saved_val" ]; then
                    STATE_MAP["$opt_key"]="$saved_val"
                else
                    local default_val="${opt_vals%%,*}"
                    STATE_MAP["$opt_key"]="$default_val"
                    # Opcional: inicializar persistencia si no existía
                    STATE_MAP["$saved_key"]="$default_val"
                fi
            done
        fi
        
        # 4. Limpiar opciones huérfanas en el estado activo
        if [ -n "$opts" ]; then
            IFS='|' read -ra OPT_ARRAY <<< "$opts"
            for opt in "${OPT_ARRAY[@]}"; do
                IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
                if [ -z "${new_keys[$opt_key]}" ]; then
                    unset STATE_MAP["$opt_key"]
                fi
            done
        fi
    else
        # Actualización de opción normal
        STATE_MAP["$KEY"]="$VAL"

        # Si se cambia transparency_type, sincronizarlo globalmente para todos los temas
        if [ "$KEY" == "transparency_type" ]; then
            for k in "${!STATE_MAP[@]}"; do
                if [[ "$k" == transparency_type* ]]; then
                    STATE_MAP["$k"]="$VAL"
                fi
            done
        fi
        
        # Persistencia bajo la identidad actual (Omitir si es llave de identidad)
        local is_id_key=0
        [[ "$KEY" == "$PRIMARY_KEY" ]] && is_id_key=1
        for vk in $VARIANT_KEYS; do [[ "$KEY" == "$vk" ]] && is_id_key=1; done

        if [ "$is_id_key" -eq 0 ] && [ -n "$COMP_HOOK" ]; then
            local suffix=$(get_identity_suffix)
            local query=$(bash "$COMP_HOOK" --query "${STATE_MAP[type]}" 2>/dev/null)
            local opts=""
            while IFS='=' read -r k v; do
                [ "$k" == "supported_options" ] && opts="$v"
            done <<< "$query"
            
            if [[ "$opts" == *"${KEY}:"* ]]; then
                STATE_MAP["${KEY}${suffix}"]="$VAL"
            fi
        fi
    fi
    STATE_CHANGED=1
}

case "$ACTION" in
    --set)
        KEY="$2"
        VAL="$3"
        if [ -z "$KEY" ]; then
            echo "Error: --set requiere <clave>" >&2
            exit 1
        fi
        set_state_value "$KEY" "$VAL"
        ;;
        
    --get)
        KEY="$2"
        if [ -z "$KEY" ]; then
            echo "Error: --get requiere <clave>" >&2
            exit 1
        fi
        echo "${STATE_MAP[$KEY]}"
        exit 0
        ;;
        
    --list)
        if [ -f "$STATE_FILE" ]; then
            cat "$STATE_FILE"
        fi
        exit 0
        ;;
        
    --list-presets)
        COMP_UPPER=${COMP^^}
        PRESETS_VAR="${COMP_UPPER}_PRESETS"
        PRESETS_VAL="${!PRESETS_VAR}"
        if [ -n "$PRESETS_VAL" ]; then
            IFS='|' read -ra PRESET_ARRAY <<< "$PRESETS_VAL"
            for preset in "${PRESET_ARRAY[@]}"; do
                name="${preset%%:*}"
                name="${name##[[:space:]]}"
                name="${name%%[[:space:]]}"
                echo "$name"
            done
        fi
        exit 0
        ;;
        
    --list-options)
        if [ -n "$COMP_HOOK" ]; then
            query_output=$(bash "$COMP_HOOK" --query "${STATE_MAP[type]}" 2>/dev/null)
            supported_opts=""
            while IFS='=' read -r k v; do
                if [ "$k" == "supported_options" ]; then
                    supported_opts="$v"
                    break
                fi
            done <<< "$query_output"
            echo "$supported_opts"
        fi
        exit 0
        ;;
        
    --list-themes)
        if [ -n "$COMP_HOOK" ]; then
            query_output=$(bash "$COMP_HOOK" --query "${STATE_MAP[type]}" 2>/dev/null)
            themes_dir=""
            default_theme=""
            while IFS='=' read -r k v; do
                if [ "$k" == "themes_dir" ]; then
                    themes_dir="$v"
                elif [ "$k" == "default_theme" ]; then
                    default_theme="$v"
                fi
            done <<< "$query_output"
            
            if [ -n "$themes_dir" ] && [ -d "$themes_dir" ]; then
                ls -1 "$themes_dir"
            elif [ -n "$default_theme" ]; then
                echo "$default_theme"
            fi
        fi
        exit 0
        ;;
        
    --apply-preset)
        PRESET_NAME="$2"
        if [ -z "$PRESET_NAME" ]; then
            echo "Error: --apply-preset requiere nombre" >&2
            exit 1
        fi
        COMP_UPPER=${COMP^^}
        PRESETS_VAR="${COMP_UPPER}_PRESETS"
        PRESETS_VAL="${!PRESETS_VAR}"
        if [ -z "$PRESETS_VAL" ]; then
            echo "Error: No hay presets definidos para '$COMP'" >&2
            exit 1
        fi
        
        IFS='|' read -ra PRESET_ARRAY <<< "$PRESETS_VAL"
        SELECTED_PRESET=""
        for preset in "${PRESET_ARRAY[@]}"; do
            name="${preset%%:*}"
            name="${name##[[:space:]]}"
            name="${name%%[[:space:]]}"
            if [ "$name" == "$PRESET_NAME" ]; then
                SELECTED_PRESET="$preset"
                break
            fi
        done
        
        if [ -n "$SELECTED_PRESET" ]; then
            preset_cmd="${SELECTED_PRESET#*:}"
            read -r -a preset_args <<< "$preset_cmd"
            
            idx=0
            while [ $idx -lt ${#preset_args[@]} ]; do
                arg_key="${preset_args[$idx]#--}"
                arg_val="${preset_args[$((idx+1))]}"
                set_state_value "$arg_key" "$arg_val"
                idx=$((idx+2))
            done
        else
            echo "Error: Preset '$PRESET_NAME' no encontrado." >&2
            exit 1
        fi
        ;;
        
    *)
        echo "Error: Acción '$ACTION' no soportada." >&2
        exit 1
        ;;
esac

# 3. Guardar estado si hubo cambios
if [ "$STATE_CHANGED" -eq 1 ]; then
    save_state_from_map
fi

# 4. Despachar cambios ejecutando el despachador
if [ "$NO_APPLY" -eq 0 ] && [ -f "$BIN_DIR/apply_dots.sh" ]; then
    bash "$BIN_DIR/apply_dots.sh"
fi
