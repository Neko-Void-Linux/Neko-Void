#!/bin/bash
# postsetup-nvidia.sh
#
# Installs the NVIDIA 580 driver inside the mklive chroot and applies the
# Neko-Wizard nvidia-config.sh tweaks that matter for a live ISO.
# Used with: mklive.sh -x ./postsetup-nvidia.sh  (receives ROOTFS as $1)
#
# Why not `curl | bash -s nvidia-580` verbatim:
#   * install.sh wraps the real work in `pkexec`, which cannot work inside a
#     headless build chroot (no polkitd session bus). We run as root already.
#   * nvidia-config.sh only writes config (grub/dracut/modules-load) and its
#     kernel_set()/grub parts die without a fully installed system. mklive
#     generates the live ISO grub itself, so we keep the dracut/modules-load
#     bits and ignore the grub steps.
set -eu

ROOTFS="$1"
[ -n "$ROOTFS" ] || { echo "ROOTFS argument missing" >&2; exit 1; }
[ -d "$ROOTFS" ] || { echo "ROOTFS directory not found: $ROOTFS" >&2; exit 1; }

NVIDIA_CONFIG="https://raw.githubusercontent.com/Neko-Void-Linux/nvidia-support/refs/heads/main/nvidia-config.sh"

# DNS inside the chroot (base-system does not guarantee a resolv.conf).
if [ -f /etc/resolv.conf ]; then
    cp /etc/resolv.conf "$ROOTFS"/etc/resolv.conf
else
    printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$ROOTFS"/etc/resolv.conf
fi

mkdir -p "$ROOTFS"/tmp

echo "[neko-postsetup] installing nvidia580 driver packages in chroot ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    xbps-install -Sy nvidia580 || { echo "[neko-postsetup] ERROR: failed to install nvidia580" >&2; exit 1; }

echo "[neko-postsetup] running xbps-reconfigure -f -a (builds dkms module) ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    xbps-reconfigure -f -a || { echo "[neko-postsetup] ERROR: xbps-reconfigure failed" >&2; exit 1; }

echo "[neko-postsetup] applying Neko-Wizard nvidia-config.sh (dracut/modules-load only) ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    bash -c '
        set -u
        mkdir -p /etc/dracut.conf.d /etc/modules-load.d

        # Keep the useful parts of nvidia-config.sh; skip grub/kernel_set which
        # require an installed system (mklive builds the live grub itself).
        cat <<"EOF" > /etc/dracut.conf.d/nvidia.conf
# Incluir los módulos esenciales de NVIDIA en el initramfs
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
EOF
        chmod 644 /etc/dracut.conf.d/nvidia.conf

        # Forzar carga de nvidia al inicio
        printf "nvidia\n" > /etc/modules-load.d/nvidia.conf

        echo "[neko-postsetup] WARN: grub/kernel_set steps of nvidia-config.sh skipped (live ISO handles grub itself)" >&2
    '

echo "[neko-postsetup] NVIDIA postsetup finished."