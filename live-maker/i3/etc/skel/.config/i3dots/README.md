# i3 dots

# Imagenes

<details><summary><h2>Fullscreen</h2></summary>

![](/assets/Screenshot_2026-04-30_17-12-09.jpg)

</details><br>

<details><summary><h2>Rofi Launcher</h2></summary>

![](/assets/Screenshot_2026-04-30_17-12-45.jpg)

</details><br>

<details><summary><h2>Wallpaper Selector</h2></summary>

![](/assets/Screenshot_2026-04-30_17-13-07.jpg)

</details><br>

<details><summary><h2>Rofi Powermenu</h2></summary>

![](/assets/Screenshot_2026-04-30_17-13-40.jpg)

</details><br>

# Instalacion 

```
mkdir screenshots
```

```
git clone --depth 1 https://github.com/Loonyx1/i3dots.git
```

```
cd i3dots
```
### Para install del dotfile en debian y void
```
./dots install i3dots (name distro)
```

# Teclas/Atajos

## Sistema e Interfaz

| Keys | Action |
|:-|:-|
| <kbd>Super</kbd> + <kbd>Return</kbd> | Abrir Terminal (Kitty) |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Cerrar ventana enfocada |
| <kbd>Super</kbd> + <kbd>F</kbd> | Pantalla completa (fullscreen) |
| <kbd>Super</kbd> + <kbd>D</kbd> | Rofi Launcher |
| <kbd>Super</kbd> + <kbd>X</kbd> | Rofi Run |
| <kbd>Super</kbd> + <kbd>P</kbd> | dmenu_run |
| <kbd>Super</kbd> + <kbd>E</kbd> | Gestor de archivos |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Powermenu |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Alternar enfoque mosaico/flotante |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Space</kbd> | Alternar ventana a flotante |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>C</kbd> | Recargar configuración de i3 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>R</kbd> | Reiniciar i3 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>L</kbd> | Cerrar sesión (logout) |
| <kbd>Super</kbd> (hold) | Arrastrar ventanas flotantes |

## Layouts y Navegación

| Keys | Action |
|:-|:-|
| <kbd>Super</kbd> + <kbd>T</kbd> | División horizontal |
| <kbd>Super</kbd> + <kbd>Y</kbd> | División vertical |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>T</kbd> | Layout con pestañas (tabbed) |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>E</kbd> | Alternar layout (toggle split) |
| <kbd>Super</kbd> + <kbd>R</kbd> | Modo redimensionar (j/k/l/ñ / flechas) |
| <kbd>Super</kbd> + <kbd>B</kbd> | Alternar bordes (ventana enfocada) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>N</kbd> | Alternar bordes (global) |
| <kbd>Super</kbd> + <kbd>↑/↓/←/→</kbd> | Mover enfoque |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>↑/↓/←/→</kbd> | Mover ventana |
| <kbd>Alt</kbd> + <kbd>F1</kbd> / <kbd>F2</kbd> | Enfoque izquierda / derecha |
| <kbd>Alt</kbd> + <kbd>Super</kbd> + <kbd>F1</kbd> / <kbd>F2</kbd> | Mover ventana izquierda / derecha |

## Gestión i3dots

| Keys | Action |
|:-|:-|
| <kbd>Super</kbd> + <kbd>W</kbd> | Selector de wallpapers (Matugen) |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>W</kbd> | Live wallpaper |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Gestionar wallpapers |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>W</kbd> | Wallpapers predefinidos |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd> | Cambiar estilo de barra (Polybar) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>M</kbd> | Opciones de barra (altura, etc.) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>D</kbd> | Administrar pantallas y resolución |
| <kbd>Super</kbd> + <kbd>H</kbd> | Visor de atajos (Cheatsheet) |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>B</kbd> | Alternar auto-ocultar barra |

## Audio y Brillo

| Keys | Action |
|:-|:-|
| <kbd>Super</kbd> + <kbd>F12</kbd> / <kbd>F11</kbd> | Subir / Bajar volumen |
| <kbd>Super</kbd> + <kbd>F10</kbd> | Silenciar / Activar audio |
| Teclas multimedia | Control de volumen y micrófono |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>F12</kbd> / <kbd>F11</kbd> | Subir / Bajar brillo |
| Teclas de brillo | Brillo con teclas multimedia |

## Capturas de Pantalla (al portapapeles)

| Keys | Screenshot |
|:-|:-|
| <kbd>Print</kbd> | Pantalla completa |
| <kbd>Super</kbd> + <kbd>Print</kbd> | Ventana activa |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Selección |

## Capturas de Pantalla (a ~/screenshots/)

| Keys | Screenshot |
|:-|:-|
| <kbd>Ctrl</kbd> + <kbd>Print</kbd> | Pantalla completa |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Print</kbd> | Ventana activa |
| <kbd>Shift</kbd> + <kbd>Print</kbd> | Selección |

## Workspaces

| Keys | Action |
|:-|:-|
| <kbd>Super</kbd> + <kbd>1-0</kbd> / <kbd>A</kbd> | Ir al workspace 1-11 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1-0</kbd> / <kbd>A</kbd> | Mover ventana al workspace 1-11 |

# Live Wallpaper

El motor detecta configuración desde el nombre del archivo:

| Nombre                          | Skip          | FPS  |
|---------------------------------|---------------|------|
| `video.mp4`                     | `nonref`      |  ∞   |
| `video_noskip.mp4`              | `none`        |  ∞   |
| `video_fps30.mp4`               | `nonref`      |  30  |
| `video_noskip_fps60.mp4`        | `none`        |  60  |

- `_noskip` → desactiva el skip de frames. Por defecto mpv salta frames no-referencia (`nonref`) para reducir CPU. Con `_noskip` se renderiza cada frame, mayor calidad pero más consumo.
- `_fps<N>` → limita los FPS (ej. `_fps30`, `_fps60`). Reduce consumo en videos de alta tasa.
- Se pueden combinar: `video_noskip_fps30.mp4`.

### Uso

- **Selector Rofi**: los wallpapers se ponen en `~/wall/live/` y aparecen automáticamente en el menú (<kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>W</kbd>).
- **Gestor de archivos**: botón derecho sobre el archivo → `Wallpaper i3` (se integra solo en Thunar y pcmanfm).
