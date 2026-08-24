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
    feh --bg-fill "$wp_path"
}
