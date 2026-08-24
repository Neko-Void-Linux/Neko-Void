#!/usr/bin/env bash
# launch.sh - Lanzador de aplicaciones (Type-3 Style-3)

# 1. Obtener la ruta del wallpaper estático (miniatura si es dinámico)
IMAGE_PATH="$HOME/.config/i3/current_static"
if [[ ! -e "$IMAGE_PATH" ]]; then
    # Fallback al original si no existe el enlace estático
    if [[ -f "$HOME/.config/i3/wall" ]]; then
        read -r IMAGE_PATH < "$HOME/.config/i3/wall"
    else
        IMAGE_PATH=""
    fi
fi


# 2. Definir el tema
THEME="$HOME/.config/rofi/themes/style-3.rasi"

# 3. Ejecutar Rofi con la imagen de fondo dinámica en el inputbar
exec rofi -show drun -theme "$THEME" -theme-str "inputbar { background-image: url(\"$IMAGE_PATH\", width); }"
