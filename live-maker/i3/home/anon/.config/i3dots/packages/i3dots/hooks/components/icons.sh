#!/usr/bin/env bash
# packages/i3dots/hooks/components/icons.sh - Hook de componente para recoloreado de iconos

# 1. Asegurar ruta de ejecución
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# 2. Ejecutar script generado de forma controlada y síncrona
APPLY_SCRIPT="${HOME}/.cache/matugen/recolor_folders-apply.sh"
if [[ -f "$APPLY_SCRIPT" ]]; then
    bash "$APPLY_SCRIPT"
fi
