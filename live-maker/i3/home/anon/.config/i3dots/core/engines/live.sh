#!/usr/bin/env bash
# live.sh - Motor de wallpaper dinámico (xwinwrap + mpv)

MPV_SOCKET="/tmp/mpv-live-wp.sock"

# Helper: envía un comando JSON al socket IPC de mpv y devuelve la primera línea de respuesta
_mpv_ipc() {
    echo "$1" | socat - "UNIX-CONNECT:$MPV_SOCKET" 2>/dev/null | head -1
}

# Helper: setea una propiedad de mpv vía IPC
_mpv_set_prop() {
    _mpv_ipc "{\"command\":[\"set_property\",\"$1\",$2]}" >/dev/null
}

_resolve_daemon_path() {
    local script_dir repo_root
    script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"   # .../core/engines
    repo_root="$(dirname "$(dirname "$script_dir")")"               # .../i3dots

    local local_bin="$HOME/.local/bin/live_wp_daemon"
    local pkg="${PACKAGE_DIR:+$PACKAGE_DIR/bin/live_wp_daemon}"
    local std="$repo_root/packages/i3dots/bin/live_wp_daemon"

    [[ -x "$local_bin" ]] && echo "$local_bin" || { [[ -x "$pkg" ]] && echo "$pkg" || echo "$std"; }
}

engine_init() {
    pkill -15 -f 'xwinwrap' &>/dev/null || true
    pkill -15 -f 'mpv.*--x11-name=mpv-wallpaper' &>/dev/null || true
    pkill -15 -f 'live_wp_daemon' &>/dev/null || true

    # Esperar de forma activa a que todos los procesos mueran por completo antes de continuar
    local count=0
    while pgrep -f 'xwinwrap' &>/dev/null || pgrep -f 'mpv.*--x11-name=mpv-wallpaper' &>/dev/null; do
        sleep 0.05
        count=$((count+1))
        [[ $count -ge 10 ]] && break
    done

    rm -f "$MPV_SOCKET"
}

