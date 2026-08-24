#!/usr/bin/env bash
# powermenu.sh - Módulo core "inteligentemente tonto"
# Gestiona las opciones de apagado/reinicio de forma agnóstica.

# 1. Configuración del paquete (config.env)
BIN="${POWERMENU_BIN:-rofi}"
ARGS=(${POWERMENU_ARGS})

# Etiquetas (Labels) - El paquete decide si usa iconos o texto
L_SHUTDOWN="${POWERMENU_LABEL_SHUTDOWN:-Shutdown}"
L_REBOOT="${POWERMENU_LABEL_REBOOT:-Reboot}"
L_SUSPEND="${POWERMENU_LABEL_SUSPEND:-Suspend}"
L_LOGOUT="${POWERMENU_LABEL_LOGOUT:-Logout}"

# 2. Control de Flujo Rofi
if [[ -z "$ROFI_LIST_MODE" && $# -eq 0 ]]; then
    # Fase 1: Lanzar Rofi (reemplaza proceso actual)
    export ROFI_LIST_MODE=1
    UPTIME=$(uptime -p | sed -E 's/up //; s/ days?/d/g; s/ hours?/h/g; s/ minutes?/m/g; s/,//g; s/  */ /g')
    exec "$BIN" -show " " -modi " :$0" "${ARGS[@]}" -theme-str 'inputbar { children: [ "textbox-prompt-colon" ]; } textbox-prompt-colon { str: "'"$UPTIME"'"; horizontal-align: 0.5; expand: true; padding: 12px 15px; background-color: transparent; text-color: inherit; }' -p ""

elif [[ "$ROFI_LIST_MODE" -eq 1 && $# -eq 0 ]]; then
    # Fase 2: Rofi solicita lista (stdout)
    UPTIME=$(uptime -p | sed -E 's/up //; s/ days?/d/g; s/ hours?/h/g; s/ minutes?/m/g; s/,//g; s/  */ /g')
    echo -e "$L_SUSPEND\n$L_LOGOUT\n$L_REBOOT\n$L_SHUTDOWN"
    exit 0
else
    # Fase 3: Rofi devuelve selección ($1)
    CHOSEN="$1"
    [[ -z "$CHOSEN" ]] && exit 1

    case "$CHOSEN" in
        "$L_SHUTDOWN") [ -n "$POWERMENU_CMD_SHUTDOWN" ] && eval "$POWERMENU_CMD_SHUTDOWN" ;;
        "$L_REBOOT")   [ -n "$POWERMENU_CMD_REBOOT" ]   && eval "$POWERMENU_CMD_REBOOT" ;;
        "$L_SUSPEND")  [ -n "$POWERMENU_CMD_SUSPEND" ]  && eval "$POWERMENU_CMD_SUSPEND" ;;
        "$L_LOGOUT")   [ -n "$POWERMENU_CMD_LOGOUT" ]   && eval "$POWERMENU_CMD_LOGOUT" ;;
    esac
    exit 0
fi
