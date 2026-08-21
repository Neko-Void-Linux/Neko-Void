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

# DNS inside the chroot (CORREGIDO: usa cp -L para seguir enlaces simbólicos)
if [ -f /etc/resolv.conf ]; then
    cp -L /etc/resolv.conf "$ROOTFS"/etc/resolv.conf
else
    printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$ROOTFS"/etc/resolv.conf
fi

echo "[neko-postsetup] installing nvidia latest driver packages in chroot ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    xbps-install -Sy nvidia nvidia-libs-32bit || { echo "[neko-postsetup] ERROR: failed to install nvidia" >&2; exit 1; }

echo "[neko-postsetup] applying Neko-Wizard nvidia-config.sh (dracut/modules-load only) ..."
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
    '

# ========== SECCIÓN GRUB CORREGIDA (sin duplicados) ==========
echo "[neko-postsetup] adding NVIDIA kernel command line options to GRUB ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    bash -c '
        set -u
        NVIDIA_CMDLINE="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprobe.blacklist=nouveau"

        # Asegurar que existe /etc/default/grub
        if [ ! -f /etc/default/grub ]; then
            echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$NVIDIA_CMDLINE\"" > /etc/default/grub
        else
            # Eliminar parámetros NVIDIA antiguos (usando \b para límite de palabra)
            sed -i "s/\bnvidia_drm\.modeset=[^ ]*//g" /etc/default/grub
            sed -i "s/\brd\.driver\.blacklist=[^ ]*//g" /etc/default/grub
            sed -i "s/\bmodprobe\.blacklist=[^ ]*//g" /etc/default/grub

            # Añadir los nuevos parámetros
            if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub; then
                sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $NVIDIA_CMDLINE\"/" /etc/default/grub
            else
                echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$NVIDIA_CMDLINE\"" >> /etc/default/grub
            fi
        fi

        # Regenerar grub.cfg si grub-mkconfig está disponible
        if command -v grub-mkconfig >/dev/null 2>&1; then
            mkdir -p /boot/grub
            grub-mkconfig -o /boot/grub/grub.cfg || echo "[neko-postsetup] WARN: grub-mkconfig failed" >&2
        else
            echo "[neko-postsetup] INFO: grub-mkconfig not found, skipping GRUB update"
        fi
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
