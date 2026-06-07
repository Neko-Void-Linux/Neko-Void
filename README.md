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

``` 
# NekoVoid Live ISO Builder - Nonfree Edition
# Genera la ISO con soporte nonfree: Steam, gaming, drivers propietarios, etc.
#
# Uso:
#   ./neko-builder.sh                        # Modo interactivo
#   ./neko-builder.sh <desktop>              # Construir escritorio específico
#   ./neko-builder.sh <desktop> -e "pkg..."  # Con paquetes extra
#   ./neko-builder.sh doble                  # Construir xlibre + xorg
#   ./neko-builder.sh doble-isor             # Construir rollibre + rolling
#
``` 

This repo also has repo of neko wizard and kasha installer module!
