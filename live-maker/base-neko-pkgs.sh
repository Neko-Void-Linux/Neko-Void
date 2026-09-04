#!/bin/bash
REPOS_PKGS="void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree"

# ─────────────────────────────────────────────
# Sistema base y utilidades
# ─────────────────────────────────────────────
BASE_SYSTEM="
    base-system
    linux-firmware-amd
    linux-firmware-nvidia
    linux-firmware-intel
    linux-mainline-headers
    dkms
	ntfs-3g
    dnsmasq
    kasha-installer
    iptables
    tlp
    tlp-pd
    tlp-rdw
    intel-ucode
    at-spi2-core
    yad
    git
    inetutils
    qemu-ga
    upower
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
    xmirror
"
MUSL_SYSTEM="
    base-system
    linux-firmware-amd
    linux-firmware-intel
    linux-mainline-headers
    linux-lts-headers
    dkms
    dnsmasq
    iptables
    tlp
    tlp-pd
    tlp-rdw
    intel-ucode
    at-spi2-core
    yad
    git
    inetutils
    qemu-ga
    upower
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
    kasha-installer
    neko-icons
    neko-themes
    neko-backgrounds
    Neko-Wizard
    xsetroot
    xinit
    xtools
    tmux
    xmirror
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
    libva-intel-driver-irql
    intel-media-driver
    orca
"

XLIBRE="
    xlibre
    xmirror
    libva-intel-driver-irql
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
	xf86-video-nouveau
"


# ─────────────────────────────────────────────
# Escritorio MATE
# ─────────────────────────────────────────────
MATE_DESKTOP="
    engrampa
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
    nwg-look
"
#XFCE DESKTOP
XFCE2="
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
    mpv
    lxqt
    xfwm4
    nwg-look
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
    xdg-desktop-portal-gtk
    xdg-desktop-portal
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
    raven-polkit
    pulseaudio-utils
    setxkbmap
    brightnessctl
    playerctl
    maim
    xclip
    xdotool
    pcmanfm
    dmenu
    ark
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
    firefox
    adw-gtk3
    matugen
    papirus-icon-theme
    lua53
    xsettingsd
    dash
    ffmpegthumbnailer
    socat
    xwinwrap-nk
    neko-icons
    dunst
"

ICEJWM="
    ristretto
    xarchiver
    arandr
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
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    mate-polkit
    xfce4-screenshooter
"

KDE="
    kde-plasma
    konsole
    kate
    firefox
    dolphin
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
	qt6-wayland-client
	qt6-wayland
    ristretto
    noctalia
    xarchiver
	emptty
	wofi
	gvfs-afc
    gvfs-mtp
    gvfs-smb
	wlr-randr
	xwayland-satellite
	swaylock
	labwc
	labwc-menu-generator
	labwc-tweaks-qt
	foot
	kanshi
	xdg-desktop-portal
	xdg-desktop-portal-wlr
	playerctl
	nwg-look
	gtk-update-icon-cache
	wl-clipboard
	wlopm
	mpv
	ristretto
	geany
	grim
	slurp
	gtksourceview
	json-c
	yad
	waterfox
	gtk-layer-shell
	gtkmm
	pcmanfm
    wlr-randr
    wdisplays
"

NIRI="
    qt6-wayland-client
    ristretto
    xarchiver
	gvfs-afc
    gvfs-mtp
    gvfs-smb
    wlr-randr
    wdisplays
    caja
    wofi
    xwayland-satellite
	emptty
	niri
	noctalia
	foot
	xdg-desktop-portal
	xdg-desktop-portal-wlr
	xdg-desktop-portal-gnome
	wl-clipboard
	mako
	wlsunset
	nwg-look
	gtk-update-icon-cache
	wl-clipboard
	wlopm
	mpv
	ristretto
	geany
	grim
	slurp
	gtksourceview
	json-c
	yad
	waterfox
	gtk-layer-shell
	gtkmm
"

# ─────────────────────────────────────────────
# Aplicaciones de escritorio
# ─────────────────────────────────────────────
DESKTOP_APPS="
    gparted
    iruka-xbps
    Neko-Kernel-Manager
"

ANOTHER="
    flatpak
    xdg-desktop-portal
    xdg-desktop-portal-gtk
"

# ─────────────────────────────────────────────
# Fuentes
# ─────────────────────────────────────────────
FONTS="
    noto-fonts-emoji
    noto-fonts-cjk
    noto-fonts-ttf
    font-JetBrainsMono
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
    SDL2-32bit
    SDL2
    libGL-32bit
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
    ${ANOTHER}
    ${FONTS}
    ${MULTIMEDIA}
    ${GAMING}
    ${OTHER}
    ${ACCESSIBILITY}
    ${NVIDIA}
"

MUSL="
    ${MUSL_SYSTEM}
    ${SYSTEM_UTILS}
    ${NETWORKING}
    ${AUDIO}
    ${XORG}
    ${GPU_DRIVERS}
    ${DESKTOP_APPS}
    ${ANOTHER}
    ${FONTS}
    ${MULTIMEDIA}
    ${GAMING}
    ${OTHER}
    ${ACCESSIBILITY}
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
    ${ANOTHER}
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

MUSL_PACKAGES="
    ${MUSL}
    ${XFCE2}
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
NIRI_PACKAGES="
    ${DEFAULT}
    ${NIRI}
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
PACKAGES_NIRI=$(echo ${NIRI_PACKAGES} | tr -s ' ')
PACKAGES_MUSL=$(echo ${MUSL_PACKAGES} | tr -s ' ')
