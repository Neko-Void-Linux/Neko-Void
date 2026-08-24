#!/bin/bash

notify() {
    notify-send -r 555 -h int:value:"$1" "$2" "$3"
}

brightness() {
    brightnessctl set "$1" >/dev/null
    local val
    val=$(brightnessctl info | grep -oP '(?<=\()\d+(?=%)')
    notify "$val" "Brillo" "${val}%"
}

volume() {
    pactl set-sink-volume @DEFAULT_SINK@ "$1" >/dev/null
    local val mute
    val=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+(?=%)' | head -1)
    mute=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -oP 'yes|no')
    [ "$mute" = "yes" ] && notify "$val" "Volumen (Silenciado)" "${val}%" || notify "$val" "Volumen" "${val}%"
}

volume_mute() {
    pactl set-sink-mute @DEFAULT_SINK@ toggle >/dev/null
    local val mute
    val=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+(?=%)' | head -1)
    mute=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -oP 'yes|no')
    [ "$mute" = "yes" ] && notify "$val" "Volumen" "Silenciado" || notify "$val" "Volumen" "${val}%"
}

mic_mute() {
    pactl set-source-mute @DEFAULT_SOURCE@ toggle >/dev/null
    local mute
    mute=$(pactl get-source-mute @DEFAULT_SOURCE@ | grep -oP 'yes|no')
    [ "$mute" = "yes" ] && notify 0 "Micrófono" "Silenciado" || notify 100 "Micrófono" "Activado"
}

case "$1" in
    brightness) brightness "$2" ;;
    volume) volume "$2" ;;
    mute) volume_mute ;;
    mic_mute) mic_mute ;;
esac
