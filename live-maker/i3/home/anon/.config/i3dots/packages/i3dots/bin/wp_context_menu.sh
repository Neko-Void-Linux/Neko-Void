#!/usr/bin/env bash
# packages/i3dots/bin/wp_context_menu.sh - Wrapper seguro para el menú contextual del gestor de archivos

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wp_shared.sh"
active_mode=$(get_state "active_mode" "dark")

exec "$ROOT_DIR/dots" i3dots wp_seq.sh --mode-"$active_mode" "$1"
