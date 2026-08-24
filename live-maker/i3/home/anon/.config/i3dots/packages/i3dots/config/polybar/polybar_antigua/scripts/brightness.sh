#!/bin/bash

# Obtener el brillo actual como porcentaje
current_brightness=$(brightnessctl get)
max_brightness=$(brightnessctl max)

# Calcular el porcentaje (asegúrate de que max_brightness no sea cero)
if [ "$max_brightness" -ne 0 ]; then
    percentage=$((current_brightness * 100 / max_brightness))
else
    percentage=0
fi

# Mostrar el resultado
echo "$percentage"
