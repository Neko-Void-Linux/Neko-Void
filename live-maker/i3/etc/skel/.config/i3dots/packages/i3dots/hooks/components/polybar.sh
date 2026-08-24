#!/usr/bin/env bash
# hooks/components/polybar.sh - Hook de enlace y generación de estado para Polybar

# 1. Asegurar Variables de Entorno y Directorios de Forma Dinámica
if [ -z "$PROJECT_ROOT" ]; then
    SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
    export PROJECT_ROOT=$(cd "$(dirname "$SCRIPT_PATH")/../../../.." && pwd)
fi
export BASE_DIR="${BASE_DIR:-$PROJECT_ROOT}"
export STATE_DIR="${STATE_DIR:-$PROJECT_ROOT/core/state}"
export CURRENT_ENV="${CURRENT_ENV:-$(basename "$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd)")}"
BAR_STATE_DIR="$STATE_DIR/$CURRENT_ENV/bar"
mkdir -p "$BAR_STATE_DIR"
STATE_FILE="$BAR_STATE_DIR/state.env"

# 0. Protocolo de Consulta para Frontends
if [ "$1" == "--query" ]; then
    CUR_TYPE="${2:-$(source "$STATE_FILE" 2>/dev/null && echo "$type" || echo "polybar_antigua")}"
    CUR_TYPE=$(echo "$CUR_TYPE" | tr -d '[:space:]')
    THEME_SRC="$PACKAGE_DIR/config/polybar/$CUR_TYPE"
    
    SUPPORTED=""
    # Cargar opciones dinámicas del tema
    if [ -f "$THEME_SRC/options.conf" ]; then
        while read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^# || -z "$line" ]] && continue
            SUPPORTED="${SUPPORTED:+$SUPPORTED|}$line"
        done < "$THEME_SRC/options.conf"
    fi

    echo "themes_dir=$PACKAGE_DIR/config/polybar"
    echo "default_theme=polybar_antigua"
    echo "primary_key=type"
    echo "variant_keys=mode"
    echo "supported_options=$SUPPORTED"
    exit 0
fi

# 1. Cargar Estado Plano
STYLE="square"
POS="bottom"
TRANS="true"
HEIGHT="15pt"
TYPE="polybar_antigua"
MODE="solid"
ROFI_STYLE="solid"
SOLID_LINE="false"
ICON_PADDING="1"
OVERRIDE_REDIRECT="dock"
TRANS_TYPE="real"
MARGIN_TYPE="floating"
MODULES_VISIBILITY="hidden"

if [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
    STYLE="${style:-$STYLE}"
    POS="${position:-$POS}"
    TRANS="${transparency:-$TRANS}"
    HEIGHT="${height:-$HEIGHT}"
    TYPE="${type:-$TYPE}"
    MODE="${mode:-$MODE}"
    ROFI_STYLE="${rofi_style:-$ROFI_STYLE}"
    SOLID_LINE="${solid_line:-$SOLID_LINE}"
    ICON_PADDING="${icon_padding:-$ICON_PADDING}"
    OVERRIDE_REDIRECT="${override_redirect:-$OVERRIDE_REDIRECT}"
    TRANS_TYPE="${transparency_type:-$TRANS_TYPE}"
    MARGIN_TYPE="${margin_type:-$MARGIN_TYPE}"
    MODULES_VISIBILITY="${modules_visibility:-$MODULES_VISIBILITY}"
fi

OR_VAL=$([ "$OVERRIDE_REDIRECT" == "overlay" ] && echo "true" || echo "false")

TYPE="${TYPE//[[:space:]]/}"
THEME_SRC="$PACKAGE_DIR/config/polybar/$TYPE"
CONF_DIR="$HOME/.config/polybar"
mkdir -p "$CONF_DIR"

# 2. Limpieza y Proyección Directa de Enlaces
# Enlazar todos los archivos de la carpeta del tema a la raíz de ~/.config/polybar/
if [ -d "$THEME_SRC" ]; then
    # Limpiar enlaces del tema anterior en la raíz (evitando borrar system_launch.sh y carpetas)
    find "$CONF_DIR" -maxdepth 1 -type l ! -name "system_launch.sh" -delete
    
    # Proyectar archivos del tema activo
    for file in "$THEME_SRC"/*; do
        filename="${file##*/}"
        # Evitar sobreescribir launch.sh y colors.ini
        if [ "$filename" != "launch.sh" ] && [ "$filename" != "colors.ini" ]; then
            ln -sf "$file" "$CONF_DIR/$filename"
        elif [ "$filename" == "launch.sh" ] && [ -x "$file" ]; then
            ln -sf "$file" "$CONF_DIR/$filename"
        fi
    done

    # Asegurar que colors.ini existe (vía tema o copia del instalador)
    [ ! -f "$CONF_DIR/colors.ini" ] && [ -f "$THEME_SRC/colors.ini" ] && ln -sf "$THEME_SRC/colors.ini" "$CONF_DIR/colors.ini"
