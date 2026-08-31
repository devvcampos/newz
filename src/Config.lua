local Config = {}

Config.Project = {
    Name = "newz",
    Version = "0.1.0",
}

Config.Runtime = {
    EntitiesFolder = "Players",
    EntityFolderTimeout = 15,
    UpdateFrequency = 30,
    VisibilityInterval = 0.10,
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

    -----------------------------------------------------
    -- FILTERS
    -----------------------------------------------------

    VisibilityCheck = false,
    TeamCheck = false,
    PlayersOnly = false,

    -----------------------------------------------------
    -- APPEARANCE
    -----------------------------------------------------

    BoxStyle = "Corner",

BoxColor =
    Color3.fromRGB(
        255,
        255,
        255
    ),

HiddenColor =
    Color3.fromRGB(
        255,
        90,
        90
    ),

    TextColor =
        Color3.fromRGB(
            255,
            255,
            255
        ),

    DynamicHealthColor = true,

    BoxThickness = 1,
    BoxPadding = 2,

    CornerRatio = 0.25,

    MaxDistance = 1000,
}

return Config
