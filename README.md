![image](https://huggingface.co/arepaconcafe/neko-base/resolve/main/1.png)
# Neko-Void Builder
- Clone repo
```
git clone https://codeberg.org/javiercplus/Neko-Void.git
cd Neko-Void
git submodule update --init --recursive
```
# Normal Build
- Build neko-void iso xorg
``` 
cd live-maker && bash neko-builder.sh xorg
```  
- Build neko-void iso xlibre
``` 
cd live-maker && bash neko-builder.sh xlibre
``` 

# for rollings with lastest kernel
- Build neko-void iso xorg
``` 
cd live-maker && bash neko-builder.sh rolling
```  
- Build neko-void iso xlibre
``` 
cd live-maker && bash neko-builder.sh rollibre
``` 
# HOW TO USE NEKO BUILDER (neko-builder.sh)
``` 
# NekoVoid Live ISO Builder - Nonfree Edition
# This here builds the ISO with nonfree support: Steam, gaming, proprietary drivers, and such.
#
# How to use:
#   ./neko-builder.sh                        # Interactive mode
#   ./neko-builder.sh <desktop>              # Build a specific desktop
#   ./neko-builder.sh <desktop> -e "pkg..."  # With extra packages
#   ./neko-builder.sh doble                  # Build xlibre + xorg
#   ./neko-builder.sh doble-isor             # Build rollibre + rolling
``` 

This repo also has repo of neko wizard and kasha installer module!

Repo Builder: https://github.com/javiercplus/repo-neko

custom kernels: https://github.com/javiercplus/kernel-neko-void/actions

webpage sourcecode: https://github.com/javiercplus/nk-web
