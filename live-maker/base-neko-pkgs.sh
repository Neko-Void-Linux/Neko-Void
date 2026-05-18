#!/bin/bash
REPOS_PKGS="void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree"

# ─────────────────────────────────────────────
# Sistema base y utilidades
# ─────────────────────────────────────────────
BASE_SYSTEM="
    grub-i386-efi
    grub-x86_64-efi
    base-system
    linux-firmware
    intel-ucode
    at-spi2-core
    qemu-ga
    open-vm-tools
    spice-vdagent
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
    bluez
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
    xf86-video-intel
    orca
"

XLIBRE="
    xlibre
    xmirror
    libva-intel-driver
    intel-media-driver
    xlibre-xf86-video-amdgpu
    xlibre-xf86-video-intel
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
    firefox
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
#XFCE DESKTOP
XFCE="
    xfce4
    xfce4-whiskermenu-plugin
    gnome-themes-standard
    xfce4-pulseaudio-plugin
    xfce4-screenshooter
    atril
    gvfs-afc
    gvfs-mtp
    firefox
    gvfs-smb
    udisks2
    lightdm
    lightdm-webkit2-greeter
    lightdm-gtk-greeter-settings
    libnotify
    numlockx
    picom
"
LXQT="
    kate
    discover
    lxqt
    xfwm4
    xfwm4-themes
    lightdm
    lightdm-webkit2-greeter
    lightdm-gtk-greeter-settings
    gvfs-afc
    gvfs-mtp
    gvfs-smb
    udisks2
    firefox
    qt6-virtualkeyboard
    qt6-svg
    qt6-multimedia
    gum
"
LXDE="
    lxde
    lightdm
    lightdm-gtk-greeter
    gvfs-afc
    gvfs-mtp
    gvfs-smb
    udisks2
    firefox
"
KDE="
    kde-plasma
    konsole
    kate
    firefox
    dolphin
    discover
    gvfs-afc
    gvfs-mtp
    gvfs-smb
    sddm
    plasma-framework
    kdeconnect
    kdegraphics-thumbnailers
    kde-baseapps
    qt6-virtualkeyboard
    qt6-svg
    qt6-multimedia
    gum
"
CINNAMON="
    cinnamon
    gvfs-afc
    gvfs-mtp
    gvfs-smb
    lightdm
    colord
    gnome-terminal
"


# ─────────────────────────────────────────────
# Aplicaciones de escritorio
# ─────────────────────────────────────────────
DESKTOP_APPS="
    ristretto
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
MATE=${MATE_DESKTOP}

# ─────────────────────────────────────────────
# Construir la lista completa de paquetes
# ─────────────────────────────────────────────
XORG_PACKAGES="
    ${REPOS_PKGS}
    ${BASE_SYSTEM}
    ${SYSTEM_UTILS}
    ${NETWORKING}
    ${AUDIO}
    ${XORG}
    ${GPU_DRIVERS}
    ${DESKTOP_APPS}
    ${MATE}
    ${FLATPAK}
    ${FONTS}
    ${MULTIMEDIA}
    ${GAMING}
    ${OTHER}
    ${ACCESSIBILITY}
    ${NVIDIA}
"

KDE_PACKAGES="
    ${REPOS_PKGS}
    ${BASE_SYSTEM}
    ${SYSTEM_UTILS}
    ${NETWORKING}
    ${AUDIO}
    ${XORG}
    ${GPU_DRIVERS}
    ${DESKTOP_APPS}
    ${KDE}
    ${FLATPAK}
    ${FONTS}
    ${MULTIMEDIA}
    ${GAMING}
    ${OTHER}
    ${ACCESSIBILITY}
    ${NVIDIA}
"

XLIBRE_PACKAGES="
    ${REPOS_PKGS}
    ${BASE_SYSTEM}
    ${SYSTEM_UTILS}
    ${NETWORKING}
    ${AUDIO}
    ${XLIBRE}
    ${GPU_DRIVERS}
    ${DESKTOP_APPS}
    ${MATE}
    ${FLATPAK}
    ${FONTS}
    ${MULTIMEDIA}
    ${GAMING}
    ${OTHER}
    ${ACCESSIBILITY}
    ${NVIDIA}
"

LXQT_PACKAGES="
    ${REPOS_PKGS}
    ${BASE_SYSTEM}
    ${SYSTEM_UTILS}
    ${NETWORKING}
    ${AUDIO}
    ${XORG}
    ${GPU_DRIVERS}
    ${DESKTOP_APPS}
    ${LXQT}
    ${FLATPAK}
    ${FONTS}
    ${MULTIMEDIA}
    ${GAMING}
    ${OTHER}
    ${ACCESSIBILITY}
    ${NVIDIA}
"

XFCE_PACKAGES="
    ${REPOS_PKGS}
    ${BASE_SYSTEM}
    ${SYSTEM_UTILS}
    ${NETWORKING}
    ${AUDIO}
    ${XORG}
    ${GPU_DRIVERS}
    ${DESKTOP_APPS}
    ${XFCE}
    ${FLATPAK}
    ${FONTS}
    ${MULTIMEDIA}
    ${GAMING}
    ${OTHER}
    ${ACCESSIBILITY}
    ${NVIDIA}
"


# Limpiar espacios extra y newlines, convertir a una línea
PACKAGES_XORG=$(echo ${XORG_PACKAGES} | tr -s ' ')
PACKAGES_XLIBRE=$(echo ${XLIBRE_PACKAGES} | tr -s ' ')
PACKAGES_KDE=$(echo ${KDE_PACKAGES} | tr -s ' ')
PACKAGES_LXQT=$(echo ${LXQT_PACKAGES} | tr -s ' ')
PACKAGES_XFCE=$(echo ${XFCE_PACKAGES} | tr -s ' ')
