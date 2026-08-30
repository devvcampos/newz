local Config = {}

Config.Project = {
    Name = "newz",
    Version = "0.1.0",
}

Config.UI = {
    Keybind = "LeftAlt",

    ConfigDirectory = "newz",
    ConfigFolder = "Configs",
}

Config.ESP = {
    Enabled = false,

    Box = true,
    Name = true,
    Health = true,
    Distance = true,

    BoxColor = Color3.fromRGB(
        255,
        255,
        255
    ),

    TextColor = Color3.fromRGB(
        255,
        255,
        255
    ),

    BoxThickness = 1,
    BoxPadding = 2,

    MaxDistance = 1000,
}

return Config