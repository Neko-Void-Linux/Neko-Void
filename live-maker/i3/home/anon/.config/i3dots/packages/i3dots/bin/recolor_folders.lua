#!/usr/bin/env lua

-- Resolver directorio del script para require() relativo
local script_path = debug.getinfo(1).source:match("@(.*)")
if script_path then
    local h = io.popen("readlink -f " .. script_path .. " 2>/dev/null")
    if h then
        local real = h:read("*a"):gsub("%s+$", ""); h:close()
        local dir  = real:match("(.*)/")
        if dir then package.path = dir .. "/?.lua;" .. package.path end
    end
end

local common = require("common")
local gtk    = require("gtk")
local qt     = require("qt")

-- ── Helpers locales (no son utilidades genéricas) ─────────────────────────────

local function read_ini_value(settings_ini, key)
    local s = common.read_file(settings_ini)
    if not s then return nil end
    for line in s:gmatch("[^\n]+") do
        local val = line:match("^" .. key .. "%s*=%s*(.*)")
        if val then return val:gsub('^"', ''):gsub('"$', ''):gsub("%s+$", "") end
    end
    return nil
end

local function get_current_icon_theme(settings_ini)
    return read_ini_value(settings_ini, "gtk%-icon%-theme%-name") or ""
end

local function get_widget_base(settings_ini)
    local v = read_ini_value(settings_ini, "gtk%-theme%-name") or "adw-gtk3-dark"
    return v:gsub("%-Custom%-[AB]$", ""):gsub("%-Custom$", "")
end

local function link_icon_subdirs(backup_dir, ram_dir, disk_dir)
    local cmds = {
        'for path in "' .. backup_dir .. '"/*; do',
        '    if [ -d "$path" ]; then',
        '        name="${path##*/}"',
        '        if [ "$name" != "Papirus-Dark-Custom-backup" ]; then',
        '            ln -sfn "' .. ram_dir .. '/$name" "' .. disk_dir .. '/$name"',
        '        fi',
        '    fi',
        'done'
    }
    common.sh_batch(cmds)
end

-- Recolorea o enlaza todos los SVGs simbólicos de un directorio fuente al destino.
-- src_abs: path absoluto de la carpeta con los *-symbolic.svg
-- dst_abs: path absoluto del directorio destino (se crea si no existe)
-- sym_sed: tabla de expresiones { patron, reemplazo } o nil para enlace simbólico
-- Recolorea todos los *-symbolic.svg de src_dirs en sus dst_dirs correspondientes.
-- src_dirs: lista de {src_abs, dst_abs}
-- sym_sed: tabla de { patron, reemplazo }
local function recolor_symbolic_dirs_batch(src_dst_pairs, sym_sed, ln_cmds)
    if not src_dst_pairs or #src_dst_pairs == 0 then return end

    -- Construir paths de búsqueda (solo los que existen)
    local valid_pairs = {}
    local search_paths = {}
    for _, pair in ipairs(src_dst_pairs) do
        if common.path_exists(pair[1]) then
            table.insert(valid_pairs, pair)
            table.insert(search_paths, pair[1])
        end
    end
    if #search_paths == 0 then return end

    -- Un solo find para todos los directorios fuente
    local cmd = "find " .. table.concat(search_paths, " ") ..
                " -maxdepth 1 -type f -name '*-symbolic.svg' 2>/dev/null"
    local p = io.popen(cmd)
    if not p then return end

    -- Preparar mkdir en batch
    local mkdirs = {}
    for _, pair in ipairs(valid_pairs) do
        mkdirs[pair[1]] = pair[2]
    end

    local writes = {}  -- { dst, content }
    for path in p:lines() do
        -- Determinar dst_abs del par correspondiente
        local src_dir = path:match("^(.*)/[^/]+$")
        local dst_abs = mkdirs[src_dir]
        if dst_abs then
            local file = path:match("([^/]+)$")
            local name = file:match("^(.+)-symbolic%.svg$")
            if name then
                local dst = dst_abs .. "/" .. name .. ".svg"
                if sym_sed then
                    local s = common.read_file(path)
                    if s then
                        for _, expr in ipairs(sym_sed) do s = s:gsub(expr[1], expr[2]) end
                        table.insert(writes, { dst, s })
                    end
                else
                    if not common.path_exists(dst) then
                        table.insert(ln_cmds, "ln -sfn " .. path .. " " .. dst)
                    end
                end
            end
        end
    end
    p:close()

    -- mkdir batch único para todos los dst_abs necesarios
    local mkdir_list = {}
    for _, pair in ipairs(valid_pairs) do
        table.insert(mkdir_list, pair[2])
    end
    if #mkdir_list > 0 then
        os.execute("mkdir -p " .. table.concat(mkdir_list, " "))
    end

    -- Escribir todos los SVGs recoloreados
    for _, w in ipairs(writes) do
        common.write_file(w[1], w[2])
    end