fi

# 3. Lógica Especial de Variantes (Underline / Solid)
if [ -f "$THEME_SRC/modules_underline.ini" ] && [ -f "$THEME_SRC/modules_solid.ini" ]; then
    MOD_FILE="modules_${MODE}.ini"
    [ ! -f "$THEME_SRC/$MOD_FILE" ] && MOD_FILE="modules_underline.ini"
    ln -sf "$THEME_SRC/$MOD_FILE" "$CONF_DIR/modules.ini"
fi

# 4. Cálculo de Variables de Estilo Genéricas (Magia Dinámica)
RADIUS=$([ "$STYLE" == "round" ] && echo 10 || echo 0)
IS_BOTTOM=$([ "$POS" == "top" ] && echo "false" || echo "true")
H_NUM="${HEIGHT//[!0-9]/}"; [[ -z "$H_NUM" ]] && H_NUM=15

# Ajustes específicos para modo Underline
LINE_SIZE=0
if [ "$MODE" == "underline" ] || [ "$SOLID_LINE" == "true" ]; then
    LINE_SIZE=$(( H_NUM / 6 )); [[ $LINE_SIZE -lt 2 ]] && LINE_SIZE=2
fi

if [ "$TYPE" == "polybar_compact" ]; then
    if [ "$MARGIN_TYPE" == "pinned" ]; then
        COMP_BORDER_TOP=0
        COMP_BORDER_BOTTOM=0
        if [ "$TRANS" == "false" ]; then
            COMP_HEIGHT="$(( H_NUM + 3 ))pt"
            COMP_LINE_SIZE="3pt"
        else
            COMP_HEIGHT="${H_NUM}pt"
            COMP_LINE_SIZE="0pt"
        fi
    else
        # Modo floating (flotante)
        if [ "$TRANS" == "false" ]; then
            COMP_HEIGHT="$(( H_NUM + 3 ))pt"
            COMP_LINE_SIZE="3pt"
            if [ "$IS_BOTTOM" == "true" ]; then
                COMP_BORDER_TOP=0
                COMP_BORDER_BOTTOM=6
            else
                COMP_BORDER_TOP=6
                COMP_BORDER_BOTTOM=0
            fi
        else
            COMP_HEIGHT="${H_NUM}pt"
            COMP_LINE_SIZE="0pt"
            if [ "$IS_BOTTOM" == "true" ]; then
                COMP_BORDER_TOP=0
                COMP_BORDER_BOTTOM=5
            else
                COMP_BORDER_TOP=5
                COMP_BORDER_BOTTOM=0
            fi
        fi
    fi
else
    COMP_HEIGHT="${H_NUM}pt"
    COMP_LINE_SIZE="${LINE_SIZE}pt"
    COMP_BORDER_TOP=5
    COMP_BORDER_BOTTOM=5
fi

