#!/bin/dash

read -r uptime_now _ < /proc/uptime
uptime_sec="${uptime_now%.*}"

read -r last_sec < /tmp/toggle_borders.last 2>/dev/null
last_sec="${last_sec:-0}"

if [ "$uptime_sec" = "$last_sec" ]; then
    exit 0
fi
echo "$uptime_sec" > /tmp/toggle_borders.last

MY_UID=$(id -u)
if [ -z "$HOME" ]; then
    HOME=$(getent passwd "$MY_UID" | cut -d: -f6)
fi
export HOME
if [ -z "$USER" ]; then
    USER=$(id -un)
fi
export USER

# Directorio base de i3dots
BASE_DIR="${DOTS_DIR:-$HOME/.config/i3dots}"
STATE_FILE="$BASE_DIR/core/state/i3dots/borders/state.env"

mkdir -p "$(dirname "$STATE_FILE")"

if [ ! -f "$STATE_FILE" ]; then
    echo 'enabled="true"' > "$STATE_FILE"
fi

. "$STATE_FILE" 2>/dev/null
CURRENT_VAL="${enabled:-true}"

if [ "$CURRENT_VAL" = "true" ]; then
    NEW_VAL="false"
else
    NEW_VAL="true"
fi

if grep -q '^enabled=' "$STATE_FILE"; then
    sed -i 's/^enabled=".*"/enabled="'"$NEW_VAL"'"/' "$STATE_FILE"
else
    echo "enabled=\"$NEW_VAL\"" >> "$STATE_FILE"
fi

BORDERS_FILE="$HOME/.config/i3/conf.d/borders_override.conf"

if [ "$NEW_VAL" = "true" ]; then
    i3-msg '[class=".*"] border pixel 1' >/dev/null 2>&1
    echo 'for_window [class=".*"] border pixel 1' > "$BORDERS_FILE"
else
    i3-msg '[class=".*"] border none' >/dev/null 2>&1
    echo 'for_window [class=".*"] border none' > "$BORDERS_FILE"
fi

i3-msg reload >/dev/null 2>&1
