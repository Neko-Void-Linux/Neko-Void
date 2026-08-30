-- packages/i3dots/bin/common.lua
local common = {}

common.home = os.getenv("HOME")

-- ── Math ──────────────────────────────────────────────────────────────────────

function common.hex_darken(hex)
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    return string.format("%02x%02x%02x",
        math.floor(r * 0.65),
        math.floor(g * 0.65),
        math.floor(b * 0.65))
end

-- ── I/O ───────────────────────────────────────────────────────────────────────

function common.path_exists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

function common.read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a"); f:close()
    return s
end

function common.write_file(path, content)
    local f = io.open(path, "w")
    if f then f:write(content); f:close() end
end

-- Ejecuta una lista de comandos shell en un SOLO fork de bash.
-- Reemplaza N os.execute separados por 1, eliminando N-1 fork()s.
function common.sh_batch(cmds)
    if not cmds or #cmds == 0 then return end
    local p = io.popen("bash", "w")
    if p then
        p:write("set -e\n")
        p:write(table.concat(cmds, "\n"))
        p:close()
    end
end

-- Itera entradas de un directorio sin fork (Lua nativo vía io.popen con un solo find).
-- Devuelve una tabla de paths absolutos.
function common.dir_list(path, maxdepth, pattern)
    local depth = maxdepth or 1
    local pat   = pattern and (" -name '" .. pattern .. "'") or ""
    local p = io.popen("find " .. path .. " -maxdepth " .. depth .. " -mindepth 1" .. pat .. " 2>/dev/null")
    if not p then return {} end
    local entries = {}
    for line in p:lines() do table.insert(entries, line) end
    p:close()
    return entries
end

-- ── Color persistence ─────────────────────────────────────────────────────────

function common.resolve_color(color_arg, persist_file)
    local color = color_arg or ""
    if color == "" then
        io.stderr:write("Especifica un color hex o --restore\n")
        return nil
    end
    if color == "--restore" then
        local s = common.read_file(persist_file)
        if not s then return nil end
        return s:gsub("%s+", "")
    end
    if not color:match("^[0-9a-fA-F]%x%x%x%x%x$") then
        io.stderr:write("Color hex inválido: " .. color .. "\n")
        return nil
    end
    common.write_file(persist_file, color)
    return color
end

function common.read_prev_color(persist_file)
    local s = common.read_file(persist_file)
    return s and s:gsub("%s+", "") or nil
end

-- ── Theme discovery ───────────────────────────────────────────────────────────

function common.detect_base_theme(settings_ini, base_file)
    local current_theme = ""
    local s = common.read_file(settings_ini)
    if s then
        -- simpler line-by-line
        for line in s:gmatch("[^\n]+") do
            local val = line:match("^gtk%-icon%-theme%-name%s*=%s*(.*)")
            if val then
                val = val:gsub('^"', ''):gsub('"$', ''):gsub("%s+$", "")
                current_theme = val
                break
            end
        end
    end

    if current_theme == "" then current_theme = "Papirus-Dark" end

    if not current_theme:find("%-Custom") then
        common.write_file(base_file, current_theme)
        return current_theme
    end

    local saved = common.read_file(base_file)
    if saved then
        saved = saved:gsub("%s+", "")
        if saved ~= "" then return saved end
    end
    return "Papirus-Dark"
end

function common.find_theme_dir(name)
    for _, base in ipairs({
        common.home .. "/.icons/",
        common.home .. "/.local/share/icons/",
        "/usr/share/icons/",
    }) do
        local path = base .. name
        if common.path_exists(path .. "/index.theme") then
            return path
        end
    end
    return nil
end

function common.load_theme_module(base_theme)
    local full = base_theme:lower()
    local ok, mod = pcall(require, full)
    if ok then return mod end

    local prefix = base_theme:match("^([^-]*)")
    if prefix then
        prefix = prefix:lower()
        if prefix ~= full then
            local ok2, mod2 = pcall(require, prefix)
            if ok2 then return mod2 end
        end
    end
    return nil
end

-- ── Variant detection ─────────────────────────────────────────────────────────

function common.detect_active_variant(xsettings_path)
    local s = common.read_file(xsettings_path)
    if s then
        local val = s:match('Net/ThemeName%s*"([^"]+)"')
        if val then
            if val:find("%-Custom%-A$") then return "A" end
            if val:find("%-Custom%-B$") then return "B" end
        end
    end
    return "B"  -- sin Custom activo → primer arranque → target será A
end

-- ── Theme cleanup ─────────────────────────────────────────────────────────────

