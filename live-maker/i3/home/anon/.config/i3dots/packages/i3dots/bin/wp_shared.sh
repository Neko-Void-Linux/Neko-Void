#!/usr/bin/env bash
# packages/i3dots/bin/wp_shared.sh - Entorno y funciones compartidas para Wallpaper Helpers

# 1. Configurar Directorios Base
export BASE_DIR="${BASE_DIR:-$HOME/.config/i3dots}"
export ROOT_DIR="$BASE_DIR"
CUR_ENV="${CURRENT_ENV:-i3dots}"
STATE_DIR_VAL="${STATE_DIR:-$BASE_DIR/core/state}"
WP_STATE_DIR="$STATE_DIR_VAL/$CUR_ENV/wallpaper"
[[ -d "$WP_STATE_DIR" ]] || mkdir -p "$WP_STATE_DIR"

# Directorio de origen de wallpapers
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/wall}"

# Migración automática de configuración heredada a state.env unificado
if [[ ! -f "$WP_STATE_DIR/state.env" ]]; then
    touch "$WP_STATE_DIR/state.env"
    for var in "show_names_mode" "card_style" "join_text" "ind_text" "ind_block" "ind_border" "ind_underline" "ind_halo" "thumbnail_mode" "thumbnail_size" "no_thumb_mode" "bg_generation" "matugen_use_thumb" "active_mode"; do
        local legacy_file="$WP_STATE_DIR/$var"
        if [[ -f "$legacy_file" ]]; then
            local val=""
            read -r val < "$legacy_file"
            val="${val//[[:space:]]/}"
            if [[ -n "$val" ]]; then
                echo "${var}=\"${val}\"" >> "$WP_STATE_DIR/state.env"
            fi
            rm -f "$legacy_file"
        fi
    done
fi

# Cargar variables de estado unificadas
[[ -f "$WP_STATE_DIR/state.env" ]] && source "$WP_STATE_DIR/state.env"

# Helper para obtener estados guardados
get_state() {
    local key="$1"
    local default="$2"
    if [[ -n "${!key+x}" ]]; then
        echo "${!key}"
    else
        echo "$default"
    fi
}

# Helper de modo claro/oscuro: persiste y señaliza al sistema
set_theme_mode() { save_state "active_mode" "$1"; command -v gsettings &>/dev/null && gsettings set org.gnome.desktop.interface color-scheme "prefer-$1"; }

# Helper para persistir estados en un único archivo de configuración
save_state() {
    local key="$1"
    local val="$2"
    local env_file="$WP_STATE_DIR/state.env"
    
    [[ -f "$env_file" ]] || touch "$env_file"
    
    if grep -q "^${key}=" "$env_file"; then
        sed -i "s|^${key}=.*|${key}=\"${val}\"|" "$env_file"
    else
        echo "${key}=\"${val}\"" >> "$env_file"
    fi
    
    printf -v "$key" "%s" "$val"
}

# 2. Cargar/Recargar variables de configuración
load_wp_config() {
    [[ -f "$WP_STATE_DIR/state.env" ]] && source "$WP_STATE_DIR/state.env"
    THUMB_MODE=$(get_state "thumbnail_mode" "enabled")
    THUMB_SIZE=$(get_state "thumbnail_size" "450")
    NO_THUMB_MODE=$(get_state "no_thumb_mode" "original")
    BG_GENERATION=$(get_state "bg_generation" "true")
    MATUGEN_USE_THUMB=$(get_state "matugen_use_thumb" "true")
    
    THUMB_CROP_MODE=$(get_state "thumbnail_crop_mode" "fit")
    MATUGEN_CLEAN_TEMP=$(get_state "matugen_clean_temp" "true")
    MATUGEN_USE_FIT=$(get_state "matugen_use_fit" "true")
    
    THUMB_DIR="$WP_STATE_DIR/thumbs/${THUMB_SIZE}_${THUMB_CROP_MODE}"
}

# Inicializar configuración
load_wp_config

# 3. Detectar Dependencia de libvips
HAS_VIPS=0
command -v vipsthumbnail &>/dev/null && HAS_VIPS=1

# 4. Helper para obtener ruta física de miniatura
# Retorna en variable global RET_THUMB para evitar subshells $(...)
get_thumb_path() {
    local real_file="$1"
    local crop_mode="${2:-$THUMB_CROP_MODE}"
    local safe_name="${real_file//\//_}"
    RET_THUMB="$WP_STATE_DIR/thumbs/${THUMB_SIZE}_${crop_mode}/${safe_name}.jpg"
}

list_wallpapers() {
    if [[ "$LIVE_ONLY" -eq 1 ]]; then
        [[ -d "$WALLPAPER_DIR/live" ]] || mkdir -p "$WALLPAPER_DIR/live"
        find -L "$WALLPAPER_DIR/live" -type f \( -iname "*.gif" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" \) | sort
    else
        find -L "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort
    fi
}

# 5. Generador centralizado y optimizado de listas para Rofi
generate_rofi_list() {
    local line_tmpl="${1:-%f\x00icon\x1f%p}"
    local out=""
    local wallpapers_to_gen=""

    # Definir find command segun modo
    local find_cmd
    if [[ "$LIVE_ONLY" -eq 1 ]]; then
        [[ -d "$WALLPAPER_DIR/live" ]] || mkdir -p "$WALLPAPER_DIR/live"
        find_cmd=(find -L "$WALLPAPER_DIR/live" -type f \( -iname "*.gif" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" \))
    else
        find_cmd=(find -L "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \))
    fi

    # 1. Obtener rutas reales en bloque (un solo fork inicial)
    # 2. Bucle de procesamiento (0 forks internos usando builtins de bash)
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        local thumb_to_use="$file"
        if [[ "$THUMB_MODE" == "enabled" ]]; then
            get_thumb_path "$file"
            local thumb="$RET_THUMB"
            
            # [[ -ot ]] es builtin, no hace fork
            if [[ -f "$thumb" && "$file" -ot "$thumb" ]]; then
                thumb_to_use="$thumb"
            else
                wallpapers_to_gen+="$file"$'\n'
                if [[ "$NO_THUMB_MODE" == "original" ]]; then
                    thumb_to_use="$file"
                else
                    thumb_to_use="image-x-generic"
                fi
            fi
        fi

        # Para wallpapers en live/ usar ruta relativa respecto a wall/live
        local rel_path
        if [[ "$LIVE_ONLY" -eq 1 ]]; then
            rel_path="${file#$WALLPAPER_DIR/live/}"
        else
            rel_path="${file#$WALLPAPER_DIR/}"
        fi
        
        local line="$line_tmpl"
        line="${line//%f/${file##*/}}"
        line="${line//%r/$rel_path}"
        line="${line//%p/$thumb_to_use}"
        out+="$line"$'\n'
    done < <("${find_cmd[@]}" -print0 | xargs -0 realpath | sort -u)

    # Lanzar pre-caché async de fondo (Totalmente desacoplado para no bloquear Rofi)
    if [[ "$THUMB_MODE" == "enabled" ]] && [[ "$BG_GENERATION" == "true" ]] && [[ -n "$wallpapers_to_gen" ]]; then
        wp_cache.sh --bg-gen <<< "$wallpapers_to_gen" >/dev/null 2>&1 &
        disown $! 2>/dev/null || true
    fi

    echo -ne "$out"
}


