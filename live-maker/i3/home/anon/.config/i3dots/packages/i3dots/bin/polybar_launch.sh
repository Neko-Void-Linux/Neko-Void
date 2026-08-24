#!/usr/bin/env bash
# packages/i3dots/bin/polybar_launch.sh - Lanzador universal de Polybar
# Copiado a ~/.config/polybar/system_launch.sh durante instalación.

if [ -z "$HOME" ]; then
    export HOME=$(getent passwd "$(id -u)" | cut -d: -f6)
fi
if [ -z "$USER" ]; then
    export USER=$(id -un)
fi

# 1. Resolver Directorios de Estado de Forma Dinámica
if [ -z "$PROJECT_ROOT" ]; then
    SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
    export PROJECT_ROOT=$(cd "$(dirname "$SCRIPT_PATH")/../../.." && pwd)
fi
export STATE_DIR="${STATE_DIR:-$PROJECT_ROOT/core/state}"
export CURRENT_ENV="${CURRENT_ENV:-i3dots}"
BAR_STATE_DIR="$STATE_DIR/$CURRENT_ENV/bar"
STATE_FILE="$BAR_STATE_DIR/state.env"
export dots_cmd="${PROJECT_ROOT}/dots"
export current_env="${CURRENT_ENV:-i3dots}"

# 2. Apagado Limpio y Rápido
polybar-msg cmd hide 2>/dev/null &
pkill -u $UID -x polybar 2>/dev/null

# 3. Detección de Hardware para Módulos Dinámicos
BACKLIGHT_CARDS=(/sys/class/backlight/*)
if [ -e "${BACKLIGHT_CARDS[0]}" ]; then
    export BACKLIGHT_CARD="${BACKLIGHT_CARDS[0]##*/}"
else
    export BACKLIGHT_CARD=""
fi

BATTERIES=(/sys/class/power_supply/*BAT*)
if [ -e "${BATTERIES[0]}" ]; then
    export HAS_BATTERY="yes"
    export BAR_BATTERY="${BATTERIES[0]##*/}"
    # Detectar cargador
    ADAPTERS=(/sys/class/power_supply/*AC*)
    [ -e "${ADAPTERS[0]}" ] && export BAR_ADAPTER="${ADAPTERS[0]##*/}"
else
    export HAS_BATTERY=""
    export BAR_BATTERY="BAT0"
    export BAR_ADAPTER="AC"
fi

export HAS_AUDIO=$(pactl info >/dev/null 2>&1 && echo "yes")

# Detectar sensor de temperatura (hwmon)
export HWMON_PATH=""
for i in /sys/class/hwmon/hwmon*/name; do
    if [ -f "$i" ]; then
        read -r name < "$i"
        if [[ "$name" =~ coretemp|fam15h_power|k10temp ]]; then
            export HWMON_PATH="${i%/*}/temp1_input"
            break
        fi
    fi
done

if [ -z "$HWMON_PATH" ]; then
    HWMONS=(/sys/class/hwmon/hwmon*/temp1_input)
    if [ -e "${HWMONS[0]}" ]; then
        export HWMON_PATH="${HWMONS[0]}"
    fi
fi

# 4. Construir Listas de Módulos (Prevención de Islas/Píldoras Vacías)
export POLY_LEFT="space left launcher right space left cpu-usage space-alt cpu-memory right space left i3-workspaces right"
[ -n "$BACKLIGHT_CARD" ] && POLY_LEFT="$POLY_LEFT space left backlight right"

export POLY_CENTER="left date right"

export POLY_RIGHT="left cpu-temperature right"
[ -n "$HAS_AUDIO" ] && POLY_RIGHT="$POLY_RIGHT space space left volume right"
[ -n "$HAS_BATTERY" ] && POLY_RIGHT="$POLY_RIGHT space left battery right"
export POLY_RIGHT="$POLY_RIGHT space left tray right space"

# Para tema compact
export POLY_COMPACT_LEFT="rofi space filesystem filesystem-value space cpu cpu-value space memory memory-value"
[ -n "$HWMON_PATH" ] && export POLY_COMPACT_LEFT="$POLY_COMPACT_LEFT space temp temp-value space xwindow"

export POLY_COMPACT_CENTER="i3"

export POLY_COMPACT_RIGHT="tray"
[ -n "$BACKLIGHT_CARD" ] && export POLY_COMPACT_RIGHT="$POLY_COMPACT_RIGHT space backlight backlight-value"

