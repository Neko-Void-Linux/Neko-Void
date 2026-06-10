#!/bin/bash
#
# NekoVoid Live ISO Builder - Nonfree Edition
# Genera la ISO con soporte nonfree: Steam, gaming, drivers propietarios, etc.
#
# Uso:
#   ./neko-builder.sh                        # Modo interactivo
#   ./neko-builder.sh <desktop>              # Construir escritorio específico
#   ./neko-builder.sh <desktop> -e "pkg..."  # Con paquetes extra
#   ./neko-builder.sh doble                  # Construir xlibre + xorg
#   ./neko-builder.sh doble-isor             # Construir rollibre + rolling
#
VERSION=$(date +"%Y%m%d")
set -euo pipefail

# ─────────────────────────────────────────────
# Configuración de salida
# ─────────────────────────────────────────────

ISO_TITLE="NekoVoid"

# ─────────────────────────────────────────────
# Driver NVIDIA (descomentar si tienes GPU NVIDIA)
# Debe definirse antes de cargar base-neko-pkgs.sh
# porque DEFAULT lo referencia.
# ─────────────────────────────────────────────
NVIDIA="${NVIDIA:-}"

# ─────────────────────────────────────────────
# Cargar definiciones de paquetes
# ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

. ./base-neko-pkgs.sh

# ─────────────────────────────────────────────
# Servicios base (el display manager se agrega
# automáticamente según el escritorio)
# ─────────────────────────────────────────────
SERVICES_BASE="dbus NetworkManager elogind polkitd rtkit sshd chronyd zramen tlp"

# ─────────────────────────────────────────────
# Colores para modo interactivo
# ─────────────────────────────────────────────
BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# ─────────────────────────────────────────────
# usage() – Ayuda
# ─────────────────────────────────────────────
usage() {
    cat <<EOF
${BOLD}NekoVoid Live ISO Builder${RESET}

Uso: $(basename "$0") [ESCRITORIO] [OPCIONES]
      $(basename "$0")                          ${CYAN}# Modo interactivo${RESET}

Escritorios disponibles:
  ${GREEN}xorg${RESET}       MATE + Xorg (kernel estable)
  ${GREEN}xlibre${RESET}     MATE + Xlibre (kernel estable, sólo libre)
  ${GREEN}rolling${RESET}    MATE + Xorg (kernel mainline)
  ${GREEN}rollibre${RESET}   MATE + Xlibre (kernel mainline, sólo libre)
  ${GREEN}kde${RESET}        KDE Plasma (kernel mainline)
  ${GREEN}lxqt${RESET}       LXQt (kernel mainline)
  ${GREEN}xfce${RESET}       XFCE (kernel mainline)
  ${GREEN}icejwm${RESET}     IceWM + JWM (kernel LTS)
  ${GREEN}cinnamon${RESET}   Cinnamon (kernel mainline)
  ${GREEN}lxde${RESET}       LXDE (kernel mainline)
  ${GREEN}i3${RESET}       I3 (kernel mainline)

Especiales:
  ${GREEN}doble${RESET}       Construir xlibre + xorg (ambos)
  ${GREEN}doble-isor${RESET}  Construir rollibre + rolling (ambos)

Opciones:
  -e, --extra "pkg1 pkg2"   Agregar paquetes extra a la ISO
  -h, --help                Mostrar esta ayuda

Ejemplos:
  $(basename "$0")                        # Menú interactivo
  $(basename "$0") icejwm                 # Construir IceWM directamente
  $(basename "$0") kde -e "gimp inkscape" # KDE + paquetes extra
  $(basename "$0") doble                  # Construir ambos (libre + nonfree)
EOF
}

