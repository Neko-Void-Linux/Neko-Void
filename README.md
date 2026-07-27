# Neko-Void ISO Builder

![image](https://huggingface.co/arepaconcafe/neko-base/resolve/main/1.png)

This repository allows you to build custom Live ISO images for Neko-Void Linux. The build process includes support for non-free software, proprietary drivers, Steam, and gaming-related packages.

## Cloning the Repository

First, clone this repository and its submodules. This repository includes the source code for the Neko Wizard and the Kasha installer module.

```bash
git clone https://codeberg.org/javiercplus/Neko-Void.git Neko-Void
cd Neko-Void
git submodule update --init --recursive

```
## Build Instructions
To build a Neko-Void ISO, you need to use the neko-builder.sh script located in the live-maker directory. First, change to that directory:
```bash
cd live-maker

```
Then, execute the builder script with your desired configuration:
### Standard Builds
 * **Build Xorg ISO:**
   ```bash
   bash neko-builder.sh xorg
   
   ```
 * **Build Xlibre ISO:**
   ```bash
   bash neko-builder.sh xlibre
   
   ```
### Rolling Builds (Latest Kernel)
 * **Build Xorg Rolling ISO:**
   ```bash
   bash neko-builder.sh rolling
   
   ```
 * **Build Xlibre Rolling ISO:**
   ```bash
   bash neko-builder.sh rollibre
   
   ```
## neko-builder.sh Usage Details
The build script supports multiple options. For example:
 * ./neko-builder.sh - Runs in interactive mode.
 * ./neko-builder.sh <desktop> - Builds a specific desktop environment (e.g., xorg, rolling).
 * ./neko-builder.sh <desktop> -e "pkg..." - Builds with extra specified packages.
 * ./neko-builder.sh doble - Builds both Xlibre and Xorg ISOs.
 * ./neko-builder.sh doble-isor - Builds both Rollibre and Rolling ISOs.
## Related Projects and Resources
You can find more information about the Neko ecosystem at these locations:
 * **Repo Builder:** https://github.com/javiercplus/repo-neko
 * **Custom Kernels (Actions):** https://github.com/javiercplus/kernel-neko-void/actions
 * **Website Source Code:** https://github.com/javiercplus/nk-web