-- Elimina variantes Custom inactivas y backups de otros temas.
-- keep_icon_theme  : e.g. "Papirus-Dark-Custom-A"
-- keep_widget_theme: e.g. "adw-gtk3-dark-Custom-A"
function common.cleanup_old_themes(keep_icon_theme, keep_widget_theme)
    local icon_prefix   = keep_icon_theme   and keep_icon_theme:match("^(.*%-Custom%-)[AB]$")   or keep_icon_theme
    local widget_prefix = keep_widget_theme and keep_widget_theme:match("^(.*%-Custom%-)[AB]$") or keep_widget_theme

    local rm_cmds = {}
    for _, dir in ipairs({ "/dev/shm", common.home .. "/.icons", common.home .. "/.themes" }) do
        local paths = common.dir_list(dir, 1, "*-Custom*")
        for _, path in ipairs(paths) do
            local name = path:match("([^/]+)$")
            if name then
                local keep = false
                if icon_prefix   and name:sub(1, #icon_prefix)   == icon_prefix   then keep = true end
                if widget_prefix and name:sub(1, #widget_prefix) == widget_prefix then keep = true end
                if not keep then table.insert(rm_cmds, "rm -rf " .. path) end
            end
        end
    end
    common.sh_batch(rm_cmds)
end

-- ── Icon backup ───────────────────────────────────────────────────────────────

function common.check_and_clean_backup(backup_dir, ram_dir, clean_pattern)
    if not clean_pattern then return end
    local p = io.popen('find ' .. backup_dir .. ' -name "' .. clean_pattern .. '" -print -quit 2>/dev/null')
    if p then
        local res = p:read("*a"); p:close()
        if res ~= "" then os.execute("rm -rf " .. ram_dir) end
    end
end

function common.create_backup(original_dir, backup_dir, exclusions, color_regex)
    local excl   = table.concat(exclusions, " ")
    local find_c = 'find -L . -type f -path "*/places/*" ' .. excl
    local grep_c = 'grep -lE "' .. color_regex .. '"'
    local cp_c   = 'xargs cp -a --parents -t ' .. backup_dir .. '/'
    os.execute('cd ' .. original_dir .. ' && ' .. find_c
        .. ' -print0 2>/dev/null | xargs -0 ' .. grep_c
        .. ' 2>/dev/null | ' .. cp_c .. ' 2>/dev/null')
end

function common.is_ram_populated(ram_dir)
    local p = io.popen("find " .. ram_dir .. " -name '*.svg' -print -quit 2>/dev/null")
    if not p then return false end
    local res = p:read("*a"); p:close()
    return res and res ~= ""
end

function common.is_theme_populated(dir)
    if not dir or dir == "" then return false end
    local p = io.popen("find -L " .. dir .. " -name '*.svg' -print -quit 2>/dev/null")
    if not p then return false end
    local res = p:read("*a"); p:close()
    return res and res ~= ""
end

function common.ensure_persistent_symlink_tree(original_dir, ram_dir, backup_dir, custom_theme, base_theme)
    if common.path_exists(ram_dir .. "/index.theme") then return end

    os.execute("mkdir -p " .. ram_dir)
    common.setup_index_theme(original_dir .. "/index.theme", ram_dir .. "/index.theme", custom_theme, base_theme)

    -- Un solo find depth=2 reemplaza N find anidados (elimina N-1 forks de bash)
    local ln_cmds = {}
    local mkdir_cmds = {}
    local p = io.popen("find " .. original_dir .. " -maxdepth 2 -mindepth 1 2>/dev/null")
    if p then
        for path in p:lines() do
            local depth1, depth2 = path:match(original_dir .. "/([^/]+)$"), path:match(original_dir .. "/([^/]+)/([^/]+)$")
            if depth1 and not depth2 and depth1 ~= "index.theme" then
                -- Nivel 1: tamaños (16x16, 22x22, etc.)
                table.insert(mkdir_cmds, "mkdir -p " .. ram_dir .. "/" .. depth1)
            elseif depth2 then
                local size = path:match(original_dir .. "/([^/]+)/[^/]+$")
                local sub  = path:match("([^/]+)$")
                local ram_item = ram_dir .. "/" .. size
                if sub == "places" then
                    table.insert(mkdir_cmds, "mkdir -p " .. ram_item .. "/places")
                elseif sub then
                    table.insert(ln_cmds, "ln -sfn " .. path .. " " .. ram_item .. "/" .. sub)
                end
            end
        end
        p:close()
    end

    local all_cmds = {}
    for _, c in ipairs(mkdir_cmds) do table.insert(all_cmds, c) end
    for _, c in ipairs(ln_cmds)   do table.insert(all_cmds, c) end
    if #all_cmds > 0 then
        os.execute(table.concat(all_cmds, " && "))
    end
end

function common.copy_and_recolor(backup_dir, ram_dir, sed_exprs)
    os.execute("cp -rd --remove-destination " .. backup_dir .. "/. " .. ram_dir .. "/")

    if not sed_exprs or #sed_exprs == 0 then return end

    local script_dir = debug.getinfo(1).source:match("@(.*)/") or ""
    local bin_c = script_dir .. "/recolor_svg"

    if common.path_exists(bin_c) then
        local args = { string.format("%q", bin_c), string.format("%q", ram_dir) }
        for _, expr in ipairs(sed_exprs) do
            table.insert(args, string.format("%q", expr[1]))
            table.insert(args, string.format("%q", expr[2]))
        end
        os.execute(table.concat(args, " ") .. " 2>/dev/null")
    else
        common.parallel_sed(ram_dir, sed_exprs)
    end
end

-- Recolorea SVGs ya existentes en RAM reemplazando old_exprs → new_exprs sin re-copiar desde backup.
-- old_exprs: tabla { {patron, reemplazo} } con el color ANTERIOR
-- new_exprs: tabla { {patron, reemplazo} } con el color NUEVO
-- Cae a copy_and_recolor si no hay SVGs en RAM.
function common.recolor_in_place(backup_dir, ram_dir, new_exprs)
    if not common.is_ram_populated(ram_dir) then
        -- Fallback: sin SVGs en RAM, copiar desde backup completo
        common.copy_and_recolor(backup_dir, ram_dir, new_exprs)
        return
    end
    common.parallel_sed(ram_dir, new_exprs)
end

function common.parallel_sed(ram_dir, sed_exprs)
    if not sed_exprs or #sed_exprs == 0 then return end
    local sed_args = {}
    for _, expr in ipairs(sed_exprs) do
        local pat = expr[1]:gsub("/", "\\/")
        local rep = expr[2]:gsub("/", "\\/")
        table.insert(sed_args, string.format("-e 's/%s/%s/g'", pat, rep))
    end
    local sed_expr_str = table.concat(sed_args, " ")
    os.execute(
        "find " .. ram_dir .. " -type f -name '*.svg' -print0 2>/dev/null" ..
        " | xargs -0 -P$(nproc) sed -i " .. sed_expr_str .. " 2>/dev/null"
    )
end

function common.setup_index_theme(src, dest, custom_theme, base_theme)
    local s = common.read_file(src)
    if not s then
        io.stderr:write("Error abriendo index.theme: " .. src .. "\n")
        return
    end
    s = s:gsub("(Name%s*=%s*)[^\n]*",    "%1" .. custom_theme)
    s = s:gsub("(Inherits%s*=%s*)[^\n]*", "%1" .. base_theme .. ",hicolor")
    common.write_file(dest, s)
end

function common.update_icon_cache(dir)
    os.execute("gtk-update-icon-cache -f -q -t " .. dir .. " 2>/dev/null &")
end

-- ── Appearance configuration (dynamic icons / GTK / storage) ─────────────────

function common.load_appearance_config()
    local cfg_path = common.home .. "/.config/i3/appearance.ini"
    local cfg = {
        dynamic_icons = true,
        dynamic_gtk   = true,
        storage_mode  = "ram",
    }
    local s = common.read_file(cfg_path)
    if s then
        for line in s:gmatch("[^\n]+") do
            local k, v = line:match("^([%w_]+)%s*=%s*(.*)")
            if k and v then
                v = v:gsub('^"', ''):gsub('"$', ''):gsub("%s+$", "")
                if k == "dynamic_icons" then
                    cfg.dynamic_icons = (v == "true" or v == "1")
                elseif k == "dynamic_gtk" then
                    cfg.dynamic_gtk = (v == "true" or v == "1")
                elseif k == "storage_mode" then
                    cfg.storage_mode = (v == "disk" or v == "hybrid") and "disk" or "ram"
                end
            end
        end
    end
    return cfg
end

function common.save_appearance_config(cfg)
    local cfg_path = common.home .. "/.config/i3/appearance.ini"
    local content = string.format(
        "dynamic_icons=%s\ndynamic_gtk=%s\nstorage_mode=%s\n",
        cfg.dynamic_icons and "true" or "false",
        cfg.dynamic_gtk and "true" or "false",
        cfg.storage_mode or "ram"
    )
    common.write_file(cfg_path, content)
end

function common.persist_theme_to_disk(custom_icon_theme)
    local ram_dir  = "/dev/shm/" .. custom_icon_theme
    local disk_dir = common.home .. "/.icons/" .. custom_icon_theme
    if not common.path_exists(ram_dir) then return false end

    os.execute("mkdir -p " .. common.home .. "/.icons")
    local tmp_disk = disk_dir .. "-tmp"
    os.execute("rm -rf " .. tmp_disk)
    os.execute("cp -rL " .. ram_dir .. " " .. tmp_disk)
    if common.path_exists(disk_dir .. "/index.theme") then
        os.execute("cp -f " .. disk_dir .. "/index.theme " .. tmp_disk .. "/index.theme")
    end
    os.execute("rm -rf " .. disk_dir)
    os.execute("mv " .. tmp_disk .. " " .. disk_dir)
    os.execute("rm -rf " .. ram_dir)
    common.update_icon_cache(disk_dir)
    return true
end

function common.restore_clean_themes(base_icon, base_gtk)
    local base_i = base_icon or "Papirus-Dark"
    local base_g = base_gtk  or "adw-gtk3-dark"

    os.execute("rm -rf /dev/shm/*-Custom-* " .. common.home .. "/.icons/*-Custom-* " .. common.home .. "/.themes/*-Custom-* 2>/dev/null")
    
    local gtk = require("gtk")
    local qt  = require("qt")
    gtk.apply(base_i, base_g)
    qt.apply(base_i)
end

return common
