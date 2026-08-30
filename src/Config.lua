local Config = {}

Config.Project = {
    Name = "newz",
    Version = "0.1.0",
}

Config.UI = {
    Keybind = "LeftAlt",

    ConfigDirectory = "newz",
    ConfigFolder = "Configs",

    HighlightColor =
        Color3.fromRGB(
            17,
            238,
            253
        ),

    AlwaysShowTab = false,

    PerformanceMode = false,

    Watermark = true,

    Rainbow = false,

    RainbowSpeed = 0.10,
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