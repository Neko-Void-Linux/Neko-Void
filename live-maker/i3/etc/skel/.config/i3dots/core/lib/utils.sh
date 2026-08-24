#!/usr/bin/env bash
# Biblioteca compartida de utilidades de dots (core/lib/utils.sh)

# Definición de colores ANSI
NC="\e[0m" BOLD="\e[1m" GRAY="\e[90m"
RED="\e[31m" GREEN="\e[32m" YELLOW="\e[33m"
BLUE="\e[34m" CYAN="\e[36m"

# Logger unificado
log_msg() {
    local indent="$1" color="$2" prefix="$3" msg="$4" fd="${5:-1}"
    echo -e "${indent}${color}${prefix}${NC} ${color}${msg}${NC}" >&"$fd"
}
print_step()     { log_msg ""     "$BLUE"   "•" "$1"; }
print_success()  { log_msg ""     "$GREEN"  "•" "$1"; }
print_sub()      { log_msg "  "   "$GRAY"   "•" "$1"; }
print_sub_ok()   { log_msg "  "   "$GREEN"  "•" "$1"; }
print_sub_warn() { log_msg "  "   "$YELLOW" "•" "$1"; }
print_sub_err()  { log_msg "  "   "$RED"    "•" "$1" 2; }

# Detección del elevador de privilegios (SUDO_CMD o ELEVATOR)
ELEVATOR="${ELEVATOR:-$SUDO_CMD}"
[ -z "$ELEVATOR" ] && [ "$EUID" -ne 0 ] && {
    command -v sudo &>/dev/null && ELEVATOR="sudo" || { command -v doas &>/dev/null && ELEVATOR="doas" || ELEVATOR=""; }
}

ask_privileges() {
    [ "$EUID" -eq 0 ] && return 0
    [ -z "$ELEVATOR" ] && return 0
    
    # No preguntar si ya tenemos privilegios sin contraseña (cached)
    if run_elevated_nopasswd; then
        return 0
    fi

    print_step "Se requieren privilegios para continuar. Ingresa tu contraseña."
    
    # sudo usa -v, doas usa true (doas no tiene -v)
    local check_cmd
    [[ "$ELEVATOR" == "sudo" ]] && check_cmd="-v" || check_cmd="true"

    if "$ELEVATOR" $check_cmd; then
        if [[ "$ELEVATOR" == "sudo" ]]; then
            # Mantener sudo vivo en segundo plano
            while true; do "$ELEVATOR" -n -v; sleep 60; done 2>/dev/null &
            SUDO_KEEP_ALIVE_PID=$!
            trap 'kill $SUDO_KEEP_ALIVE_PID 2>/dev/null' EXIT
        fi
        print_sub_ok "Privilegios confirmados."
    else
        print_sub_err "No se obtuvieron privilegios. Algunas tareas fallarán."
        return 1
    fi
}

run_elevated() {
    local ticker=false
    if [[ "$1" == "--ticker" ]]; then ticker=true; shift; fi

    if [ "$ticker" = "true" ]; then
        local cmd=("$@")
        local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
        local i=0
        local line
        
        # Ejecutar en segundo plano redirigiendo salida a archivo temporal
        local runner=""
        [ "$EUID" -ne 0 ] && [ -n "$ELEVATOR" ] && runner="$ELEVATOR"

        local tmp_log="/tmp/ticker_$$.log"
        $runner "${cmd[@]}" < /dev/null > "$tmp_log" 2>&1 &
        local pid=$!
        while kill -0 $pid 2>/dev/null; do
            local line=$(tail -n 1 "$tmp_log" 2>/dev/null | tr -d '\r\n')
            printf "\r  ${GRAY}%s${NC} ${GRAY}Trabajando...${NC} %s\e[K" "${spinner:$((i++ % 10)):1}" "${line:0:60}"
            sleep 0.1
        done
        wait $pid; local exit_code=$?
        cat "$tmp_log" >> "${LOG_FILE:-/dev/null}" 2>/dev/null; rm -f "$tmp_log"
        printf "\r\e[K"
        return $exit_code
    fi

    if [ "$EUID" -ne 0 ] && [ -n "$ELEVATOR" ]; then
        "$ELEVATOR" "$@" &>> "${LOG_FILE:-/dev/null}"
    else
        "$@" &>> "${LOG_FILE:-/dev/null}"
    fi
}

run_elevated_nopasswd() {
    [ "$EUID" -eq 0 ] && return 0
    [ -n "$ELEVATOR" ] && "$ELEVATOR" -n true 2>/dev/null
}
