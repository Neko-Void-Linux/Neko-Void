-- packages/i3dots/bin/colloid.lua
local colloid = {}

colloid.name = "Colloid"
colloid.color_regex = "#5294e2|#60c0f0|#357ec7"
colloid.backup_clean_pattern = "*pink*"

colloid.find_exclusions = {
    "! -path \"*@2x*\"",
    "! -path \"*/16/*\"",
    "! -path \"*/22/*\"",
    "! -path \"*/24/*\"",
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
    "! -name \"*pink*\"",
    "! -name \"*purple*\"",
    "! -name \"*blue*\"",
    "! -name \"*crash*\""
}

function colloid.get_sed_expressions(color, dark_color)
    return {
        { "#5294e2", "#" .. color },
        { "#5294E2", "#" .. color },
        { "#60c0f0", "#" .. color },
        { "#60C0F0", "#" .. color },
        { "#357ec7", "#" .. dark_color },
        { "#357EC7", "#" .. dark_color }
    }
end

function colloid.get_symbolic_sed_expressions(color)
    return {
        { "currentColor", "#" .. color },
    }
end

return colloid