[ -n "$HAS_AUDIO" ] && {
    export POLY_COMPACT_RIGHT="$POLY_COMPACT_RIGHT space pulseaudio pulseaudio-value"
}

[ -n "$HAS_BATTERY" ] && {
    export POLY_COMPACT_RIGHT="$POLY_COMPACT_RIGHT space battery battery-value"
}

export POLY_COMPACT_RIGHT="$POLY_COMPACT_RIGHT space time time-value"

# 5. Cargar Estado de Estilo y Exportar a Entorno
if [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
    # Exportar variables de estado plano al entorno para uso directo de Polybar
    export BAR_HEIGHT="${height:-15pt}"
    export BAR_POSITION="${position:-bottom}"
    export BAR_STYLE="${style:-square}"
    export BAR_TRANSPARENCY="${transparency:-true}"
    export BAR_MODE="${mode:-solid}"
    export BAR_ROFI_STYLE="${rofi_style:-solid}"
    export BAR_SOLID_LINE="${solid_line:-false}"
    export BAR_ICON_PADDING="${icon_padding:-1}"
    export BAR_AUTOHIDE="${autohide:-false}"
    if [ "${modules_visibility:-hidden}" == "visible" ]; then
        export COMP_MODULES_HIDDEN="false"
    else
        export COMP_MODULES_HIDDEN="true"
    fi
fi

# 5.5 Conditional Module Injection (Atajos)
if [ "$type" == "polybar_underline" ] && [ "${BAR_MODE}" == "solid" ]; then
    export POLY_LEFT="${POLY_LEFT/launcher right/launcher right space left help-keys right}"
fi

# 6. Generar Script Estático POSIX para Dash
STATIC_SCRIPT="$HOME/.config/polybar/run_static.sh"
CONFIG_FILE="$HOME/.config/polybar/config.ini"

BARS=""
if [ -f "$CONFIG_FILE" ]; then
    BARS=$(grep -oP '^\[bar/\K[^\]]+' "$CONFIG_FILE")
fi
[ -z "$BARS" ] && BARS="bottom"

cat << EOF > "$STATIC_SCRIPT"
#!/bin/dash
export BAR_HEIGHT="$BAR_HEIGHT"
export BAR_POSITION="$BAR_POSITION"
export BAR_STYLE="$BAR_STYLE"
export BAR_TRANSPARENCY="$BAR_TRANSPARENCY"
export BAR_MODE="$BAR_MODE"
export BAR_ROFI_STYLE="$BAR_ROFI_STYLE"
export BAR_SOLID_LINE="$BAR_SOLID_LINE"
export BAR_ICON_PADDING="$BAR_ICON_PADDING"
export BAR_AUTOHIDE="$BAR_AUTOHIDE"
export COMP_MODULES_HIDDEN="$COMP_MODULES_HIDDEN"
export dots_cmd="${PROJECT_ROOT}/dots"
export current_env="${CURRENT_ENV:-i3dots}"

# Variables de Hardware
export BACKLIGHT_CARD="$BACKLIGHT_CARD"
export HAS_BATTERY="$HAS_BATTERY"
export BAR_BATTERY="$BAR_BATTERY"
export BAR_ADAPTER="$BAR_ADAPTER"
export HAS_AUDIO="$HAS_AUDIO"
export HWMON_PATH="$HWMON_PATH"

# Variables de Modulos
export POLY_LEFT="$POLY_LEFT"
export POLY_CENTER="$POLY_CENTER"
export POLY_RIGHT="$POLY_RIGHT"
export POLY_COMPACT_LEFT="$POLY_COMPACT_LEFT"
export POLY_COMPACT_CENTER="$POLY_COMPACT_CENTER"
export POLY_COMPACT_RIGHT="$POLY_COMPACT_RIGHT"
EOF

for bar in $BARS; do
    echo "/usr/bin/polybar -q \"$bar\" -c \"$CONFIG_FILE\" &" >> "$STATIC_SCRIPT"
done

chmod +x "$STATIC_SCRIPT"

# 7. Matar demonio autohide previo por si acaso
pkill -f polybar_autohide 2>/dev/null

if [ "$BAR_AUTOHIDE" == "true" ]; then
    # Lanzar únicamente el demonio de autohide en segundo plano con su delay y método
    $HOME/.local/bin/polybar_autohide --delay "${autohide_delay:-100}" --position "${BAR_POSITION:-bottom}" --method "${autohide_method:-kill}" &
else
    # Lanzar barras usando el script estático de Dash recién creado
    $STATIC_SCRIPT &
fi
