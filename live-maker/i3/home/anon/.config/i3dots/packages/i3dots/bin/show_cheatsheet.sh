#!/usr/bin/env bash
# show_cheatsheet.sh - Visor interactivo y categorizado de atajos con Rofi

# 1. Toggle si ya hay una instancia del visor corriendo
if pkill -f "rofi.*cheatsheet.rasi" 2>/dev/null; then
    exit 0
fi

# 2. Localizar archivo markdown fuente
BASE_DIR="${BASE_DIR:-$HOME/.config/i3dots}"
MD_FILE="$BASE_DIR/packages/i3dots/assets/cheatsheet.md"

if [ ! -f "$MD_FILE" ]; then
    MD_FILE="/home/dereck/dotfile/i3dots/packages/i3dots/assets/cheatsheet.md"
fi

if [ ! -f "$MD_FILE" ]; then
    notify-send -u critical "i3dots Atajos" "No se encontró el archivo de atajos: $MD_FILE" 2>/dev/null || true
    exit 1
fi

# 3. Localizar tema de Rofi
ROFI_THEME="$HOME/.config/rofi/themes/cheatsheet.rasi"
if [ ! -f "$ROFI_THEME" ]; then
    ROFI_THEME="$BASE_DIR/packages/i3dots/config/rofi/themes/cheatsheet.rasi"
fi

# 4. Funciones de extracción de datos
get_categories() {
    awk -F'|' '
    /^## / {
        sub(/^## /, "", $0)
        gsub(/^[ \t]+|[ \t]+$/, "", $0)
        cat = $0
        cats[cat] = 0
        cat_order[++n] = cat
        next
    }
    /^\|/ && !/Atajo/ && !/---/ {
        if (cat != "") cats[cat]++
    }
    END {
        for (i=1; i<=n; i++) {
            c = cat_order[i]
            printf "%-36s (%d atajos)\n", c, cats[c]
        }
        printf "󰍉  Ver todos los atajos\n"
    }
    ' "$MD_FILE"
}

get_shortcuts() {
    local target="$1"
    echo "󰌌  ← Volver a Categorías"
    awk -v target="$target" -F'|' '
    /^## / {
        sub(/^## /, "", $0)
        gsub(/^[ \t]+|[ \t]+$/, "", $0)
        in_cat = (target == "ALL" || $0 == target)
        cur_cat = $0
        next
    }
    /^\|/ && !/Atajo/ && !/---/ {
        if (in_cat) {
            key = $2; desc = $3
            gsub(/<\/?kbd>/, "", key)
            gsub(/^[ \t]+|[ \t]+$/, "", key)
            gsub(/^[ \t]+|[ \t]+$/, "", desc)
            if (key != "" && desc != "") {
                if (target == "ALL") {
                    printf "%-26s  ·  %-38s [%s]\n", key, desc, cur_cat
                } else {
                    printf "%-26s  ·  %s\n", key, desc
                }
            }
        }
    }
    ' "$MD_FILE"
}

# 5. Bucle de navegación
while true; do
    selected_cat=$(get_categories | rofi -dmenu -i \
        -p "󰌌 Categorías" \
        -theme "$ROFI_THEME" \
        -theme-str 'entry { placeholder: "Selecciona una categoría o busca..."; }')

    [ -z "$selected_cat" ] && exit 0

    if [[ "$selected_cat" =~ "Ver todos" ]]; then
        target_cat="ALL"
        prompt_title="󰌌 Todos los Atajos"
    else
        target_cat=$(echo "$selected_cat" | sed -E 's/[ \t]*\([0-9]+ atajos\)//; s/^[ \t]+|[ \t]+$//')
        prompt_title="󰌌 $target_cat"
    fi

    while true; do
        chosen=$(get_shortcuts "$target_cat" | rofi -dmenu -i \
            -p "$prompt_title" \
            -theme "$ROFI_THEME" \
            -theme-str 'entry { placeholder: "Filtrar atajo o presiona Escape para volver..."; }')

        # Si presiona Escape en el submenú, regresa al menú de categorías
        [ -z "$chosen" ] && break

        # Si selecciona el botón volver
        if [[ "$chosen" =~ "Volver a Categorías" ]]; then
            break
        fi

        # Si seleccionó un atajo real: copiar y notificar
        key=$(echo "$chosen" | awk -F'·' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
        desc=$(echo "$chosen" | awk -F'·' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')

        if [ -n "$key" ]; then
            echo -n "$key" | xclip -selection clipboard 2>/dev/null || true
            dunstify -i input-keyboard -t 3000 "Atajo Copiado" "$key\n$desc" 2>/dev/null || \
            notify-send -i input-keyboard -t 3000 "Atajo Copiado" "$key - $desc" 2>/dev/null || true
            exit 0
        fi
    done
done
