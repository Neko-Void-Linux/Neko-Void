#!/bin/dash
# toggle_autohide.sh - Alternado ultra-rápido de autohide para Polybar sin recarga pesada

# 1. Cooldown nativo de 1 segundo (Sin subprocesos)
read -r uptime_now _ < /proc/uptime
uptime_sec="${uptime_now%.*}"

read -r last_sec < /tmp/toggle_autohide.last 2>/dev/null
last_sec="${last_sec:-0}"

if [ "$uptime_sec" = "$last_sec" ]; then
    exit 0
fi
echo "$uptime_sec" > /tmp/toggle_autohide.last

# Resolver variables de entorno básicas de forma segura para dash/i3
MY_UID=$(id -u)
if [ -z "$HOME" ]; then
    HOME=$(getent passwd "$MY_UID" | cut -d: -f6)
fi
export HOME
if [ -z "$USER" ]; then
    USER=$(id -un)
fi
export USER

# Directorio base de i3dots dinámico (resuelve symlinks, tildes y comandos de PATH)
SCRIPT_NAME="$0"
case "$SCRIPT_NAME" in
    ~*) SCRIPT_NAME="$HOME${SCRIPT_NAME#\~}" ;;
esac
case "$SCRIPT_NAME" in
    */*) ;;
    *) SCRIPT_NAME=$(command -v "$SCRIPT_NAME") ;;
esac
REAL_PATH=$(readlink -f "$SCRIPT_NAME")
SCRIPT_DIR=$(dirname "$REAL_PATH")
BASE_DIR=$(cd "$SCRIPT_DIR/../../.." && pwd)
STATE_FILE="$BASE_DIR/core/state/i3dots/bar/state.env"

[ ! -f "$STATE_FILE" ] && exit 1

# Cargar variables de estado usando dot source (POSIX)
. "$STATE_FILE" 2>/dev/null
CURRENT_VAL="${autohide:-false}"
CUR_TYPE="${type}"
METHOD="${autohide_method:-kill}"

# Decidir nuevo valor
if [ "$CURRENT_VAL" = "true" ]; then
    NEW_VAL="false"
else
    NEW_VAL="true"
fi

# Guardar nuevo estado en state.env de forma robusta
if grep -q '^autohide=' "$STATE_FILE"; then
    sed -i 's/^autohide=".*"/autohide="'"$NEW_VAL"'"/' "$STATE_FILE"
else
    echo "autohide=\"$NEW_VAL\"" >> "$STATE_FILE"
fi

# Actualizar el valor del tema activo (ej: autohide_polybar_compact)
if [ -n "$CUR_TYPE" ]; then
    if grep -q "^autohide_${CUR_TYPE}=" "$STATE_FILE"; then
        sed -i 's/^autohide_'"$CUR_TYPE"'=".*"/autohide_'"$CUR_TYPE"'="'"$NEW_VAL"'"/' "$STATE_FILE"
    else
        echo "autohide_${CUR_TYPE}=\"$NEW_VAL\"" >> "$STATE_FILE"
    fi
fi

# Aplicar cambios en caliente en base al nuevo valor
if [ "$NEW_VAL" = "true" ]; then
    # 1. Activar Autohide
    export BAR_POSITION="${position:-bottom}"
    DELAY_MS="${autohide_delay:-100}"
    
    # Ocultar visualmente y apagar Polybar de inmediato solo si el método es "kill"
    if [ "$METHOD" = "kill" ]; then
        polybar-msg cmd hide >/dev/null 2>&1
        pkill -u "$MY_UID" -x polybar 2>/dev/null
    fi
    
    # Matar demonio previo y arrancar uno nuevo
    pkill -f polybar_autohide 2>/dev/null
    nohup $HOME/.local/bin/polybar_autohide --delay "$DELAY_MS" --position "$BAR_POSITION" --method "$METHOD" >/dev/null 2>&1 &
else
    # 2. Desactivar Autohide (Modo clásico permanente)
    pkill -f polybar_autohide 2>/dev/null
    
    if [ "$METHOD" = "hide" ]; then
        # Sincronizar estado interno de Polybar antes de mostrar (hide -> show)
        polybar-msg cmd hide >/dev/null 2>&1
        polybar-msg cmd show >/dev/null 2>&1
    else
        # En modo kill, la barra no está en ejecución. Limpiar y arrancar una permanente.
        pkill -u "$MY_UID" -x polybar 2>/dev/null
        sleep 0.1
        if [ -x "$HOME/.config/polybar/run_static.sh" ]; then
            nohup $HOME/.config/polybar/run_static.sh >/dev/null 2>&1 &
        fi
    fi
fi
