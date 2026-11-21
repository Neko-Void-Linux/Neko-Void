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
KERNEL_DEFAULT="linux-mainline"
KERNEL_STABLE="linux6.18"

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
SERVICES_BASE="dbus NetworkManager polkitd rtkit sshd chronyd zramen tlp tlp-pd"

# ─────────────────────────────────────────────
# Colores para modo interactivo
# ─────────────────────────────────────────────
BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# ─────────────────────────────────────────────
# run_as_root() – Eleva privilegios usando
#                 root directo, sudo, doas o su -c
# ─────────────────────────────────────────────
run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas "$@"
    elif command -v su >/dev/null 2>&1; then
        local escaped_cmd
        printf -v escaped_cmd '%q ' "$@"
        su -c "$escaped_cmd"
    else
        echo -e "${BOLD}Error:${RESET} No se encontró sudo, doas ni su para ejecutar como root." >&2
        exit 1
    fi
}

# ─────────────────────────────────────────────
# usage() – Ayuda
# ─────────────────────────────────────────────
usage() {
    cat <<EOF
${BOLD}NekoVoid Live ISO Builder${RESET}

Uso: $(basename "$0") [ESCRITORIO] [OPCIONES]
      $(basename "$0")                          ${CYAN}# Modo interactivo${RESET}

Escritorios disponibles:
  ${GREEN}mate${RESET}        MATE + Xorg (kernel mainline)
  ${GREEN}matelibre${RESET}   MATE + Xlibre (kernel mainline, sólo libre)
  ${GREEN}kde${RESET}         KDE Plasma (kernel mainline)
  ${GREEN}lxqt${RESET}        LXQt (kernel mainline)
  ${GREEN}xfce${RESET}        XFCE (kernel LTS)
  ${GREEN}icewm${RESET}       IceWM (kernel LTS)
  ${GREEN}jwm${RESET}         JWM (kernel LTS)
  ${GREEN}cinnamon${RESET}    Cinnamon (kernel LTS)
  ${GREEN}labwc${RESET}       Labwc (kernel mainline)
  ${GREEN}niri${RESET}        Niri (kernel mainline)
  ${GREEN}i3${RESET}          i3 (kernel mainline)
  ${GREEN}musl${RESET}        Musl (kernel mainline)
  ${GREEN}nvidia${RESET}      Niri + NVIDIA Legacy 575 (drivers via postsetup)
  ${GREEN}nvidia-open${RESET} Labwc + NVIDIA Open 620 (drivers via postsetup)

Especiales:
  ${GREEN}doble${RESET}       Construir xlibre + xorg (ambos)
  ${GREEN}doble-isor${RESET}  Construir rollibre + rolling (ambos)

Opciones:
  -e, --extra "pkg1 pkg2"   Agregar paquetes extra a la ISO
  -h, --help                Mostrar esta ayuda

Ejemplos:
  $(basename "$0")                        # Menú interactivo
  $(basename "$0") icewm                  # Construir IceWM directamente
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
    local arch=""
    local postsetup=""

    # ─── Mapeo de escritorio → configuración ───
    case "$desktop" in
        mate)
            pkg_var="PACKAGES_XORG"
            includedir="./mate"
            kernel_kver="$KERNEL_DEFAULT"
            dm_service="lightdm"
            iso_name="nekovoid-mate-$VERSION.iso"
            arch="x86_64"
            ;;
        matelibre)
            pkg_var="PACKAGES_XLIBRE"
            includedir="./mate"
            kernel_kver="$KERNEL_DEFAULT"
            dm_service="lightdm"
            iso_name="nekovoid-matelibre-$VERSION.iso"
            arch="x86_64"
            ;;
        kde)
            pkg_var="PACKAGES_KDE"
            includedir="./kdedir"
            kernel_kver="$KERNEL_DEFAULT"
            dm_service="sddm tlp-pd"
            iso_name="nekovoid-kde-$VERSION.iso"
            arch="x86_64"
            ;;
        lxqt)
            pkg_var="PACKAGES_LXQT"
            includedir="./lxqt"
            kernel_kver="$KERNEL_DEFAULT"
            dm_service="lightdm"
            iso_name="nekovoid-lxqt-$VERSION.iso"
            arch="x86_64"
            ;;
        i3)
            pkg_var="PACKAGES_I3"
            includedir="./i3"
            kernel_kver="$KERNEL_DEFAULT"
            dm_service="lightdm"
            iso_name="nekovoid-i3-$VERSION.iso"
            arch="x86_64"
            ;;
        xfce)
            pkg_var="PACKAGES_XFCE"
            includedir="./xfce"
            kernel_kver="linux-lts"
            dm_service="lightdm"
            iso_name="nekovoid-xfce-$VERSION.iso"
            arch="x86_64"
            ;;
        icewm)
            pkg_var="PACKAGES_ICEWM"
            includedir="./icewm"
            kernel_kver="linux-lts"
            dm_service="lightdm"
            iso_name="nekovoid-lts-icewm-$VERSION.iso"
            arch="x86_64"
            ;;
        jwm)
            pkg_var="PACKAGES_JWM"
            includedir="./jwm"
            kernel_kver="linux-lts"
            dm_service="lightdm"
            iso_name="nekovoid-lts-jwm-$VERSION.iso"
            arch="x86_64"
            ;;
        cinnamon)
            pkg_var="PACKAGES_CINNAMON"
            includedir="./cinnamon"
            kernel_kver="linux-lts"
            dm_service="lightdm"
            iso_name="nekovoid-cinnamon-$VERSION.iso"
            arch="x86_64"
            ;;
        labwc)
            pkg_var="PACKAGES_LABWC"
            includedir="./labwc"
            kernel_kver="$KERNEL_DEFAULT"
            dm_service="emptty"
            iso_name="nekovoid-labwc-$VERSION.iso"
            arch="x86_64"
            ;;
        niri)
            pkg_var="PACKAGES_NIRI"
            includedir="./niri"
            kernel_kver="$KERNEL_DEFAULT"
            dm_service="emptty"
            iso_name="nekovoid-niri-$VERSION.iso"
            arch="x86_64"
            ;;
        musl)
            pkg_var="PACKAGES_MUSL"
            includedir="./musl"
            kernel_kver="$KERNEL_DEFAULT"
            dm_service="lightdm"
            iso_name="nekovoid-musl-$VERSION.iso"
            arch="x86_64-musl"
            ;;
        nvidia)
            pkg_var="PACKAGES_NIRI"
            includedir="./niri"
            kernel_kver="$KERNEL_DEFAULT"
            dm_service="emptty"
            iso_name="nekovoid-nvidia-$VERSION.iso"
            arch="x86_64"
            postsetup="./postsetup-nvidia.sh"
            ;;
        nvidia-open)
            pkg_var="PACKAGES_LABWC"
            includedir="./labwc"
            kernel_kver="$KERNEL_DEFAULT"
            dm_service="emptty"
            iso_name="nekovoid-nvidia-open-$VERSION.iso"
            arch="x86_64"
            postsetup="./postsetup-nvidia-open.sh"
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

    # ─── Paquetes específicos por build ───
    if [ -n "$postsetup" ]; then
        packages="$packages ${kernel_kver}-headers"
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
        -a "$arch"
        -I "$includedir"
        -o "$iso_name"
        -T "$ISO_TITLE"
        -p "$packages"
    )

    if [ -n "$postsetup" ]; then
        if [ ! -f "$postsetup" ] || [ ! -x "$postsetup" ]; then
            echo -e "${BOLD}Error:${RESET} Postsetup script no encontrado o no ejecutable: $postsetup"
            exit 1
        fi
    fi

    if [ -n "$kernel_kver" ]; then
        cmd_args+=(-v "$kernel_kver")
    fi

    if [ -n "$postsetup" ]; then
        cmd_args+=(-x "$postsetup")
    fi

    cmd_args+=(-S "$SERVICES_BASE $dm_service")

    run_as_root ./mklive.sh \
        -r https://github.com/xlibre-void/xlibre/releases/latest/download \
        -r https://github.com/Neko-Void-Linux/repo-neko/releases/download/stable \
        -r https://repo-de.voidlinux.org/current/nonfree \
        -r https://repo-de.voidlinux.org/current \
        -r https://repo-de.voidlinux.org/current/multilib/nonfree \
        -r https://repo-de.voidlinux.org/current/multilib \
        -r https://repo-de.voidlinux.org/current/musl/bootstrap \
        -r https://repo-de.voidlinux.org/current/musl \
        -r https://repo-de.voidlinux.org/current/musl/nonfree \
        -r https://sourceforge.net/projects/neko-void/files/repo/musl \
        -i xz -s zstd -L 22 "${cmd_args[@]}"

    sha256sum "${iso_name}" >> "${iso_name}.txt"
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
    echo -e "  ${GREEN} 1)${RESET} mate        ${YELLOW}→${RESET} MATE + Xorg (kernel mainline)"
    echo -e "  ${GREEN} 2)${RESET} matelibre   ${YELLOW}→${RESET} MATE + Xlibre (kernel mainline, libre)"
    echo -e "  ${GREEN} 3)${RESET} kde         ${YELLOW}→${RESET} KDE Plasma (kernel mainline)"
    echo -e "  ${GREEN} 4)${RESET} lxqt        ${YELLOW}→${RESET} LXQt (kernel mainline)"
    echo -e "  ${GREEN} 5)${RESET} xfce        ${YELLOW}→${RESET} XFCE (kernel LTS)"
    echo -e "  ${GREEN} 6)${RESET} icewm       ${YELLOW}→${RESET} IceWM (kernel LTS)"
    echo -e "  ${GREEN} 7)${RESET} jwm         ${YELLOW}→${RESET} JWM (kernel LTS)"
    echo -e "  ${GREEN} 8)${RESET} cinnamon    ${YELLOW}→${RESET} Cinnamon (kernel LTS)"
    echo -e "  ${GREEN} 9)${RESET} lxde        ${YELLOW}→${RESET} LXDE (kernel mainline)"
    echo -e "  ${GREEN}10)${RESET} labwc       ${YELLOW}→${RESET} Labwc (kernel mainline)"
    echo -e "  ${GREEN}11)${RESET} i3          ${YELLOW}→${RESET} i3 (kernel mainline)"
    echo -e "  ${GREEN}12)${RESET} niri        ${YELLOW}→${RESET} Niri (kernel mainline)"
    echo -e "  ${GREEN}13)${RESET} nvidia      ${YELLOW}→${RESET} Niri + NVIDIA Legacy 575 (postsetup)"
    echo -e "  ${GREEN}14)${RESET} nvidia-open ${YELLOW}→${RESET} Labwc + NVIDIA Open 620 (postsetup)"
    echo ""

    local choice
    read -r -p "  Selecciona escritorio [1-14]: " choice

    local desktop
    case "$choice" in
        1)  desktop="mate" ;;
        2)  desktop="matelibre" ;;
        3)  desktop="kde" ;;
        4)  desktop="lxqt" ;;
        5)  desktop="xfce" ;;
        6)  desktop="icewm" ;;
        7)  desktop="jwm" ;;
        8)  desktop="cinnamon" ;;
        9)  desktop="lxde" ;;
        10) desktop="labwc" ;;
        11) desktop="i3" ;;
        12) desktop="niri" ;;
        13) desktop="nvidia" ;;
        14) desktop="nvidia-open" ;;
        *)
            echo -e "${BOLD}Error:${RESET} Opción inválida '$choice'. Usa un número del 1 al 14."
            exit 1
            ;;
    esac

    echo ""
    read -r -p "  ¿Agregar paquetes extra? (nombres separados por espacio, Enter para omitir): " extra_pkgs

    build_iso "$desktop" "$extra_pkgs"
}


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

if [ -z "$DESKTOP" ]; then
    interactive_menu
    exit 0
fi

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