engine_set() {
    local wp_path="$1"

    # Detectar tipo de archivo
    local mime_type is_video=false
    mime_type=$(file -b --mime-type "$wp_path" 2>/dev/null)
    [[ "$mime_type" =~ ^video/ || "$wp_path" =~ \.(mp4|webm|mkv|gif)$ ]] && is_video=true

    # Fallback estático
    if [[ "$is_video" == false ]] || ! command -v xwinwrap &>/dev/null; then
        engine_init
        command -v feh &>/dev/null && feh --bg-fill "$wp_path" &
        return 0
    fi

    # Parsear nombre del archivo para configuración
    local base_name="$(basename "$wp_path")"
    local base_noext="${base_name%.*}"

    local skip_level="nonref" fps_cap=""
    [[ "$base_noext" == *_noskip* ]] && skip_level="none"
    [[ "$base_noext" =~ _fps([0-9]+) ]] && fps_cap="${BASH_REMATCH[1]}"

    # Calcular geometría actual
    local geom dim
    dim="$(xdpyinfo 2>/dev/null | grep -oP 'dimensions:\s+\K\d+x\d+')"
    if [[ -n "$dim" ]]; then
        geom="${dim}+0+0"
    else
        geom="$(xrandr 2>/dev/null | grep " connected" | grep -oP '\d+x\d+\+\d+\+\d+' | head -1)"
    fi
    geom="${geom:-1920x1080+0+0}"

    # Hot-reload vía socket IPC (solo si la resolución no cambió)
    local hot_reload=false
    local daemon_path="$(_resolve_daemon_path)"
    if [[ -S "$MPV_SOCKET" ]] && pgrep -f 'mpv.*--x11-name=mpv-wallpaper' &>/dev/null && [[ -x "$daemon_path" ]]; then
        local xwin_geom=$(pgrep -a xwinwrap | grep -oP -- '-g \K\S+' | head -1)
        if [[ "$xwin_geom" == "$geom" ]]; then
            hot_reload=true
        fi
    fi

    if [[ "$hot_reload" == true ]]; then
        _mpv_set_prop "vd-lavc-skipframe" "\"$skip_level\""
        local vf_val="[]"
        [[ -n "$fps_cap" ]] && printf -v vf_val '[{"name":"fps","params":{"fps":"%s"}}]' "$fps_cap"
        _mpv_set_prop "vf" "$vf_val"
        "$daemon_path" --loadfile "$wp_path" 2>/dev/null && return 0
    fi

    # Inicio frío: limpiar procesos y lanzar nueva sesión desvinculada
    engine_init

    # Lanzar xwinwrap+mpv en segundo plano de forma desvinculada usando setsid -f (fork)
    # Se pasan las variables de entorno de X11 de forma explícita para evitar fallas de conexión al display.
    # sleep 0.3 previene errores BadWindow en X11/picom al liberar la ventana anterior.
    setsid -f bash -c '
            export DISPLAY="$1"
            export XAUTHORITY="$2"
            geom="$3"
            socket="$4"
            path="$5"
            skip="${6:-none}"
            fps_cap="$7"
            exec xwinwrap -g "$geom" -ov -ni -b -nf -s -st -sp -- \
            mpv --wid=%WID \
                            ${fps_cap:+--vf=fps=fps=$fps_cap} \
                            --x11-name=mpv-wallpaper \
                            --msg-level=all=no \
                            --really-quiet \
                            --no-config \
                            --load-scripts=no \
                            --no-osc \
                            --no-osd-bar \
                            --osd-level=0 \
                            --no-sub \
                            --no-sub-auto \
                            --no-sub-visibility \
                            --subs-with-matching-audio=no \
                            --no-audio \
                            --ao=null \
                            --no-audio-display \
                            --no-keep-open \
                            --no-resume-playback \
                            --no-sid \
                            --no-aid \
                            --no-save-position-on-quit \
                            --no-keepaspect-window \
                            --keepaspect=yes \
                            --no-border \
                            --no-window-dragging \
                            --no-show-in-taskbar \
                            --no-taskbar-progress \
                            --no-stop-screensaver \
                            --no-terminal \
                            --no-input-default-bindings \
                            --no-input-builtin-bindings \
                            --no-media-controls \
                            --input-conf=/dev/null \
                            --input-test=no \
                            --no-input-cursor \
                            --no-input-vo-keyboard \
                            --no-input-media-keys \
                            --no-input-terminal \
                            --input-ipc-client= \
                            --no-ontop \
                            --no-fullscreen \
                            --no-fs \
                            --native-fs=no \
                            --no-auto-window-resize \
                            --x11-bypass-compositor=no \
                            --vo=gpu \
                            --gpu-context=x11egl \
                            --gpu-dumb-mode=yes \
                            --opengl-pbo=no \
                            --opengl-swapinterval=0 \
                            --opengl-early-flush=no \
                            --swapchain-depth=1 \
                            --sws-scaler=fast-bilinear \
                            --sws-fast \
                            --scale=bilinear \
                            --dscale=bilinear \
                            --cscale=bilinear \
                            --dither=no \
                            --correct-downscaling=no \
                            --sigmoid-upscaling=no \
                            --deband=no \
                            --interpolation=no \
                            --tscale=nearest \
                            --video-unscaled=no \
                            --cover-art-auto=no \
                            --cache-pause=no \
                            --cache=no \
                            --cache-on-disk=no \
                            --demuxer-cache-wait=no \
                            --demuxer-max-bytes=100KiB \
                            --demuxer-max-back-bytes=0 \
                            --demuxer-readahead-secs=0 \
                            --demuxer-seekable-cache=no \
                            --no-demuxer-thread \
                            --no-untimed \
                            --script-opts= \
                            --scripts= \
                            --glsl-shaders= \
                            --no-cookies \
                            --user-agent=" " \
                            --no-ytdl \
                            --no-audio-pitch-correction \
                            --edition=auto \
                            --title= \
                            --video-aspect-override=-2 \
                            --video-rotate=no \
                            --video-pan-x=0 \
                            --video-pan-y=0 \
                            --video-zoom=0 \
                            --video-align-x=0 \
                            --video-align-y=0 \
                            --deinterlace=no \
                            --framedrop=no \
                            --video-sync=desync \
                            --vd-lavc-fast \
                            --vd-lavc-dr=yes \
                            --vd-lavc-threads=1 \
                            --vd-lavc-skiploopfilter="$skip" \
                            --vd-lavc-skipidct="$skip" \
                            --vd-lavc-skipframe="$skip" \
                            --hwdec=auto-safe \
                            --hwdec-codecs=h264,hevc,mpeg4 \
                            --hwdec-extra-frames=0 \
                            --hwdec-image-format=no \
                            --loop-file=inf \
                            --input-ipc-server="$socket" \
                            "$path"
    ' bash "${DISPLAY:-:0}" "${XAUTHORITY:-$HOME/.Xauthority}" "$geom" "$MPV_SOCKET" "$wp_path" "$skip_level" "$fps_cap" >/tmp/xwinwrap.log 2>&1

    # Lanzar daemon si no está corriendo de forma desvinculada con nohup
    if ! pgrep -x live_wp_daemon &>/dev/null && [[ -x "$daemon_path" ]]; then
        nohup "$daemon_path" < /dev/null > /dev/null 2>&1 &
        disown $! 2>/dev/null || true
    fi
}
