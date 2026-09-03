local Config = {}

Config.Project = {
    Name = "Newz",
    Version = "0.6.0",
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

    -- Extra visual layer inspired by the recovered project.
    Outlines = false,
    OutlineColor = Color3.fromRGB(0, 0, 0),

    HealthBar = {
        Enabled = false,
        Position = "Left",
        Width = 3,
        ShowText = false,

        DynamicColor = true,
        Color = Color3.fromRGB(90, 255, 130),
        BackgroundColor = Color3.fromRGB(12, 12, 12),
    },

    Skeleton = {
        Enabled = false,
        Color = Color3.fromRGB(255, 255, 255),
        Thickness = 1,
    },

    Flags = {
        Enabled = false,
        TextColor = Color3.fromRGB(255, 255, 255),

        Options = {
            Idle = true,
            Moving = true,
            Jumping = true,
        },
    },

    OffScreenArrows = {
        Enabled = false,
        Size = 20,
        Color = Color3.fromRGB(255, 255, 255),
        OrbitRadius = 150,
        Outline = true,
        OutlineColor = Color3.fromRGB(0, 0, 0),
    },

    Chams = {
        Enabled = false,
        FillColor = Color3.fromRGB(85, 170, 255),
        FillTransparency = 0.55,
        OutlineColor = Color3.fromRGB(255, 255, 255),
        OutlineTransparency = 0,
        AlwaysOnTop = true,
        VisibleCheck = false,
    },

    AdvancedText = {
        Enabled = false,
        Name = true,
        Distance = true,
        Position = "Bottom",
        Gap = 2,
        TextSize = 13,
        TextOutline = true,
    },
}

Config.Corpses = {
    Enabled = false,

    FolderName = "Corpses",

    Box = true,
    Name = true,
    Distance = true,

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

Config.Freecam = {
    Enabled = false,

    Keybind = "V",

    Speed = 55,
    BoostMultiplier = 3,
    MouseSensitivity = 0.12,

    -- Freecam keeps the real character in place while active.
    -- On normal exit this performs one ordinary client-side reposition attempt.
    TeleportOnExit = true,

    SnapToGround = true,
    GroundProbeDistance = 200,
    GroundOffset = 3,
}

Config.AimAssist = {
    Enabled = false,

    Keybind = "E",
    Hold = true,

    TargetPart = "Head",

    FOV = 150,
    MaxDistance = 1000,

    TeamCheck = true,
    VisibilityCheck = true,

    ShowFOV = true,
    FOVColor = Color3.fromRGB(255, 255, 255),

    -- Deterministic camera responsiveness. No randomized/humanized input.
    Responsiveness = 18,
}

Config.Zoom = {
    Enabled = false,
    Keybind = "Z",
    FOV = 25,
}

Config.Noclip = {
    Enabled = false,
    Keybind = "B",
}

Config.Invisible = {
    Enabled = false,
    Keybind = "I",
}

Config.PlayerTools = {
    SelectedName = "",
}

return Config