# ─────────────────────────────────────────────
# build_iso() – Construye una ISO para un
#               escritorio específico
#
# Argumentos:
#   $1 = clave del escritorio
#   $2 = paquetes extra (opcional)
# ─────────────────────────────────────────────
build_iso() {
    local desktop="$1"
    local extra_pkgs="${2:-}"

    local pkg_var=""
    local includedir=""
    local kernel_kver=""
    local dm_service=""
    local iso_name=""

    # ─── Mapeo de escritorio → configuración ───
    case "$desktop" in
        xorg)
            pkg_var="PACKAGES_XORG"
            includedir="./includedir"
            kernel_kver=""
            dm_service="lightdm"
            iso_name="nekovoid-xorg-$VERSION.iso"
            ;;
        xlibre)
            pkg_var="PACKAGES_XLIBRE"
            includedir="./includedir"
            kernel_kver=""
            dm_service="lightdm"
            iso_name="nekovoid-xlibre-$VERSION.iso"
            ;;
        rolling)
            pkg_var="PACKAGES_XORG"
            includedir="./includedir"
            kernel_kver="linux-mainline"
            dm_service="lightdm"
            iso_name="nekovoid-rolling-xorg-$VERSION.iso"
            ;;
        rollibre)
            pkg_var="PACKAGES_XLIBRE"
            includedir="./includedir"
            kernel_kver="linux-mainline"
            dm_service="lightdm"
            iso_name="nekovoid-rolling-xlibre-$VERSION.iso"
            ;;
        kde)
            pkg_var="PACKAGES_KDE"
            includedir="./kdedir"
            kernel_kver="linux-lts"
            dm_service="sddm tlp-pd"
            iso_name="nekovoid-kde-$VERSION.iso"
            ;;
        lxqt)
            pkg_var="PACKAGES_LXQT"
            includedir="./lxqt"
            kernel_kver="linux-lts"
            dm_service="lightdm"
            iso_name="nekovoid-lxqt-$VERSION.iso"
            ;;
        i3)
            pkg_var="PACKAGES_I3"
            includedir="./i3"
            kernel_kver="linux-lts"
            dm_service="lightdm"
            iso_name="nekovoid-i3-$VERSION.iso"
            ;;
        xfce)
            pkg_var="PACKAGES_XFCE"
            includedir="./xfce"
            kernel_kver="linux-lts"
            dm_service="lightdm"
            iso_name="nekovoid-xfce-$VERSION.iso"
            ;;
        icejwm)
            pkg_var="PACKAGES_ICEJWM"
            includedir="./icejwm"
            kernel_kver="linux-lts"
            dm_service="lightdm"
            iso_name="nekovoid-lts-icejwm-$VERSION.iso"
            ;;
        cinnamon)
            pkg_var="PACKAGES_CINNAMON"
            includedir="./cinnamon"
            kernel_kver="linux-lts"
            dm_service="lightdm"
            iso_name="nekovoid-cinnamon-$VERSION.iso"
            ;;
        lxde)
            pkg_var="PACKAGES_LXDE"
            includedir="./lxde"
            kernel_kver="linux-lts"
            dm_service="lightdm"
            iso_name="nekovoid-lxde-$VERSION.iso"
            ;;
        *)
            echo -e "${BOLD}Error:${RESET} Escritorio desconocido '${desktop}'"
            echo "Usa --help para ver los escritorios disponibles."
            exit 1
            ;;
    esac

    # ─── Obtener lista de paquetes (indirect reference) ───
    local packages="${!pkg_var}"

    # ─── Agregar paquetes extra ───
    if [ -n "$extra_pkgs" ]; then
        packages="$packages $extra_pkgs"
    fi

    # ─── Banner informativo ───
    echo ""
    echo "============================================="
    echo "  NekoVoid Live ISO Builder (Nonfree)"
    echo "============================================="
    echo ""
    echo "  Escritorio:      ${desktop}"
    echo "  ISO de salida:   ${iso_name}"
    echo "  Paquetes total:  $(echo "${packages}" | wc -w)"
    if [ -n "$kernel_kver" ]; then
        echo "  Kernel:          ${kernel_kver}"
    else
        echo "  Kernel:          (por defecto)"
    fi
    if [ -n "$extra_pkgs" ]; then
        echo "  Paquetes extra:  ${extra_pkgs}"
    fi
    echo ""
    echo "============================================="
    echo ""

    # ─── Construir comando ───
    local cmd_args=(
        -I "$includedir"
        -o "$iso_name"
        -T "$ISO_TITLE"
        -p "$packages"
    )

    if [ -n "$kernel_kver" ]; then
        cmd_args+=(-v "$kernel_kver")
    fi

    cmd_args+=(-S "$SERVICES_BASE $dm_service")

    sudo ./mklive.sh -a x86_64 -i gzip -s zstd "${cmd_args[@]}"
}

