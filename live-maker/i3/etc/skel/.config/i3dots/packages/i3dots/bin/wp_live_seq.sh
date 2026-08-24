#!/usr/bin/env bash
# packages/i3dots/bin/wp_live_seq.sh - Wrapper para lanzar wp_seq.sh en modo Wallpaper Dinámico

export LIVE_ONLY=1

# Obtener la ruta real del script wp_seq.sh en el mismo directorio
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/wp_seq.sh" "$@"
