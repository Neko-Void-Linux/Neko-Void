#!/bin/bash
#
# NekoVoid Live ISO Builder - Nonfree Edition
# Genera la ISO con soporte nonfree: Steam, gaming, drivers propietarios, etc.
#

set -e

# ─────────────────────────────────────────────
# Configuración de salida
# ─────────────────────────────────────────────
ISO_NAME="nekovoid-beta-7.1-xorg.iso"
ISO_TITLE="NekoVoid"

# ─────────────────────────────────────────────
# Repositorios (nonfree + multilib)
# ─────────────────────────────────────────────
REPOS_PKGS="void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree"

# ─────────────────────────────────────────────
# Sistema base y utilidades
# ─────────────────────────────────────────────
BASE_SYSTEM="
    base-system
    at-spi2-core
    bash-completion
    cryptsetup
    dbus
    dialog
    elogind
    grub
    mdadm
    nano
    rtkit
    xdo
    xsetroot
    xinit
    Neko-Wizard
    neko-icons
    neko-themes
    neko-backgrounds
    xtools
    tmux
"

SYSTEM_UTILS="
    7zip
    p7zip
    unrar
    zip
    xxd
    xz
    btop
    fastfetch
    curl
    wget
    git
    xdg-user-dirs
    xdg-utils
    ethtool
    iproute2
    lvm2
    polkit
    udisks2
    eudev
    void-docs-browse
    xtools-minimal
    openssh
    chrony
"

# ─────────────────────────────────────────────
# Networking
# ─────────────────────────────────────────────
NETWORKING="
    NetworkManager
    network-manager-applet
    wpa_supplicant
    iw
"

# ─────────────────────────────────────────────
# Audio (PipeWire stack completo)
# ─────────────────────────────────────────────
AUDIO="
    pipewire
    wireplumber
    alsa-lib
    alsa-utils
    alsa-pipewire
    libjack-pipewire
    pavucontrol
    pulsemixer
    rsync
    volumeicon
"

# ─────────────────────────────────────────────
# Xorg + drivers GPU
# ─────────────────────────────────────────────
XORG="
    xorg
    xmirror
    libva-intel-driver
    intel-media-driver
    orca
"

GPU_DRIVERS="
    mesa
    mesa-dri
    mesa-vaapi
    vulkan-loader
    Vulkan-Tools
    libglvnd
    linux-firmware-intel
    linux-firmware-amd
"

# ─────────────────────────────────────────────
# Escritorio MATE
# ─────────────────────────────────────────────
MATE_DESKTOP="
    mate
    mate-extra
    mate-tweak
    mate-polkit
    mate-terminal
    pluma
    caja-wallpaper
    caja-sendto
    caja-open-terminal
    caja-extensions
    atril
    gnome-screenshot
    gnome-keyring
    gvfs-afc
    gvfs-mtp
    gvfs-smb
    lightdm
    lightdm-webkit2-greeter
    lightdm-gtk-greeter-settings
    libnotify
    numlockx
    picom
    lxappearance
"

# ─────────────────────────────────────────────
# Aplicaciones de escritorio
# ─────────────────────────────────────────────
DESKTOP_APPS="
    firefox
    ristretto
    geany
    mpv
    arandr
    xarchiver
    gparted
    gnome-software
"

# ─────────────────────────────────────────────
# Flatpak + portales
# ─────────────────────────────────────────────
FLATPAK="
    flatpak
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    octoxbps
"

# ─────────────────────────────────────────────
# Fuentes
# ─────────────────────────────────────────────
FONTS="
    noto-fonts-emoji
    noto-fonts-cjk
    noto-fonts-ttf
    font-awesome
    dejavu-fonts-ttf
    liberation-fonts-ttf
    font-misc-misc
    terminus-font
"

# ─────────────────────────────────────────────
# Multimedia / codecs
# ─────────────────────────────────────────────
MULTIMEDIA="
    ffmpeg
    gstreamer1
    gst-plugins-base1
    gst-plugins-good1
    gst-plugins-bad1
    gst-plugins-ugly1
"

# ─────────────────────────────────────────────
# Librerías 32-bit (requeridas para Steam)
# ─────────────────────────────────────────────
MULTILIB_32BIT="
    mesa-32bit
    mesa-dri-32bit
"

# ─────────────────────────────────────────────
# Gaming
# ─────────────────────────────────────────────
GAMING="
    gamemode
    MangoHud
"

# ─────────────────────────────────────────────
# Otros
# ─────────────────────────────────────────────
OTHER="
    ntp
    zramen
"

# ─────────────────────────────────────────────
# Accesibilidad
# ─────────────────────────────────────────────
ACCESSIBILITY="
    espeakup
    void-live-audio
    brltty
"

# ─────────────────────────────────────────────
# Driver NVIDIA (descomentar si tienes GPU NVIDIA)
# ─────────────────────────────────────────────
#NVIDIA="nvidia nvidia-libs-32bit"
NVIDIA=""

# ─────────────────────────────────────────────
# Construir la lista completa de paquetes
# ─────────────────────────────────────────────
ALL_PACKAGES="
    ${REPOS_PKGS}
    ${BASE_SYSTEM}
    ${SYSTEM_UTILS}
    ${NETWORKING}
    ${AUDIO}
    ${XORG}
    ${GPU_DRIVERS}
    ${MATE_DESKTOP}
    ${DESKTOP_APPS}
    ${FLATPAK}
    ${FONTS}
    ${MULTIMEDIA}
    ${GAMING}
    ${OTHER}
    ${ACCESSIBILITY}
    ${NVIDIA}
"

# Limpiar espacios extra y newlines, convertir a una línea
PACKAGES=$(echo ${ALL_PACKAGES} | tr -s ' ')

echo "============================================="
echo " NekoVoid Live ISO Builder (Nonfree)"
echo "============================================="
echo ""
echo "ISO de salida: ${ISO_NAME}"
echo "Paquetes totales: $(echo ${PACKAGES} | wc -w)"
echo ""

sudo ./mklive.sh \
    -I includedir \
    -o "${ISO_NAME}" \
    -T "${ISO_TITLE}" \
    -p "${PACKAGES}" \
    -S "dbus elogind NetworkManager lightdm polkitd rtkit sshd chronyd zramen"
