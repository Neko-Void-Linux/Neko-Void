-- packages/i3dots/bin/gtk.lua
-- Responsabilidad: widget theme (symlinks en disco) + escritura de configs GTK/xsettingsd.
local common = require("common")
local gtk    = {}

-- Crea ~/.themes/<base>-Custom-<V>/ como directorio de symlinks al original.
-- Solo index.theme es un archivo real con el nombre correcto.
-- Matugen ya escribe los colores via @import en colors.css; no hay que generar CSS.
function gtk.setup_theme_variant(base_theme, variant)
    local custom_name = base_theme .. "-Custom-" .. variant
    local custom_dir  = common.home .. "/.themes/" .. custom_name

    local base_path = common.home .. "/.themes/" .. base_theme
    if not common.path_exists(base_path) then
        base_path = "/usr/share/themes/" .. base_theme
    end
    if not common.path_exists(base_path) then return false end

    -- Clonar estructura de enlaces simbólicos del tema base
    os.execute("rm -rf " .. custom_dir)
    os.execute("cp -as " .. base_path .. " " .. custom_dir)

    -- Personalizar index.theme (quitar enlace primero)
    local index_path = custom_dir .. "/index.theme"
    local idx = common.read_file(index_path)
    if idx then
        os.remove(index_path)
        idx = idx:gsub("(Name%s*=%s*)[^\n]*",     "%1" .. custom_name)
        idx = idx:gsub("(GtkTheme%s*=%s*)[^\n]*", "%1" .. custom_name)
        common.write_file(index_path, idx)
    end

    -- Leer colores frescos generados por Matugen
    local colors_path = common.home .. "/.config/gtk-3.0/colors.css"
    local colors = common.read_file(colors_path) or ""

    -- Reemplazar archivos CSS en gtk-3.0 y gtk-4.0
    for _, sub in ipairs({"gtk-3.0", "gtk-4.0"}) do
        local dst_sub = custom_dir .. "/" .. sub
        if common.path_exists(dst_sub) then
            os.remove(dst_sub .. "/gtk.css")
            os.remove(dst_sub .. "/gtk-dark.css")

            for _, name in ipairs({"gtk.css", "gtk-dark.css"}) do
                local src_file = base_path .. "/" .. sub .. "/" .. name
                if common.path_exists(src_file) then
                    local content = '@import url("' .. src_file .. '");\n' .. colors
                    common.write_file(dst_sub .. "/" .. name, content)
                end
            end
        end
    end

    return true
end

-- ── Config writers (formato correcto por tipo de archivo) ─────────────────────

local function apply_ini(path, icon_theme, widget_theme)
    local s = common.read_file(path)
    if not s then return end
    -- INI format: gtk-theme-name=Value  (no quotes)
    if icon_theme then
        s = s:gsub("(gtk%-icon%-theme%-name%s*=%s*)([^\n]*)",
            function(key, _) return key .. icon_theme end)
    end
    if widget_theme then
        s = s:gsub("(gtk%-theme%-name%s*=%s*)([^\n]*)",
            function(key, _) return key .. widget_theme end)
    end
    common.write_file(path, s)
end

local function apply_gtkrc(path, icon_theme, widget_theme)
    local s = common.read_file(path)
    if not s then return end
    -- gtkrc-2.0 format: gtk-theme-name="Value"  (with quotes)
    if icon_theme then
        s = s:gsub('(gtk%-icon%-theme%-name=)[^\n]*',
            '%1"' .. icon_theme .. '"')
    end
    if widget_theme then
        s = s:gsub('(gtk%-theme%-name=)[^\n]*',
            '%1"' .. widget_theme .. '"')
    end
    common.write_file(path, s)
end

local function signal_xsettingsd()
    local sh = [[
if pgrep -a -x xsettingsd 2>/dev/null | grep -q "\.config/xsettingsd/xsettingsd\.conf"; then
    pkill -HUP xsettingsd 2>/dev/null || true
else
    pkill -x xsettingsd 2>/dev/null || true
    xsettingsd -c "$HOME/.config/xsettingsd/xsettingsd.conf" >/dev/null 2>&1 &
fi
]]
    os.execute("bash -c " .. string.format("%q", sh))
end

local function apply_xsettingsd(path, icon_theme, widget_theme)
    local s = common.read_file(path)
        or 'Net/ThemeName "adw-gtk3-dark"\nNet/IconThemeName "hicolor"\nGtk/CursorThemeName "Adwaita"\nGtk/FontName "Sans 10"\n'

    if icon_theme then
        if s:find("Net/IconThemeName") then
            s = s:gsub('Net/IconThemeName[^\n]*', 'Net/IconThemeName "' .. icon_theme .. '"')
        else
            s = s .. '\nNet/IconThemeName "' .. icon_theme .. '"\n'
        end
    end
    if widget_theme then
        if s:find("Net/ThemeName") then
            s = s:gsub('Net/ThemeName[^\n]*', 'Net/ThemeName "' .. widget_theme .. '"')
        else
            s = s .. '\nNet/ThemeName "' .. widget_theme .. '"\n'
        end
    end

    common.write_file(path, s)
    signal_xsettingsd()
end

-- ── API pública ───────────────────────────────────────────────────────────────

-- icon_theme y/o widget_theme pueden ser nil para actualizar solo uno.
function gtk.apply(icon_theme, widget_theme)
    local ini3 = common.home .. "/.config/gtk-3.0/settings.ini"
    local ini4 = common.home .. "/.config/gtk-4.0/settings.ini"
    local rc2  = common.home .. "/.gtkrc-2.0"
    local xconf= common.home .. "/.config/xsettingsd/xsettingsd.conf"

    apply_ini(ini3,  icon_theme, widget_theme)
    apply_ini(ini4,  icon_theme, widget_theme)
    apply_gtkrc(rc2, icon_theme, widget_theme)

    -- Vaciar stylesheets de usuario para que no sobrescriban con colores viejos
    common.write_file(common.home .. "/.config/gtk-3.0/gtk.css", "/* Desactivado para recarga en caliente */\n")
    common.write_file(common.home .. "/.config/gtk-4.0/gtk.css", "/* Desactivado para recarga en caliente */\n")

    if icon_theme then
        os.execute('command -v gsettings &>/dev/null && gsettings set org.gnome.desktop.interface icon-theme "'   .. icon_theme   .. '" || true')
    end
    if widget_theme then
        os.execute('command -v gsettings &>/dev/null && gsettings set org.gnome.desktop.interface gtk-theme "' .. widget_theme .. '" || true')
    end

    apply_xsettingsd(xconf, icon_theme, widget_theme)
end

return gtk
