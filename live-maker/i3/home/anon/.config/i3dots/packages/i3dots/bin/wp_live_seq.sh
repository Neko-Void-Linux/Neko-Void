#!/usr/bin/env bash
# packages/i3dots/bin/wp_live_seq.sh - Wrapper para lanzar wp_seq.sh en modo Wallpaper Dinámico

export LIVE_ONLY=1

# Obtener la ruta del script wp_seq.sh
BASE_DIR="${BASE_DIR:-$HOME/.config/i3dots}"
exec "$BASE_DIR/packages/i3dots/bin/wp_seq.sh" "$@"
