#!/usr/bin/env bash
# packages/i3dots/bin/wp_cache.sh - Helper de administración de caché de wallpapers (Backend)

# 1. Parseo de argumentos
CACHE_NOW=0
CLEAN_CACHE=0
CLEAN_ARG=""
BG_GEN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -CN|--cache-now) CACHE_NOW=1; shift ;;
        -CC|--clean-cache)
            CLEAN_CACHE=1
            CLEAN_ARG="$2"
            shift; [[ $# -gt 0 ]] && shift
            ;;
        --bg-gen) BG_GEN=1; shift ;;
        *) shift ;;
    esac
done

# 2. Cargar entorno y lógica compartida
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wp_shared.sh"

# 2.5 Lock de seguridad para evitar concurrencia
LOCK_FILE="/dev/shm/wp_cache_${UID}.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    # Si ya hay una instancia corriendo, salir en silencio
    exit 0
fi

# Helper para generar miniatura segun tipo de archivo
generate_single_thumb() {
    local input_file="$1"
    local output_thumb="$2"
    
    if [[ "$input_file" =~ \.(mp4|webm|mkv|mov)$ ]]; then
        if command -v ffmpegthumbnailer &>/dev/null; then
            nice -n 19 ffmpegthumbnailer -i "$input_file" -o "$output_thumb" -s "$THUMB_SIZE" &>/dev/null
            return $?
        fi
    else
        if [[ "$HAS_VIPS" -eq 1 ]]; then
            local vips_args=(-s "$THUMB_SIZE")
            [[ "$THUMB_CROP_MODE" == "crop" ]] && vips_args=(-s "${THUMB_SIZE}x${THUMB_SIZE}" -m centre)
            nice -n 19 vipsthumbnail "${vips_args[@]}" -o "$output_thumb" "$input_file" 2>/dev/null
            return $?
        fi
    fi
    return 1
}

# 3. Modo: Pre-caché en background (--bg-gen)
if [[ "$BG_GEN" -eq 1 ]]; then
    if [[ ! -t 0 ]]; then
        wallpapers_found=$(cat)
    else
        wallpapers_found=$(list_wallpapers)
    fi
    [[ -z "$wallpapers_found" ]] && exit 0
    
    [[ -d "$THUMB_DIR" ]] || mkdir -p "$THUMB_DIR"
    
    # Bucle secuencial de baja prioridad para wallpapers faltantes
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ -L "$file" ]]; then
            real_file=$(readlink -f "$file")
        else
            real_file="$file"
        fi
        get_thumb_path "$real_file"
        thumb="$RET_THUMB"
        if [[ ! -f "$thumb" || "$real_file" -nt "$thumb" ]]; then
            generate_single_thumb "$real_file" "$thumb"
        fi
    done <<< "$wallpapers_found"
    exit 0
fi

# 4. Modo: Cachear Ahora (--cache-now)
if [[ "$CACHE_NOW" -eq 1 ]]; then
    wallpapers_found=$(list_wallpapers)
    [[ -z "$wallpapers_found" ]] && { echo "No se encontraron wallpapers." >&2; exit 0; }
    
    [[ -d "$THUMB_DIR" ]] || mkdir -p "$THUMB_DIR"
    
    # Filtrar imágenes pendientes
    mapfile -t files <<< "$wallpapers_found"
    declare -a pending=()
    for file in "${files[@]}"; do
        [[ -z "$file" ]] && continue
        if [[ -L "$file" ]]; then
            real_file=$(readlink -f "$file")
        else
            real_file="$file"
        fi
        get_thumb_path "$real_file"
        thumb="$RET_THUMB"
        if [[ ! -f "$thumb" || "$real_file" -nt "$thumb" ]]; then
            pending+=("$real_file")
        fi
    done
    
    total="${#pending[@]}"
    if [[ "$total" -eq 0 ]]; then
        echo "Caché al día. No hay miniaturas pendientes."
        exit 0
    fi
    
    echo "Generando caché de miniaturas (Calidad: ${THUMB_SIZE}px) para $total wallpapers..."
    count=0
    for file in "${pending[@]}"; do
        count=$((count+1))
        echo -e "\e[1A\e[K[$count/$total] Procesando: ${file##*/}"
        get_thumb_path "$file"
        thumb="$RET_THUMB"
        generate_single_thumb "$file" "$thumb"
    done
    

    echo "Caché de miniaturas completado."
    exit 0
fi


# 5. Modo: Limpiar Caché (--clean-cache)
if [[ "$CLEAN_CACHE" -eq 1 ]]; then
    root_thumbs="$WP_STATE_DIR/thumbs"
    [[ ! -d "$root_thumbs" ]] && { echo "Caché vacía. Nada que limpiar." >&2; exit 0; }
    
    case "$CLEAN_ARG" in
        orphans)
            echo "Buscando miniaturas huérfanas en todas las calidades..."
            wallpapers_found=$(list_wallpapers)
            
            declare -A active_walls
            while IFS= read -r file; do
                [[ -n "$file" ]] && active_walls["$file"]=1
            done <<< "$wallpapers_found"
            
            declare -A active_safes
            for w in "${!active_walls[@]}"; do
                safe="${w//\//_}"
                active_safes["$safe"]=1
            done
            
            deleted_count=0
            while IFS= read -r -d '' thumb_file; do
                [[ -z "$thumb_file" ]] && continue
                t_name="${thumb_file##*/}"
                t_name="${t_name%.jpg}"
                if [[ -z "${active_safes[$t_name]}" ]]; then
                    rm -f "$thumb_file"
                    deleted_count=$((deleted_count+1))
                fi
            done < <(find "$root_thumbs" -type f -name "*.jpg" -print0 2>/dev/null)
            
            echo "Limpieza completada. Borradas $deleted_count miniaturas huérfanas."
            ;;
        300|450|600|[0-9]*)
            size_dir="$root_thumbs/$CLEAN_ARG"
            if [[ -d "$size_dir" ]]; then
                rm -rf "$size_dir"
                echo "Caché de calidad $CLEAN_ARG px eliminada."
            else
                echo "No existe caché para la calidad $CLEAN_ARG px."
            fi
            ;;
        keep-active)
            echo "Eliminando todas las calidades excepto la activa (${THUMB_SIZE}px)..."
            while IFS= read -r -d '' dir; do
                [[ -z "$dir" ]] && continue
                dir_name="${dir##*/}"
                if [[ "$dir_name" != "$THUMB_SIZE" ]]; then
                    rm -rf "$dir"
                    echo "Eliminada calidad residual: ${dir_name}px"
                fi
            done < <(find "$root_thumbs" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
            ;;
        full)
            echo "Vaciando toda la caché de miniaturas..."
            rm -rf "$root_thumbs"
            echo "Caché completa eliminada."
            ;;
        *)
            echo "Opción de limpieza no válida. Opciones: orphans, Baja (300), Media (450), Alta (600), entero, keep-active, full" >&2
            exit 1
            ;;
    esac
    exit 0
fi

echo "Error: wp_cache.sh requiere --cache-now, --clean-cache o --bg-gen" >&2
exit 1
