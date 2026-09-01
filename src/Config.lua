local Config = {}

Config.Project = {
    Name = "Newz",
    Version = "0.4.3",
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

Config.Profiler = {
    Enabled = false,
    Overlay = true,
    ReportInterval = 1.0,
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

Config.CorpseIllusion = {
    TargetName = "",

    -- Position of the visual-only copy relative to the local player.
    Distance = 5,
    VerticalOffset = 0,

    -- Local-only container created under Workspace.
    ContainerName = "newz_LocalIllusions",
}

Config.Corpses = {
    Enabled = false,

    FolderName = "Corpses",

    Box = true,
    Name = true,
    Distance = true,

    -- Keep all corpses tracked, but render only the nearest active set.
    MaxCorpses = 8,
    SelectionInterval = 0.25,

    BoxStyle = "Corner",

    Color = Color3.fromRGB(255, 190, 90),
    TextColor = Color3.fromRGB(255, 255, 255),

    BoxThickness = 1,
    BoxPadding = 2,
    CornerRatio = 0.25,

    MaxDistance = 500,
}

return Config
