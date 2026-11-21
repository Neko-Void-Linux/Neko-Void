#!/bin/bash
# postsetup-nvidia.sh
#
# Installs the custom NVIDIA Open Kernel driver (64/32-bit) inside the
# mklive chroot and applies the Neko-Void live ISO kernel/initramfs tweaks.
# Used with: mklive.sh -x ./postsetup-nvidia.sh  (receives ROOTFS as $1)

set -eu

ROOTFS="$1"
[ -n "$ROOTFS" ] || { echo "ROOTFS argument missing" >&2; exit 1; }
[ -d "$ROOTFS" ] || { echo "ROOTFS directory not found: $ROOTFS" >&2; exit 1; }

# DNS inside the chroot
if [ -f /etc/resolv.conf ]; then
    cp -L /etc/resolv.conf "$ROOTFS"/etc/resolv.conf
else
    printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$ROOTFS"/etc/resolv.conf
fi

echo "[neko-postsetup] installing nvidia-open-620 (64/32-bit + firmware + prime-run) in chroot ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    xbps-install -Sy nvidia-open-620 || { echo "[neko-postsetup] ERROR: failed to install nvidia-open-620" >&2; exit 1; }

echo "[neko-postsetup] configuring live ISO early module loading (dracut/modules-load) ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    bash -c '
        set -u
        mkdir -p /etc/dracut.conf.d /etc/modules-load.d

        cat <<"EOF" > /etc/dracut.conf.d/nvidia-live.conf
# Incluir los módulos esenciales de NVIDIA en el initramfs de la ISO Live
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
EOF
        chmod 644 /etc/dracut.conf.d/nvidia-live.conf

        # Forzar carga temprana de nvidia y nvidia-drm al inicio
        printf "nvidia\nnvidia-drm\n" > /etc/modules-load.d/nvidia.conf
    '

echo "[neko-postsetup] adding NVIDIA kernel command line options to GRUB ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    bash -c '
        set -u
        NVIDIA_CMDLINE="nvidia_drm.modeset=1 nvidia_drm.fbdev=1 rd.driver.blacklist=nouveau,nova_core,nova_drm modprobe.blacklist=nouveau,nova_core,nova_drm"

        if [ ! -f /etc/default/grub ]; then
            echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$NVIDIA_CMDLINE\"" > /etc/default/grub
        else
            sed -i "s/\bnvidia_drm\.modeset=[^ ]*//g" /etc/default/grub
            sed -i "s/\bnvidia_drm\.fbdev=[^ ]*//g" /etc/default/grub
            sed -i "s/\brd\.driver\.blacklist=[^ ]*//g" /etc/default/grub
            sed -i "s/\bmodprobe\.blacklist=[^ ]*//g" /etc/default/grub

            if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub; then
                sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $NVIDIA_CMDLINE\"/" /etc/default/grub
            else
                echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$NVIDIA_CMDLINE\"" >> /etc/default/grub
            fi
        fi

        if command -v grub-mkconfig >/dev/null 2>&1; then
            mkdir -p /boot/grub
            grub-mkconfig -o /boot/grub/grub.cfg || echo "[neko-postsetup] WARN: grub-mkconfig failed" >&2
        fi
    '

echo "[neko-postsetup] verifying DKMS build and regenerating initramfs in chroot ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    bash -c '
        set -e
        for kdir in /lib/modules/*; do
            kver="$(basename "$kdir")"
            if [ -e "$kdir/build/Kbuild" ] || [ -e "$kdir/build/Makefile" ]; then
                dkms build -m nvidia -v 620.73.04 -k "$kver" || true
                dkms install -m nvidia -v 620.73.04 -k "$kver" || true
                depmod -a "$kver"
                dracut --force "/boot/initramfs-${kver}.img" "$kver"
            fi
        done
    ' || { echo "[neko-postsetup] ERROR: DKMS/initramfs build failed in chroot" >&2; exit 1; }

echo "[neko-postsetup] cleaning extra kernels and DKMS build artifacts..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    bash -c '
        # Obtener la versión exacta del kernel principal instalado en el chroot
        KEEP_KVER=$(ls -1 /boot/vmlinuz-* 2>/dev/null | sed "s|/boot/vmlinuz-||" | sort -V | tail -n 1)

        if [ -n "$KEEP_KVER" ]; then
            for kver in $(ls -1 /boot/vmlinuz-* 2>/dev/null | sed "s|/boot/vmlinuz-||"); do
                if [ "$kver" != "$KEEP_KVER" ]; then
                    echo "Removing older/extra kernel: $kver"
                    rm -rf "/boot/vmlinuz-${kver}" "/boot/initramfs-${kver}.img" "/boot/System.map-${kver}" "/boot/config-${kver}" "/lib/modules/${kver}"
                fi
            done
        fi

        # Limpiar archivos temporales de compilación de DKMS (los .ko ya están en /lib/modules)
        rm -rf /var/lib/dkms/nvidia/*/build
    '

echo "[neko-postsetup] cleaning up xbps cache to reduce ISO size ..."
chroot "$ROOTFS" env -i HOME=/root TERM="$TERM" \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    xbps-remove -Oy || true

echo "[neko-postsetup] NVIDIA 620.73.04 postsetup finished."
