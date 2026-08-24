#!/usr/bin/env bash
# hooks/components/refresh.sh
# Recarga apps que necesitan señal para actualizar colores

#pkill -USR1 kitty 2>/dev/null || true
sleep 0.2
pkill -USR2 cava 2>/dev/null || true
dunstctl reload 2>/dev/null || true