# ─────────────────────────────────────────────
# interactive_menu() – Menú interactivo cuando
#                       no se pasan argumentos
# ─────────────────────────────────────────────
interactive_menu() {
    echo ""
    echo -e "${BOLD}=============================================${RESET}"
    echo -e "${BOLD}  NekoVoid Live ISO Builder – Interactivo${RESET}"
    echo -e "${BOLD}=============================================${RESET}"
    echo ""
    echo -e "  ${CYAN}Escritorios disponibles:${RESET}"
    echo ""
    echo -e "  ${GREEN} 1)${RESET} xorg      ${YELLOW}→${RESET} MATE + Xorg (kernel estable)"
    echo -e "  ${GREEN} 2)${RESET} xlibre    ${YELLOW}→${RESET} MATE + Xlibre (kernel estable, libre)"
    echo -e "  ${GREEN} 3)${RESET} rolling   ${YELLOW}→${RESET} MATE + Xorg (kernel mainline)"
    echo -e "  ${GREEN} 4)${RESET} rollibre  ${YELLOW}→${RESET} MATE + Xlibre (kernel mainline, libre)"
    echo -e "  ${GREEN} 5)${RESET} kde       ${YELLOW}→${RESET} KDE Plasma (kernel mainline)"
    echo -e "  ${GREEN} 6)${RESET} lxqt      ${YELLOW}→${RESET} LXQt (kernel mainline)"
    echo -e "  ${GREEN} 7)${RESET} xfce      ${YELLOW}→${RESET} XFCE (kernel mainline)"
    echo -e "  ${GREEN} 8)${RESET} icejwm    ${YELLOW}→${RESET} IceWM + JWM (kernel LTS)"
    echo -e "  ${GREEN} 9)${RESET} cinnamon  ${YELLOW}→${RESET} Cinnamon (kernel mainline)"
    echo -e "  ${GREEN}10)${RESET} lxde      ${YELLOW}→${RESET} LXDE (kernel mainline)"
    echo -e "  ${GREEN}11)${RESET} i3      ${YELLOW}→${RESET} I3 (kernel mainline)"
    echo ""

    local choice
    read -r -p "  Selecciona escritorio [1-10]: " choice

    local desktop
    case "$choice" in
        1)  desktop="xorg" ;;
        2)  desktop="xlibre" ;;
        3)  desktop="rolling" ;;
        4)  desktop="rollibre" ;;
        5)  desktop="kde" ;;
        6)  desktop="lxqt" ;;
        7)  desktop="xfce" ;;
        8)  desktop="icejwm" ;;
        9)  desktop="cinnamon" ;;
        10) desktop="lxde" ;;
        11) desktop="i3" ;;
        *)
            echo -e "${BOLD}Error:${RESET} Opción inválida '$choice'. Usa un número del 1 al 10."
            exit 1
            ;;
    esac

    echo ""
    read -r -p "  ¿Agregar paquetes extra? (nombres separados por espacio, Enter para omitir): " extra_pkgs

    build_iso "$desktop" "$extra_pkgs"
}

# ─────────────────────────────────────────────
# MAIN – Parseo de argumentos
# ─────────────────────────────────────────────
EXTRA_PKGS=""
DESKTOP=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -e|--extra)
            if [ $# -lt 2 ]; then
                echo "Error: -e/--extra requiere un argumento (ej: -e \"gimp inkscape\")"
                exit 1
            fi
            EXTRA_PKGS="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Error: Opción desconocida '$1'. Usa --help para ayuda."
            exit 1
            ;;
        *)
            if [ -z "$DESKTOP" ]; then
                DESKTOP="$1"
            else
                echo "Error: Ya se especificó el escritorio '$DESKTOP'. No se puede usar '$1' también."
                echo "Usa --help para ver la sintaxis."
                exit 1
            fi
            shift
            ;;
    esac
done

# ─── Si no hay escritorio especificado → modo interactivo ───
if [ -z "$DESKTOP" ]; then
    interactive_menu
    exit 0
fi

# ─── Despachar según el escritorio ───
case "$DESKTOP" in
    doble)
        echo -e "${CYAN}→ Construyendo xlibre + xorg...${RESET}"
        build_iso xlibre "$EXTRA_PKGS"
        echo ""
        build_iso xorg "$EXTRA_PKGS"
        ;;
    doble-isor)
        echo -e "${CYAN}→ Construyendo rollibre + rolling...${RESET}"
        build_iso rollibre "$EXTRA_PKGS"
        echo ""
        build_iso rolling "$EXTRA_PKGS"
        ;;
    *)
        build_iso "$DESKTOP" "$EXTRA_PKGS"
        ;;
esac
