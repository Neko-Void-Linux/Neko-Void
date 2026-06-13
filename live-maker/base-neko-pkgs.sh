#!/bin/bash
REPOS_PKGS="void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree"

# ─────────────────────────────────────────────
# Sistema base y utilidades
# ─────────────────────────────────────────────
BASE_SYSTEM="
    base-system
    linux-firmware
    tlp
    intel-ucode
    at-spi2-core
    kyoz
    yad
    qemu-ga
    open-vm-tools
    spice-vdagent
    elogind
    bash-completion
    cryptsetup
    dbus
    dialog
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
    linux-firmware-nvidia
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
    mpv
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
"
LXQT="
    kate
    discover
    mpv
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
    mpv
    firefox
"

I3="
    i3
    lightdm
    lightdm-gtk-greeter
    polybar
    rofi
    kitty
    geany
    picom
    qt6ct
    lxappearance
    feh
    mpv
    dex
    polkit-gnome 
    pulseaudio-utils
    setxkbmap
    brightnessctl
    playerctl
    maim
    xclip
    xdotool
    nemo
    dmenu
    git
    ark
    curl
    wget
    unzip
    cargo
    pkg-config
    openssl
    libxcb
    xcb-util
    xcb-util-image
    xcb-util-keysyms
    xcb-util-renderutil
    xcb-util-wm
    libxkbcommon
    font-awesome6
    fontconfig
    ImageMagick
    gvfs-afc
    gvfs-mtp
    gvfs-smb
    udisks2
    firefox
"

ICEJWM="
    jwm
    jwmkit-neko
    icewm
    mpv
    pcmanfm
    alacritty
    ristretto
    lxappearance
    atril
    lightdm
    lightdm-gtk-greeter
    gvfs-afc
    gvfs-mtp
    gvfs-smb
    udisks2
    firefox
    mate-polkit
    xfce4-screenshooter
"

KDE="
    kde-plasma
    konsole
    kate
    tlp-pd
    tlp-rdw
    firefox
    dolphin
    discover
    gvfs-afc
    gvfs-mtp
    gvfs-smb
    mpv
    sddm
    plasma-framework
    kdeconnect
    kdegraphics-thumbnailers
    kde-baseapps
    qt6-virtualkeyboard
    qt6-svg
    qt6-multimedia
    gum
    okular
    spectacle
    gwenview
    ark
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

LABWC="
	lightdm
	gvfs-afc
    gvfs-mtp
    gvfs-smb
	wlr-randr
	mako
	swaylock
	labwc
	alacritty
	kanshi
	nerd-fonts-ttf
	fish-shell
	xdg-desktop-portal
	xdg-desktop-portal-wlr
	playerctl
	rofi
	ristre
	nwg-look
	gtk-update-icon-cache
	wl-clipboard
	wlopm
	mpv
	ristretto
	kate
	grim
	slurp
	gtksourceview
	json-c
	yad
	gtk-layer-shell
	gtkmm
	Thunar
"


# ─────────────────────────────────────────────
# Aplicaciones de escritorio
# ─────────────────────────────────────────────
DESKTOP_APPS="
    ristretto
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
DEFAULT="
    ${REPOS_PKGS}
    ${BASE_SYSTEM}
    ${SYSTEM_UTILS}
    ${NETWORKING}
    ${AUDIO}
    ${XORG}
    ${GPU_DRIVERS}
    ${DESKTOP_APPS}
    ${FLATPAK}
    ${FONTS}
    ${MULTIMEDIA}
    ${GAMING}
    ${OTHER}
    ${ACCESSIBILITY}
    ${NVIDIA}
"

# ─────────────────────────────────────────────
# Construir la lista completa de paquetes
# ─────────────────────────────────────────────
XORG_PACKAGES="
    ${DEFAULT}
    ${MATE}
"

KDE_PACKAGES="
    ${DEFAULT}
    ${KDE}
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
    ${DEFAULT}
    ${LXQT}
"
I3_PACKAGES="
    ${DEFAULT}
    ${I3}
"

XFCE_PACKAGES="
    ${DEFAULT}
    ${XFCE}
"


ICEJWM_PACKAGES="
    ${DEFAULT}
    ${ICEJWM}
"

LXDE_PACKAGES="
    ${DEFAULT}
    ${LXDE}
"

CINNAMON_PACKAGES="
    ${DEFAULT}
    ${CINNAMON}
"
LABWC_PACKAGES="
    ${DEFAULT}
    ${LABWC}
"

# Limpiar espacios extra y newlines, convertir a una línea
PACKAGES_XORG=$(echo ${XORG_PACKAGES} | tr -s ' ')
PACKAGES_XLIBRE=$(echo ${XLIBRE_PACKAGES} | tr -s ' ')
PACKAGES_KDE=$(echo ${KDE_PACKAGES} | tr -s ' ')
PACKAGES_LXQT=$(echo ${LXQT_PACKAGES} | tr -s ' ')
PACKAGES_I3=$(echo ${I3_PACKAGES} | tr -s ' ')
PACKAGES_XFCE=$(echo ${XFCE_PACKAGES} | tr -s ' ')
PACKAGES_ICEJWM=$(echo ${ICEJWM_PACKAGES} | tr -s ' ')
PACKAGES_LXDE=$(echo ${LXDE_PACKAGES} | tr -s ' ')
PACKAGES_CINNAMON=$(echo ${CINNAMON_PACKAGES} | tr -s ' ')
PACKAGES_LABWC=$(echo ${LABWC_PACKAGES} | tr -s ' ')
