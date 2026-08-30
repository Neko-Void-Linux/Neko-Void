#!/usr/bin/env lua
-- rofi_network.lua
-- Gestor de redes y WiFi interactivo para i3dots basado en Rofi y nmcli.
-- Adaptación optimizada, robusta y libre de bugs del script de Archcraft.

local os, io, string, table, math, utf8 = os, io, string, table, math, utf8

-- ---------- Helpers del Sistema ----------

local function shq(s)
	return "'" .. (tostring(s or ""):gsub("'", "'\\''")) .. "'"
end

local function run(cmd)
	local p = io.popen("LC_ALL=C " .. cmd .. " 2>/dev/null")
	if not p then return "", 1 end
	local out = p:read("*a") or ""
	local ok, _, code = p:close()
	local exit_code = (type(ok) == "number" and ok) or (code or (ok == true and 0 or 1))
	return out, exit_code
end

local function run_input(cmd, input)
	local in_file = os.tmpname()
	local f = io.open(in_file, "wb")
	if f then
		f:write(input or "")
		f:close()
	end
	local p = io.popen(cmd .. " < " .. shq(in_file) .. " 2>/dev/null")
	local out = p and p:read("*a") or ""
	local ok, _, code = false, nil, 1
	if p then ok, _, code = p:close() end
	os.remove(in_file)
	local exit_code = (type(ok) == "number" and ok) or (code or (ok == true and 0 or 1))
	return out, exit_code
end

local function has(cmd)
	local _, c = run("command -v " .. cmd)
	return c == 0
end

local function strip(s)
	return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function notify(title, msg, urgency)
	if not has("notify-send") then return end
	urgency = urgency or "low"
	local cmd = "notify-send -u " .. urgency .. " -a 'i3dots Network' -t 4000 " .. shq(title)
	if msg and msg ~= "" then
		cmd = cmd .. " " .. shq(msg)
	end
	os.execute(cmd .. " >/dev/null 2>&1 &")
end

-- ---------- Detección de Temas Rofi ----------

local function resolve_rofi_theme()
	local home = os.getenv("HOME") or ""
	local candidates = {
		home .. "/.config/rofi/themes/networkmenu.rasi",
		home .. "/.config/i3dots/packages/i3dots/config/rofi/themes/networkmenu.rasi",
		home .. "/.config/rofi/themes/wall_manage.rasi",
	}
	for _, p in ipairs(candidates) do
		local f = io.open(p, "r")
		if f then
			f:close()
			return p
		end
	end
	return nil
end

local ROFI_THEME = resolve_rofi_theme()

-- Procesar argumentos CLI
for i = 1, #arg do
	if arg[i] == "--theme" and arg[i + 1] then
		ROFI_THEME = arg[i + 1]
	end
end

-- ---------- Menú Interactivo (Rofi con -format i) ----------

local function rofi_menu(prompt, items, active_indices)
	local cmd = "rofi -dmenu -i -format i -p " .. shq(prompt)
	if ROFI_THEME and ROFI_THEME ~= "" then
		cmd = cmd .. " -theme " .. shq(ROFI_THEME)
	end
	if active_indices and #active_indices > 0 then
		cmd = cmd .. " -a " .. table.concat(active_indices, ",")
	end

	local lines = {}
	for i, it in ipairs(items) do
		lines[i] = it.label or tostring(it)
	end

	local out, code = run_input(cmd, table.concat(lines, "\n"))
	if code ~= 0 or strip(out) == "" then
		return nil -- Usuario canceló con Escape
	end

	local idx = tonumber(strip(out))
	if idx and items[idx + 1] then
		return items[idx + 1]
	end
	return nil
end

local function rofi_input(prompt, is_password)
	local cmd = "rofi -dmenu -p " .. shq(prompt)
	if is_password then
		cmd = cmd .. " -password"
	end
	if ROFI_THEME and ROFI_THEME ~= "" then
		cmd = cmd .. " -theme " .. shq(ROFI_THEME)
	end
	local out, code = run_input(cmd, "")
	if code ~= 0 then return nil end
	local val = strip(out)
	return (val ~= "") and val or nil
end

local function rofi_msg(title, text)
	local cmd = "rofi -e " .. shq(title .. "\n\n" .. text)
	if ROFI_THEME and ROFI_THEME ~= "" then
		cmd = cmd .. " -theme " .. shq(ROFI_THEME)
	end
	os.execute(cmd .. " >/dev/null 2>&1 &")
end

-- ---------- Consultas Optimizadas (rfkill en sysfs + nmcli por lotes) ----------

