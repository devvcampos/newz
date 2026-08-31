local Config = {}

Config.Project = {
    Name = "Newz",
    Version = "0.2.0",
}

Config.Runtime = {
    UpdateFrequency = 30,
    VisibilityInterval = 0.10,
}

Config.UI = {
    Keybind = "LeftAlt",

    ConfigDirectory = "newz",
    ConfigFolder = "Configs",

    AccentColor = Color3.fromRGB(17, 238, 253),
    Watermark = true,
}

Config.ESP = {
    Enabled = false,

    Box = true,
    Name = true,
    Health = true,
    Weapon = true,
    Distance = true,

    VisibilityCheck = false,
    TeamCheck = false,

    BoxStyle = "Corner",

    VisibleColor = Color3.fromRGB(90, 255, 130),
    HiddenColor = Color3.fromRGB(255, 90, 90),
    TextColor = Color3.fromRGB(255, 255, 255),

    DynamicHealthColor = true,

    BoxThickness = 1,
    BoxPadding = 2,
    CornerRatio = 0.25,

    MaxDistance = 1000,
}

return Config
