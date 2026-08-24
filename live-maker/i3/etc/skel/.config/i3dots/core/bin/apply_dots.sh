#!/usr/bin/env bash

# apply_dots.sh - Aplicador de componentes y hooks inteligente
# Consume: -E <hook>

# 1. Parseo
H_NAME=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -E) H_NAME="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# 2. Aplicar Componentes Secuenciales (pesados, sin competencia)
for component in $SEQUENTIAL_COMPONENTS; do
    var_name="COMPONENT_${component^^}"
    value="${!var_name}"
    [[ -z "$value" ]] && continue

    component_hook="$HOOK_DIR/components/${component}.sh"
    if [ -f "$component_hook" ]; then
        source "$component_hook" "$value"
    fi
done

# 3. Aplicar Componentes Paralelos (ligeros, tras los secuenciales)
for component in $MANAGED_COMPONENTS; do
    var_name="COMPONENT_${component^^}"
    value="${!var_name}"
    [[ -z "$value" ]] && continue

    component_hook="$HOOK_DIR/components/${component}.sh"
    if [ -f "$component_hook" ]; then
        source "$component_hook" "$value" &
    fi
done
wait # Esperar a que todos terminen antes del hook final

# 3. Aplicar Hook
if [ -n "$H_NAME" ]; then
    HOOK_SCRIPT="$HOOK_DIR/envs/${H_NAME}.sh"
    [[ ! -f "$HOOK_SCRIPT" ]] && HOOK_SCRIPT="$HOOK_DIR/${H_NAME}.sh"
else
    # Auto-deteccion si no hay -E
    HOOK_SCRIPT="$HOOK_DIR/envs/${CURRENT_ENV}.sh"
fi

if [ -f "$HOOK_SCRIPT" ]; then
    source "$HOOK_SCRIPT"
fi
