# Ejecutar rice_set solo en sesión gráfica
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    $HOME/i3dots/dots install i3dots void
fi