end


local function link_symbolic_icons(original_dir, ram_dir, disk_dir, sym_sed)
    -- Enlazar directorios 'symbolic' del original al ram_dir (batch: un solo os.execute)
    local p = io.popen("find " .. original_dir .. " -maxdepth 2 \\( -type d -o -type l \\) -name 'symbolic' 2>/dev/null")
    local sym_link_cmds = {}
    if p then
        for path in p:lines() do
            local rel = path:sub(#original_dir + 2)
            local dst = ram_dir .. "/" .. rel
            if not common.path_exists(dst) then
                table.insert(sym_link_cmds, "mkdir -p " .. (dst:match("^(.*)/") or "") .. " && ln -sfn " .. path .. " " .. dst)
            end
        end
        p:close()
    end
    if #sym_link_cmds > 0 then
        os.execute(table.concat(sym_link_cmds, " && "))
    end

    local function ensure_disk_link(subdir)
        if not common.path_exists(disk_dir .. "/" .. subdir) and common.path_exists(ram_dir .. "/" .. subdir) then
            os.execute("ln -sfn " .. ram_dir .. "/" .. subdir .. " " .. disk_dir .. "/" .. subdir)
        end
    end

    local pi_sz = { "16x16", "22x22", "24x24" }
    local cd_sz = { "16", "22", "24" }
    local ln_cmds = {}

    -- Papirus: symbolic/places, symbolic/categories, symbolic/devices, symbolic/apps (batch: 1 find para todos)
    local pi_pairs = {}
    for _, s in ipairs(pi_sz) do
        local base = ram_dir .. "/" .. s
        table.insert(pi_pairs, { base .. "/symbolic/places",     base .. "/places"     })
        table.insert(pi_pairs, { base .. "/symbolic/categories", base .. "/categories" })
        table.insert(pi_pairs, { base .. "/symbolic/devices",    base .. "/devices"    })
        table.insert(pi_pairs, { base .. "/symbolic/apps",       base .. "/apps"       })
        ensure_disk_link(s)
    end
    recolor_symbolic_dirs_batch(pi_pairs, sym_sed, ln_cmds)

    -- Colloid: places/symbolic, devices/symbolic, categories/symbolic, apps/symbolic (batch: 1 find para todos)
    local cd_pairs = {}
    for _, s in ipairs(cd_sz) do
        table.insert(cd_pairs, { ram_dir .. "/places/symbolic",     ram_dir .. "/places/" .. s     })
        table.insert(cd_pairs, { ram_dir .. "/devices/symbolic",    ram_dir .. "/devices/" .. s    })
        table.insert(cd_pairs, { ram_dir .. "/categories/symbolic", ram_dir .. "/categories/" .. s })
        table.insert(cd_pairs, { ram_dir .. "/apps/symbolic",       ram_dir .. "/apps/" .. s       })
        table.insert(cd_pairs, { original_dir .. "/categories/" .. s, ram_dir .. "/categories/" .. s })
    end
    recolor_symbolic_dirs_batch(cd_pairs, sym_sed, ln_cmds)

    if #ln_cmds > 0 then
        os.execute(table.concat(ln_cmds, " && "))
    end

    -- Aliases: nombres de icono que algunos gestores usan pero Papirus no provee
    local icon_aliases = {
        { "applications-accessories", "applications-utilities" },
        { "preferences-desktop",      "preferences-system" },
    }
    local alias_cmds = {}
    for _, s in ipairs(pi_sz) do
        for _, alias in ipairs(icon_aliases) do
            local src = ram_dir .. "/" .. s .. "/categories/" .. alias[2] .. ".svg"
            local dst = ram_dir .. "/" .. s .. "/categories/" .. alias[1] .. ".svg"
            if common.path_exists(src) and not common.path_exists(dst) then
                table.insert(alias_cmds, "ln -sfn " .. src .. " " .. dst)
            end
        end
    end
    if #alias_cmds > 0 then
        os.execute(table.concat(alias_cmds, " && "))
    end
end

-- ── Main ──────────────────────────────────────────────────────────────────────

local function main()
    local persist_file  = common.home .. "/.config/i3/last_icon_color"
    local settings_ini  = common.home .. "/.config/gtk-3.0/settings.ini"
    local base_file     = common.home .. "/.config/i3/icon_theme.base"
    local xsettings_cfg = common.home .. "/.config/xsettingsd/xsettingsd.conf"

    local prev_color = common.read_prev_color(persist_file)
    local color      = common.resolve_color(arg[1], persist_file)

    local base_theme   = common.detect_base_theme(settings_ini, base_file)
    local original_dir = common.find_theme_dir(base_theme)
    if not original_dir then
        common.cleanup_old_themes("", "")
        os.exit(0)
    end

    -- Early exit: mismo color ya aplicado en RAM
    local active_variant    = common.detect_active_variant(xsettings_cfg)
    local active_icon_theme = base_theme .. "-Custom-" .. active_variant
    if color == prev_color
        and common.is_ram_populated("/dev/shm/" .. active_icon_theme)
        and get_current_icon_theme(settings_ini) == active_icon_theme
    then
        gtk.apply(nil, nil)
        os.exit(0)
    end

    local theme_mod = common.load_theme_module(base_theme)
    if not theme_mod then
        common.cleanup_old_themes("", "")
        gtk.apply(base_theme, "adw-gtk3-dark")
        qt.apply(base_theme)
        os.exit(0)
    end

    local target_variant      = (active_variant == "A") and "B" or "A"
    local widget_base         = get_widget_base(settings_ini)
    local custom_icon_theme   = base_theme  .. "-Custom-" .. target_variant
    local custom_widget_theme = widget_base .. "-Custom-" .. target_variant
    local ram_icon_dir        = "/dev/shm/" .. custom_icon_theme
    local backup_dir          = "/dev/shm/" .. base_theme .. "-Custom-backup"
    local physical_icon_dir   = common.home .. "/.icons/" .. custom_icon_theme

    -- ── FASE 1: widget theme y señal Qt inmediatos ───────────────────────────
    common.cleanup_old_themes(custom_icon_theme, custom_widget_theme)
    gtk.setup_theme_variant(widget_base, target_variant)
    gtk.apply(nil, custom_widget_theme)
    qt.apply(custom_icon_theme)

    -- ── FASE 2: backup + recoloreo de SVGs ───────────────────────────────────
    common.check_and_clean_backup(backup_dir, ram_icon_dir, theme_mod.backup_clean_pattern)
    if not common.path_exists(backup_dir) then
        os.execute("mkdir -p " .. backup_dir)
        common.create_backup(original_dir, backup_dir, theme_mod.find_exclusions, theme_mod.color_regex)
    end

    local dark_color = common.hex_darken(color)
    local sed_exprs  = theme_mod.get_sed_expressions(color, dark_color)
    local sym_sed    = theme_mod.get_symbolic_sed_expressions and theme_mod.get_symbolic_sed_expressions(color) or nil

    if not common.is_ram_populated(ram_icon_dir) or not common.path_exists(physical_icon_dir .. "/index.theme") then
        os.execute("rm -rf " .. ram_icon_dir .. " " .. physical_icon_dir)
        os.execute("mkdir -p " .. ram_icon_dir .. " " .. physical_icon_dir)
        common.setup_index_theme(original_dir .. "/index.theme",
            physical_icon_dir .. "/index.theme", custom_icon_theme, base_theme)
        link_icon_subdirs(backup_dir, ram_icon_dir, physical_icon_dir)

        -- Clonación rápida (1.8ms) de la estructura de enlaces a la otra variante
        local other_variant  = (target_variant == "A") and "B" or "A"
        local other_ram_dir  = "/dev/shm/" .. base_theme .. "-Custom-" .. other_variant
        local other_phys_dir = common.home .. "/.icons/" .. base_theme .. "-Custom-" .. other_variant
        if not common.path_exists(other_ram_dir) then
            os.execute("cp -rd " .. ram_icon_dir .. " " .. other_ram_dir .. " 2>/dev/null")
            os.execute("mkdir -p " .. common.home .. "/.icons && ln -sfn " .. other_ram_dir .. " " .. other_phys_dir .. " 2>/dev/null")
        end
    end

    -- Recolorear carpetas en RAM (cp backup + parallel sed con xargs -P$(nproc))
    common.copy_and_recolor(backup_dir, ram_icon_dir, sed_exprs)

    -- Actualizar glifos simbólicos de lugares y carpetas en RAM
    link_symbolic_icons(original_dir, ram_icon_dir, physical_icon_dir, sym_sed)

    -- ── FASE 3: señalizar iconos GTK (primero), luego cache en background ────────────────────────
    gtk.apply(custom_icon_theme, nil)
    common.update_icon_cache(physical_icon_dir) -- no bloqueante (&)
end

main()
