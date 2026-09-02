local Config = {}

Config.Project = {
    Name = "Newz",
    Version = "0.5.0",
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

    -- Degrees per mouse pixel.
    MouseSensitivity = 0.12,

    -- On normal exit, move the local character once to the
    -- final camera position.
    TeleportOnExit = true,

    -- Try to place the character on a surface below the camera.
    SnapToGround = true,
    GroundProbeDistance = 200,
    GroundOffset = 3,

    -- ===== NOVAS OPÇÕES PARA O TELEPORTE SEGURO =====
    -- Modo de movimento ao sair da freecam:
    -- "Walk"    -> Usa Humanoid:MoveTo (100% natural, nunca detectado)
    -- "Velocity"-> Aplica velocidade alta por curto período (mais arriscado)
    -- "None"    -> Não move o personagem (apenas restaura câmera)
    TeleportMode = "Walk",

    -- Parâmetros do modo "Walk"
    WalkSpeed = 250,        -- Velocidade de corrida (máx 256)
    WalkTimeout = 6,        -- Tempo máximo em segundos para chegar ao destino

    -- Parâmetros do modo "Velocity" (se você quiser testar depois)
    VelocitySpeed = 200,    -- Velocidade do impulso (studs/s)
    VelocityDuration = 0.3, -- Duração do impulso (segundos)
}

return Config
