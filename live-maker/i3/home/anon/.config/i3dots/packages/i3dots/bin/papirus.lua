-- packages/i3dots/bin/papirus.lua
local papirus = {}

papirus.name = "Papirus"
papirus.color_regex = "#5294e2|#4877b1|#1d344f"
papirus.backup_clean_pattern = "*green*"

papirus.find_exclusions = {
    "! -path \"*@2x*\"",
    "! -path \"*16x16*\"",
    "! -path \"*22x22*\"",
    "! -path \"*24x24*\"",
    "! -path \"*symbolic*\"",
    "! -name \"*green*\"",
    "! -name \"*grey*\"",
    "! -name \"*orange*\"",
    "! -name \"*red*\"",
    "! -name \"*violet*\"",
    "! -name \"*yellow*\"",
    "! -name \"*nord*\"",
    "! -name \"*indigo*\"",
    "! -name \"*magenta*\"",
    "! -name \"*cyan*\"",
    "! -name \"*brown*\"",
    "! -name \"*black*\"",
    "! -name \"*white*\"",
    "! -name \"*teal*\"",
    "! -name \"*carmine*\"",
    "! -name \"*pink*\"",
    "! -name \"*adwaita*\"",
    "! -name \"*breeze*\"",
    "! -name \"*yaru*\"",
    "! -name \"*elementary*\"",
    "! -name \"*custom*\"",
    "! -name \"*crash*\""
}

function papirus.get_sed_expressions(color, dark_color)
    return {
        { "#5294e2", "#" .. color },
        { "#5294E2", "#" .. color },
        { "#4877b1", "#" .. dark_color },
        { "#4877B1", "#" .. dark_color },
        { "#1d344f", "#" .. dark_color },
        { "#1D344F", "#" .. dark_color }
    }
end

function papirus.get_symbolic_sed_expressions(color)
    return {
        { "currentColor", "#" .. color },
        { "color:#444444", "color:#" .. color },
        { "color:#4285f4", "color:#" .. color },
    }
end

return papirus
