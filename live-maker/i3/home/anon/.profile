# Ejecutar rice_set solo en sesión gráfica
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    /usr/bin/rice_set
fi