# Coeficientes proporcionales
F_TEXT=$(( H_NUM * 3 / 5 + 1 ))
F_ICON=$(( H_NUM + 1 ))
F_OFFSET=$(( (H_NUM - 6) / 3 ))
F_EXTRA=$(( H_NUM - 1 ))
F_SYM=$(( H_NUM * 13 / 20 + 1 ))
F_CURV=$(( H_NUM * 14 / 10 + 1 ))
F_CURV_OFFSET=$(( F_OFFSET + 1 ))
F_OFFSET_TEXT=$(( (H_NUM - F_TEXT) / 2 ))
F_OFFSET_SYM=$(( (H_NUM - F_SYM) / 2 ))
F_OFFSET_LARGE=$(( F_OFFSET_TEXT + 2 ))

if [ "$MODE" == "underline" ]; then
    F_SYM=$(( H_NUM * 11 / 20 + 1 ))
    F_ICON=$(( H_NUM * 3 / 4 ))
    F_OFFSET_TEXT=$(( (H_NUM - LINE_SIZE - F_TEXT) / 2 ))
    F_OFFSET_SYM=$(( (H_NUM - LINE_SIZE - F_SYM) / 2 - LINE_SIZE ))
    F_OFFSET_LARGE=$(( (H_NUM - LINE_SIZE - (F_SYM + 2)) / 2 ))
fi

# Normalización de offsets negativos y mínimos
[[ $F_OFFSET_TEXT -lt 0 ]] && F_OFFSET_TEXT=0
[[ $F_OFFSET_SYM -lt 0 ]] && F_OFFSET_SYM=0
[[ $F_OFFSET_LARGE -lt 0 ]] && F_OFFSET_LARGE=0
[[ $F_CURV_OFFSET -lt 1 ]] && F_CURV_OFFSET=1

# Colores y Estilos de Módulos
BG_COLOR=$([ "$TRANS" == "false" ] && echo "\${colors.background-solid}" || echo "#00000000")
COMPACT_BG_COLOR=$([ "$TRANS" == "false" ] && echo "\${colors.compact-bar-background}" || echo "#00000000")
if [ "$TRANS" == "false" ]; then
    P_TRANS="false"
else
    P_TRANS=$([ "$TRANS_TYPE" == "pseudo" ] && echo "true" || echo "false")
fi

# Definir esquema de resaltado
if [ "$MODE" == "underline" ]; then
    MOD_FOC_BG="$BG_COLOR"; MOD_FOC_FG="\${colors.primary}"; MOD_FOC_UND="\${colors.primary}"
    MOD_PRE_BG="$BG_COLOR"; MOD_PRE_FG="\${colors.primary}"
    
    if [ "$ROFI_STYLE" == "underline" ]; then
        MOD_ROFI_BG="$BG_COLOR"; MOD_ROFI_FG="\${colors.primary}"; MOD_ROFI_UND="\${colors.primary}"
        MOD_ROFI_FONT=5; LAUNCH_ICON=$'\u00a0'"${OS_ICON:-󰣆}"$'\u00a0'
        F_ROFI_SIZE=$(( H_NUM * 4 / 5 + 1 )); R_ROFI_OFFSET=$F_OFFSET
    else
        MOD_ROFI_BG="\${colors.primary}"; MOD_ROFI_FG="\${colors.background-solid}"; MOD_ROFI_UND=""
        MOD_ROFI_FONT=4; LAUNCH_ICON=$'\u00a0\u00a0'"${OS_ICON:-󰣆}"$'\u00a0\u00a0'
        F_ROFI_SIZE=$(( H_NUM * 13 / 20 + 1 )); R_ROFI_OFFSET=$(( (H_NUM - F_ROFI_SIZE) / 2 ))
    fi
