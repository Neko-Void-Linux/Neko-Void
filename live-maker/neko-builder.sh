#!/bin/bash
#
# NekoVoid Live ISO Builder - Nonfree Edition
# Genera la ISO con soporte nonfree: Steam, gaming, drivers propietarios, etc.
#

set -e

# ─────────────────────────────────────────────
# Configuración de salida
# ─────────────────────────────────────────────

ISO_TITLE="NekoVoid"

# ─────────────────────────────────────────────
# Repositorios (nonfree + multilib)
# ─────────────────────────────────────────────
. ./base-neko-pkgs.sh
# ─────────────────────────────────────────────
# Driver NVIDIA (descomentar si tienes GPU NVIDIA)
# ─────────────────────────────────────────────
#NVIDIA="nvidia nvidia-libs-32bit"
NVIDIA=""



xorg() {
ISO_NAME="nekovoid-beta-7.4-xorg.iso"
echo "============================================="
echo " NekoVoid Live ISO Builder (Nonfree)"
echo "============================================="
echo ""
echo "ISO de salida: ${ISO_NAME}"
echo "Paquetes totales: $(echo ${PACKAGES_XORG} | wc -w)"
echo ""
sudo ./mklive.sh \
    -I ./includedir \
    -o "${ISO_NAME}" \
    -T "${ISO_TITLE}" \
    -p "${PACKAGES_XORG}" \
    -S "dbus elogind NetworkManager lightdm polkitd rtkit sshd chronyd zramen"
}
rolling() {
ISO_NAME="nekovoid-rolling-xorg.iso"
echo "============================================="
echo " NekoVoid Live ISO Builder (Nonfree)"
echo "============================================="
echo ""
echo "ISO de salida: ${ISO_NAME}"
echo "Paquetes totales: $(echo ${PACKAGES_XORG} | wc -w)"
echo ""
sudo ./mklive.sh \
    -I ./includedir \
    -o "${ISO_NAME}" \
    -T "${ISO_TITLE}" \
    -p "${PACKAGES_XORG}" \
    -v linux-mainline \
    -S "dbus elogind NetworkManager lightdm polkitd rtkit sshd chronyd zramen"
}

kde() {
ISO_NAME="nekovoid-rolling-kde.iso"
echo "============================================="
echo " NekoVoid Live ISO Builder (Nonfree)"
echo "============================================="
echo ""
echo "ISO de salida: ${ISO_NAME}"
echo "Paquetes totales: $(echo ${PACKAGES_XORG} | wc -w)"
echo ""
sudo ./mklive.sh \
    -I ./kdedir \
    -o "${ISO_NAME}" \
    -T "${ISO_TITLE}" \
    -p "${PACKAGES_KDE}" \
    -v linux-mainline \
    -S "dbus elogind NetworkManager sddm polkitd rtkit sshd chronyd zramen"
}

lxqt() {
ISO_NAME="nekovoid-rolling-lxqt.iso"
echo "============================================="
echo " NekoVoid Live ISO Builder (Nonfree)"
echo "============================================="
echo ""
echo "ISO de salida: ${ISO_NAME}"
echo "Paquetes totales: $(echo ${PACKAGES_XORG} | wc -w)"
echo ""
sudo ./mklive.sh \
    -I ./lxqt \
    -o "${ISO_NAME}" \
    -T "${ISO_TITLE}" \
    -p "${PACKAGES_LXQT}" \
    -v linux-mainline \
    -S "dbus elogind NetworkManager lightdm polkitd rtkit sshd chronyd zramen"
}


xfce() {
ISO_NAME="nekovoid-rolling-xfce.iso"
echo "============================================="
echo " NekoVoid Live ISO Builder (Nonfree)"
echo "============================================="
echo ""
echo "ISO de salida: ${ISO_NAME}"
echo "Paquetes totales: $(echo ${PACKAGES_XORG} | wc -w)"
echo ""
sudo ./mklive.sh \
    -I ./xfce \
    -o "${ISO_NAME}" \
    -T "${ISO_TITLE}" \
    -p "${PACKAGES_XFCE}" \
    -v linux-mainline \
    -S "dbus elogind NetworkManager lightdm polkitd rtkit sshd chronyd zramen"
}


xlibre() {
ISO_NAME="nekovoid-beta-7.4-xlibre.iso"
echo "============================================="
echo " NekoVoid Live ISO Builder (Nonfree)"
echo "============================================="
echo ""
echo "ISO de salida: ${ISO_NAME}"
echo "Paquetes totales: $(echo ${PACKAGES_XLIBRE} | wc -w)"
echo ""
sudo ./mklive.sh \
    -I ./includedir \
    -o "${ISO_NAME}" \
    -T "${ISO_TITLE}" \
    -p "${PACKAGES_XLIBRE}" \
    -S "dbus elogind NetworkManager lightdm polkitd rtkit sshd chronyd zramen"
}

rollinglibre() {
ISO_NAME="nekovoid-rolling-xlibre.iso"
echo "============================================="
echo " NekoVoid Live ISO Builder (Nonfree)"
echo "============================================="
echo ""
echo "ISO de salida: ${ISO_NAME}"
echo "Paquetes totales: $(echo ${PACKAGES_XLIBRE} | wc -w)"
echo ""
sudo ./mklive.sh \
    -I ./includedir \
    -o "${ISO_NAME}" \
    -T "${ISO_TITLE}" \
    -p "${PACKAGES_XLIBRE}" \
    -v linux-mainline \
    -S "dbus elogind NetworkManager lightdm polkitd rtkit sshd chronyd zramen"
}


doble-iso(){
xlibre
xorg
}
doble-isor(){
rollinglibre
rolling
}
case "$@" in
    doble) doble-iso;;
    xlibre) xlibre;;
    xorg) xorg;;
    rolling) rolling;;
    rollinglibre) rollinglibre;;
    doble-isor) doble-isor;;
    kde) kde;;
    lxqt) lxqt;;
    xfce) xfce;;
esac
