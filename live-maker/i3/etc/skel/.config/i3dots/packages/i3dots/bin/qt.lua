-- packages/i3dots/bin/qt.lua
local common = require("common")
local qt = {}

function qt.sync_timestamp()
    local val = 0
    local handle = io.popen("xprop -root _QT_SETTINGS_TIMESTAMP 2>/dev/null")
    if handle then
        local res = handle:read("*a"); handle:close()
        local num = res:match("=%s*(%d+)")
        local parsed = num and tonumber(num)
        if parsed then val = math.floor(parsed) end
    end
    val = (val + 1) % 2000000000
    os.execute("xprop -root -f _QT_SETTINGS_TIMESTAMP 32c -set _QT_SETTINGS_TIMESTAMP " .. val .. " 2>/dev/null || true")
end

local function write_icon_theme(theme)
    local targets = {
        common.home .. "/.config/qt5ct/qt5ct.conf",
        common.home .. "/.config/qt6ct/qt6ct.conf",
    }
    for _, path in ipairs(targets) do
        local f = io.open(path, "r")
        if f then
            local content = f:read("*a"); f:close()
            local new
            if content:find("icon_theme%s*=") then
                new = content:gsub("(icon_theme%s*=%s*)[^\n]*", "%1" .. theme)
            else
                new = content:gsub("%[Appearance%]", "[Appearance]\nicon_theme=" .. theme)
            end
            local tmp_path = path .. ".tmp"
            local fw = io.open(tmp_path, "w")
            if fw then
                fw:write(new)
                fw:close()
                os.rename(tmp_path, path)
            end
        end
    end
end

function qt.apply(theme)
    write_icon_theme(theme)
    qt.sync_timestamp()
end

return qt
