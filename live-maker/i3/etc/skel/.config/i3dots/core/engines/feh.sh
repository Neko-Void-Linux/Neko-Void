#!/usr/bin/env bash
# feh.sh - Motor de wallpaper estático (feh)

MPV_SOCKET="/tmp/mpv-live-wp.sock"

engine_init() {
    # Limpiar procesos de video residuales al cambiar a estático
    pkill -9 -f 'xwinwrap' &>/dev/null || true
    pkill -9 -f 'mpv.*--x11-name=mpv-wallpaper' &>/dev/null || true
    pkill -9 -f 'live_wp_daemon' &>/dev/null || true
    rm -f "$MPV_SOCKET"
}

engine_set() {
    local wp_path="$1"
    engine_init
    local wp_state_dir="${BASE_DIR:-$HOME/.config/i3dots}/core/state/${CURRENT_ENV:-i3dots}/wallpaper"
    mkdir -p "$wp_state_dir"
    ln -sf "$wp_path" "$wp_state_dir/color_source"
    feh --bg-fill "$wp_path"
}
