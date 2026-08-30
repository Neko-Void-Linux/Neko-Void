#!/usr/bin/env bash
# packages/i3dots/bin/wp_context_menu.sh - Wrapper seguro para el menú contextual del gestor de archivos

BASE_DIR="${BASE_DIR:-$HOME/.config/i3dots}"
source "$BASE_DIR/packages/i3dots/bin/wp_shared.sh"
active_mode=$(get_state "active_mode" "dark")

exec "$BASE_DIR/dots" i3dots wp_seq.sh --mode-"$active_mode" "$1"
