#!/bin/bash
# postsetup-nvidia.sh
#
# Installs the NVIDIA 580 driver inside the mklive chroot and applies the
# Neko-Wizard nvidia-config.sh tweaks that matter for a live ISO.
# Used with: mklive.sh -x ./postsetup-nvidia.sh  (receives ROOTFS as $1)

set -eu

ROOTFS="$1"
[ -n "$ROOTFS" ] || { echo "ROOTFS argument missing" >&2; exit 1; }
[ -d "$ROOTFS" ] || { echo "ROOTFS directory not found: $ROOTFS" >&2; exit 1; }

# DNS inside the chroot
if [ -f /etc/resolv.conf ]; then
    cp /etc/resolv.conf "$ROOTFS"/etc/resolv.conf
else
    printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$ROOTFS"/etc/resolv.conf
fi

echo "[neko-postsetup] installing nvidia latest driver packages in chroot ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    xbps-install -Sy nvidia nvidia-libs-32bit || { echo "[neko-postsetup] ERROR: failed to install nvidia" >&2; exit 1; }

echo "[neko-postsetup] applying Neko-Wizard nvidia-config.sh (dracut/modules-load only) ..."
# ATENCIÓN: Esto debe ir ANTES de xbps-reconfigure para que Dracut lo lea.
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    bash -c '
        set -u
        mkdir -p /etc/dracut.conf.d /etc/modules-load.d

        cat <<"EOF" > /etc/dracut.conf.d/nvidia.conf
# Incluir los módulos esenciales de NVIDIA en el initramfs
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
EOF
        chmod 644 /etc/dracut.conf.d/nvidia.conf

        # Forzar carga de nvidia al inicio
        printf "nvidia\n" > /etc/modules-load.d/nvidia.conf

        echo "[neko-postsetup] WARN: grub/kernel_set steps skipped (live ISO handles grub itself)" >&2
    '

echo "[neko-postsetup] running xbps-reconfigure -f -a (builds dkms module and initramfs) ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    xbps-reconfigure -f -a || { echo "[neko-postsetup] ERROR: xbps-reconfigure failed" >&2; exit 1; }

echo "[neko-postsetup] cleaning up xbps cache to reduce ISO size ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    xbps-remove -Oy || true

echo "[neko-postsetup] NVIDIA postsetup finished."
