#! /usr/bin/env bash
 bash neko-builder.sh icewm -e linux-lts-headers &&
 bash neko-builder.sh jwm -e linux-lts-headers &&
 bash neko-builder.sh xfce -e linux-lts-headers &&
 bash neko-builder.sh kde -e linux-mainline-headers &&
 bash neko-builder.sh niri -e linux-mainline-headers &&
 bash neko-builder.sh labwc -e linux-mainline-headers &&
 bash neko-builder.sh i3 -e linux-mainline-headers &&
 bash neko-builder.sh lxqt -e linux-mainline-headers &&
 bash neko-builder.sh mate -e linux-mainline-headers &&
 bash neko-builder.sh matelibre -e linux-mainline-headers &&
 bash neko-builder.sh nvidia -e linux-mainline-headers