else
    MOD_FOC_BG="\${colors.primary}"; MOD_FOC_FG="\${colors.surface}"; MOD_FOC_UND=""
    MOD_PRE_BG="\${colors.primary}"; MOD_PRE_FG="\${colors.surface}"
    MOD_ROFI_BG="\${colors.primary}"; MOD_ROFI_FG="\${colors.surface}"; MOD_ROFI_UND=""
    MOD_ROFI_FONT=5; LAUNCH_ICON=$'\u00a0\u00a0'"${OS_ICON:-󰣆}"$'\u00a0\u00a0'
    F_ROFI_SIZE=$(( H_NUM * 13 / 20 + 1 )); R_ROFI_OFFSET=$(( (H_NUM - F_ROFI_SIZE) / 2 ))
fi
[[ $R_ROFI_OFFSET -lt 0 ]] && R_ROFI_OFFSET=0
F_ROFI_NAME="Symbols Nerd Font Mono"

# 5. Generar variables.ini
VARS_FILE="$CONF_DIR/variables.ini"
cat > "$VARS_FILE" <<EOF
[vars]
height = $COMP_HEIGHT
radius = $RADIUS
bottom = $IS_BOTTOM
override-redirect = $OR_VAL
pseudo-transparency = $P_TRANS
background = $BG_COLOR
compact-background = $COMPACT_BG_COLOR
border-top = ${COMP_BORDER_TOP}pt
border-bottom = ${COMP_BORDER_BOTTOM}pt
line-size = $COMP_LINE_SIZE
comp-modules-hidden = $([ "$MODULES_VISIBILITY" == "visible" ] && echo "false" || echo "true")
font-0 = "JetBrainsMono Nerd Font Mono:style=Bold:size=$F_TEXT;$F_OFFSET_TEXT"
font-1 = "Symbols Nerd Font:size=$F_CURV;$F_CURV_OFFSET"
font-2 = "JetBrainsMono Nerd Font Mono:size=$F_TEXT:antialias=false;$F_OFFSET_TEXT"
font-rofi = "$F_ROFI_NAME:size=$F_ROFI_SIZE;$R_ROFI_OFFSET"
font-extra = "JetBrainsMono Nerd Font Mono:size=$F_EXTRA;$F_OFFSET_TEXT"
font-firacode = "FiraCode Nerd Font:size=$F_ICON;$F_OFFSET_TEXT"
font-symbols = "Symbols Nerd Font Mono:size=$F_SYM;$F_OFFSET_SYM"
font-large = "JetBrainsMono Nerd Font Mono:size=$((F_SYM + 2));$F_OFFSET_LARGE"
module-padding = 1
label-padding = 1
icon-padding = $ICON_PADDING
focused-bg = $MOD_FOC_BG
focused-fg = $MOD_FOC_FG
focused-underline = $MOD_FOC_UND
prefix-bg = $MOD_PRE_BG
prefix-fg = $MOD_PRE_FG
rofi-bg = $MOD_ROFI_BG
rofi-fg = $MOD_ROFI_FG
rofi-underline = $MOD_ROFI_UND
rofi-font = $MOD_ROFI_FONT
launcher-icon = $LAUNCH_ICON
launcher-icon-raw = ${OS_ICON:-󰣆}

; Icon Library
icon-cpu = 
icon-ram = 󰍛
icon-temp = 
icon-date = 󰃭
icon-disk = 󰋊
icon-vol = 󰕾
icon-light = 󰃠
icon-bat = 󱊣
EOF

# Crear enlace en RAM para compatibilidad o velocidad de lectura si es necesario
ln -sf "$VARS_FILE" "/dev/shm/user_configs.ini"

# 6. Enlace de Lanzador e Inicio
ln -sf "$PACKAGE_DIR/bin/polybar_launch.sh" "$CONF_DIR/system_launch.sh"
if [ -x "$THEME_SRC/launch.sh" ]; then
    ln -sf "current_theme/launch.sh" "$CONF_DIR/launch.sh"
else
    ln -sf "$CONF_DIR/system_launch.sh" "$CONF_DIR/launch.sh"
fi

if [ -n "$DISPLAY" ]; then
    bash "$CONF_DIR/launch.sh" >/tmp/polybar.log 2>&1 &
fi