local function get_rfkill_states()
	local states = { wlan = true, bluetooth = nil }
	local p = io.popen("ls -d /sys/class/rfkill/rfkill* 2>/dev/null")
	if p then
		for dir in p:lines() do
			local f_type = io.open(dir .. "/type", "r")
			local f_soft = io.open(dir .. "/soft", "r")
			if f_type and f_soft then
				local typ = strip(f_type:read("*l") or "")
				local soft = strip(f_soft:read("*l") or "")
				f_type:close()
				f_soft:close()
				if typ == "wlan" then
					states.wlan = (soft == "0")
				elseif typ == "bluetooth" then
					states.bluetooth = (soft == "0")
				end
			end
		end
		p:close()
	end
	return states
end

local function toggle_bluetooth(enable)
	os.execute("bluetoothctl power " .. (enable and "on" or "off") .. " >/dev/null 2>&1 &")
	notify("[BT] Bluetooth", enable and "Bluetooth activado" or "Bluetooth desactivado")
end

local function fetch_all_data()
	-- Consulta unificada en una sola llamada (~35 ms):
	-- 1. Redes WiFi en caché (--rescan no para apertura instantánea)
	-- 2. Conexiones guardadas y activas
	local cmd = "LC_ALL=C sh -c \"nmcli -m multiline -t -f SIGNAL,SECURITY,ACTIVE,SSID,DEVICE device wifi list --rescan no; echo ===CONNS===; nmcli -m multiline -t -f NAME,TYPE,UUID,ACTIVE connection show\" 2>/dev/null"
	local p = io.popen(cmd)
	if not p then return {}, {} end
	local out = p:read("*a") or ""
	p:close()

	local sep = "\n===CONNS===\n"
	local pos = out:find(sep, 1, true)
	local wifi_str = pos and out:sub(1, pos - 1) or out
	local conn_str = pos and out:sub(pos + #sep) or ""

	-- 1. Parsear Redes WiFi
	local aps_map = {}
	local cur_ap = {}
	for line in wifi_str:gmatch("[^\r\n]+") do
		local k, v = line:match("^([A-Z]+):(.*)$")
		if k then
			cur_ap[k] = strip(v)
			if k == "DEVICE" then
				local ssid = cur_ap.SSID or ""
				local sig = tonumber(cur_ap.SIGNAL) or 0
				local sec = cur_ap.SECURITY or ""
				local act = (cur_ap.ACTIVE or ""):lower()
				local is_act = (act == "yes" or act == "si" or act == "sí" or act == "*")

				if ssid ~= "" and ssid ~= "--" then
					local existing = aps_map[ssid]
					if not existing then
						aps_map[ssid] = {
							ssid = ssid,
							signal = sig,
							sec = (sec ~= "" and sec ~= "--") and sec or "Abierta",
							active = is_act,
							dev = cur_ap.DEVICE or ""
						}
					else
						if is_act then
							existing.active = true
							existing.dev = cur_ap.DEVICE or existing.dev
						end
						if sig > existing.signal then
							existing.signal = sig
							if sec ~= "" and sec ~= "--" then existing.sec = sec end
						end
					end
				end
				cur_ap = {}
			end
		end
	end

	local aps = {}
	for _, ap in pairs(aps_map) do aps[#aps + 1] = ap end
	table.sort(aps, function(a, b)
		if a.active ~= b.active then return a.active end
		return a.signal > b.signal
	end)

	-- 2. Parsear Perfiles de Conexión
	local profiles = {}
	local cur_conn = {}
	for line in conn_str:gmatch("[^\r\n]+") do
		local k, v = line:match("^([A-Z]+):(.*)$")
		if k then
			cur_conn[k] = strip(v)
			if k == "ACTIVE" then
				if cur_conn.NAME and cur_conn.NAME ~= "" then
					local is_act = (cur_conn.ACTIVE:lower() == "yes" or cur_conn.ACTIVE == "*")
					profiles[#profiles + 1] = {
						name = cur_conn.NAME,
						type = cur_conn.TYPE or "",
						uuid = cur_conn.UUID or "",
						active = is_act
					}
				end
				cur_conn = {}
			end
		end
	end

	return aps, profiles
end

-- ---------- Iconos e Indicadores de Señal ----------

local function signal_icon(sig)
	if sig >= 80 then return "󰤨"
	elseif sig >= 60 then return "󰤥"
	elseif sig >= 40 then return "󰤢"
	elseif sig >= 20 then return "󰤟"
	else return "󰤯" end
end

-- ---------- Acciones de Red ----------

local function connect_wifi(ap)
	local ssid = ap.ssid

	-- Si ya está activa: confirmar si desea desconectar
	if ap.active then
		local items = {
			{ label = "Desconectar de " .. ssid, action = "disconnect" },
			{ label = "Cancelar", action = "cancel" }
		}
		local sel = rofi_menu("Desconectar Red Activa", items)
		if sel and sel.action == "disconnect" then
			local _, c = run("nmcli connection down id " .. shq(ssid))
			if c ~= 0 and ap.dev ~= "" then
				run("nmcli device disconnect " .. shq(ap.dev))
			end
			notify("[WIFI] Desconectado", "Se desconectó de " .. ssid)
		end
		return
	end

	-- Verificar si ya es una conexión guardada en perfiles
	local _, c_saved = run("nmcli -t -f NAME connection show id " .. shq(ssid))
	local is_saved = (c_saved == 0)

	if is_saved then
		notify("[WIFI] Conectando...", "Activando conexión guardada " .. ssid)
		local out, c = run("nmcli connection up id " .. shq(ssid))
		if c == 0 then
			notify("[OK] Conexión establecida", "Conectado exitosamente a " .. ssid)
		else
			notify("[ERROR] Error al conectar", "No se pudo conectar a " .. ssid .. ": " .. strip(out), "critical")
		end
		return
	end

	-- Red nueva con clave
	local is_open = (ap.sec == "Abierta" or ap.sec == "--" or ap.sec == "" or ap.sec:match("NONE"))
	local password = nil
	if not is_open then
		password = rofi_input("Clave para " .. ssid .. ":", true)
		if not password or password == "" then
			return -- Cancelado por el usuario
		end
	end

	notify("[WIFI] Conectando...", "Estableciendo conexión con " .. ssid)
	local cmd = "nmcli device wifi connect " .. shq(ssid)
	if password and password ~= "" then
		cmd = cmd .. " password " .. shq(password)
	end

	local out, c = run(cmd)
	if c == 0 then
		notify("[OK] WiFi Conectado", "Conexión exitosa a " .. ssid)
	else
		notify("[ERROR] Fallo de autenticación", "Error al conectar con " .. ssid .. ": " .. strip(out), "critical")
	end
end

local function toggle_connection(name, is_active)
	if is_active then
		run("nmcli connection down id " .. shq(name))
		notify("[NET] Conexión desactivada", name)
	else
		run("nmcli connection up id " .. shq(name))
		notify("[NET] Conexión activada", name)
	end
end

local function delete_saved_connection()
	local out, _ = run("nmcli -m multiline -t -f NAME,TYPE connection show")
	local items = {}
	local cur = {}
	for line in (out or ""):gmatch("[^\r\n]+") do
		local k, v = line:match("^([A-Z]+):(.*)$")
		if k then
			cur[k] = strip(v)
			if k == "TYPE" then
				if cur.TYPE == "802-11-wireless" and cur.NAME then
					items[#items + 1] = { label = "Eliminar: " .. cur.NAME, name = cur.NAME }
				end
				cur = {}
			end
		end
	end

	if #items == 0 then
		notify("[INFO] Redes Guardadas", "No hay redes WiFi guardadas para eliminar.")
		return
	end

	local sel = rofi_menu("Seleccionar red a eliminar", items)
	if sel and sel.name then
		local conf = rofi_menu("¿Confirmar eliminación de '" .. sel.name .. "'?", {
			{ label = "Sí, eliminar definitivamente", ok = true },
			{ label = "No, cancelar", ok = false }
		})
		if conf and conf.ok then
			run("nmcli connection delete id " .. shq(sel.name))
			notify("[OK] Red eliminada", "Se eliminó el perfil '" .. sel.name .. "'")
		end
	end
end

local function launch_qr_terminal(ssid, psk)
	local inner_cmd = string.format(
		"echo -e '\\033[1;35m[WIFI] Red:\\033[0m %s'; " ..
		"echo -e '\\033[1;35m[WIFI] Clave:\\033[0m %s\\n'; " ..
		"if command -v qrencode &>/dev/null; then " ..
		"    qrencode -t UTF8 %s; " ..
		"else " ..
		"    nmcli device wifi show-password 2>/dev/null || true; " ..
		"fi; " ..
		"echo ''; " ..
		"read -n 1 -s -r -p 'Presiona cualquier tecla para cerrar...'",
		ssid, psk, shq("WIFI:T:WPA;S:" .. ssid .. ";P:" .. psk .. ";;")
	)

	local term_cmd = nil
	if has("kitty") then
		term_cmd = "kitty --class wifi-qr --title 'WiFi QR - " .. ssid .. "' -e bash -c " .. shq(inner_cmd)
	elseif has("alacritty") then
		term_cmd = "alacritty --class wifi-qr --title 'WiFi QR - " .. ssid .. "' -e bash -c " .. shq(inner_cmd)
	elseif has("foot") then
		term_cmd = "foot --app-id wifi-qr --title 'WiFi QR - " .. ssid .. "' bash -c " .. shq(inner_cmd)
	elseif has("xterm") then
		term_cmd = "xterm -class wifi-qr -title 'WiFi QR - " .. ssid .. "' -e bash -c " .. shq(inner_cmd)
	end

	if term_cmd then
		os.execute(term_cmd .. " >/dev/null 2>&1 &")
	else
		notify("[ERROR] Terminal", "No se encontró ningún emulador de terminal compatible.", "critical")
	end
end

local function show_current_password(active_ssid)
	if not active_ssid or active_ssid == "" then
		notify("[INFO] WiFi", "No hay ninguna red activa en este momento.")
		return
	end

	local psk, _ = run("nmcli -s -g 802-11-wireless-security.psk connection show id " .. shq(active_ssid))
	psk = strip(psk)
	if psk == "" then
		notify("[INFO] WiFi", "La red '" .. active_ssid .. "' no requiere contraseña o no está disponible.")
		return
	end

	-- Menú interactivo con tema nativo de Rofi
	local options = {
		{ label = "󰷖   Red (SSID):     " .. active_ssid, action = "copy" },
		{ label = "󰌘   Contraseña:     " .. psk, action = "copy" },
		{ label = "󰆏   Copiar contraseña al portapapeles", action = "copy" },
		{ label = "󰐳   Mostrar código QR en terminal", action = "qr" },
		{ label = "󰅖   Cerrar", action = "close" }
	}

	local sel = rofi_menu("Seguridad de " .. active_ssid, options)
	if sel then
		if sel.action == "copy" then
			if has("xclip") then
				os.execute("printf '%s' " .. shq(psk) .. " | xclip -selection clipboard >/dev/null 2>&1")
				notify("[OK] Contraseña copiada", "Copiada al portapapeles: " .. psk)
			end
		elseif sel.action == "qr" then
			launch_qr_terminal(active_ssid, psk)
		end
	end
end

local function connect_hidden_network()
	local ssid = rofi_input("Nombre de red oculta (SSID):", false)
	if not ssid or ssid == "" then return end

	local pass = rofi_input("Contraseña (dejar vacío si es abierta):", true)

	local cmd = "nmcli device wifi connect " .. shq(ssid) .. " hidden yes"
	if pass and pass ~= "" then
		cmd = cmd .. " password " .. shq(pass)
	end

	notify("[WIFI] Conectando a red oculta...", ssid)
	local out, c = run(cmd)
	if c == 0 then
		notify("[OK] Red Oculta Conectada", ssid)
	else
		notify("[ERROR] Fallo al conectar a red oculta", strip(out), "critical")
	end
end

local function launch_connection_manager()
	if has("nm-connection-editor") then
		os.execute("nohup nm-connection-editor >/dev/null 2>&1 &")
		return
	end
	for _, term in ipairs({ "kitty", "alacritty", "foot", "xterm" }) do
		if has(term) and has("nmtui") then
			os.execute(term .. " -e nmtui >/dev/null 2>&1 &")
			return
		end
	end
	notify("[ERROR] Gestor de red", "Ni nm-connection-editor ni nmtui están disponibles", "critical")
end

-- ---------- Menú Principal ----------

local function main()
	-- 0. Validar si nmcli está disponible (componente opcional)
	if not has("nmcli") then
		notify("[INFO] Gestor de Red", "NetworkManager (nmcli) no está instalado en este sistema.", "normal")
		rofi_msg("Gestor de Red - i3dots", "El comando 'nmcli' (NetworkManager) no se encuentra instalado en este sistema.\n\nEste menú es un componente opcional de i3dots. Si deseas gestionar conexiones y redes WiFi desde aquí, puedes instalarlo con tu gestor de paquetes:\n\n  • Void Linux:   xbps-install -S NetworkManager\n  • Arch Linux:   pacman -S networkmanager\n  • Debian/Ubuntu: apt install network-manager")
		return
	end

	-- 1. Estados de hardware instantáneos (sysfs en ~0.2 ms)
	local rf = get_rfkill_states()
	local wifi_on = rf.wlan
	local bt_on = rf.bluetooth

	-- 2. Consultar datos en lote en una sola ejecución ultrarrápida (~35 ms)
	local aps, profiles = fetch_all_data()

	local items = {}
	local active_indices = {}
	local active_wifi_ssid = nil

	-- 3. Redes WiFi disponibles
	if wifi_on then
		for _, ap in ipairs(aps) do
			if ap.active then active_wifi_ssid = ap.ssid end
			local icon = signal_icon(ap.signal)
			local sec_badge = (ap.sec == "Abierta") and "󰌘 -" or ("󰌘 " .. ap.sec)
			local status = ap.active and "[Conectado]" or ""
			local label = string.format("%-2s  %-24s  %-15s  %3d%%  %s", icon, ap.ssid:sub(1, 24), sec_badge, ap.signal, status)

			local item = {
				label = label,
				type = "ap",
				ap = ap,
				active = ap.active
			}
			items[#items + 1] = item
			if ap.active then
				active_indices[#active_indices + 1] = #items - 1
			end
		end
	end

	-- 4. Conexiones Ethernet / VPN / Wireguard
	local has_any_active = false
	for _, p in ipairs(profiles) do
		if p.active then has_any_active = true end
		if p.type == "802-3-ethernet" then
			items[#items + 1] = {
				label = string.format("󰈀   Ethernet: %-20s  %s", p.name, p.active and "[Activo]" or "[Inactivo]"),
				type = "toggle",
				name = p.name,
				active = p.active
			}
			if p.active then active_indices[#active_indices + 1] = #items - 1 end
		elseif p.type == "vpn" or p.type == "wireguard" then
			items[#items + 1] = {
				label = string.format("󰖂   VPN: %-25s  %s", p.name, p.active and "[Conectada]" or "[Desconectada]"),
				type = "toggle",
				name = p.name,
				active = p.active
			}
			if p.active then active_indices[#active_indices + 1] = #items - 1 end
		end
	end

	-- 5. Separador y Opciones de Control
	local wifi_label = wifi_on and "󰤮   Desactivar WiFi" or "󰤨   Activar WiFi"
	items[#items + 1] = { label = wifi_label, type = "toggle_wifi", current = wifi_on }

	local net_on = (wifi_on or has_any_active)
	local net_label = net_on and "󰈂   Desactivar Red (Modo Avión)" or "󰈁   Activar Red Global"
	items[#items + 1] = { label = net_label, type = "toggle_net", current = net_on }

	if bt_on ~= nil then
		local bt_label = bt_on and "󰂲   Desactivar Bluetooth" or "󰂯   Activar Bluetooth"
		items[#items + 1] = { label = bt_label, type = "toggle_bt", current = bt_on }
	end

	if wifi_on then
		items[#items + 1] = { label = "󰑐   Escanear redes WiFi", type = "rescan" }
		items[#items + 1] = { label = "󰤨   Conectar a red oculta...", type = "hidden" }
		items[#items + 1] = { label = "󰷖   Ver contraseña de red actual", type = "show_pass", ssid = active_wifi_ssid }
	end

	local has_saved_wifi = false
	for _, p in ipairs(profiles) do
		if p.type == "802-11-wireless" then
			has_saved_wifi = true
			break
		end
	end
	if has_saved_wifi then
		items[#items + 1] = { label = "󰆴   Eliminar conexión guardada...", type = "delete" }
	end

	if has("nm-connection-editor") or has("nmtui") then
		items[#items + 1] = { label = "󰒓   Abrir gestor avanzado de conexiones", type = "manager" }
	end

	-- 6. Mostrar menú
	local sel = rofi_menu("Redes & WiFi", items, active_indices)
	if not sel then return end

	-- 7. Procesar selección
	if sel.type == "ap" then
		connect_wifi(sel.ap)
	elseif sel.type == "toggle" then
		toggle_connection(sel.name, sel.active)
	elseif sel.type == "toggle_wifi" then
		run("nmcli radio wifi " .. (sel.current and "off" or "on"))
		notify("[WIFI] Estado WiFi", sel.current and "WiFi desactivado" or "WiFi activado")
	elseif sel.type == "toggle_net" then
		run("nmcli networking " .. (sel.current and "off" or "on"))
		notify("[NET] Estado de Red", sel.current and "Red desactivada" or "Red activada")
	elseif sel.type == "toggle_bt" then
		toggle_bluetooth(not sel.current)
	elseif sel.type == "rescan" then
		notify("[INFO] WiFi", "Buscando redes inalámbricas...")
		run("nmcli device wifi rescan")
		os.execute("sleep 2")
		main()
	elseif sel.type == "show_pass" then
		show_current_password(sel.ssid)
	elseif sel.type == "hidden" then
		connect_hidden_network()
	elseif sel.type == "delete" then
		delete_saved_connection()
	elseif sel.type == "manager" then
		launch_connection_manager()
	end
end

main()
