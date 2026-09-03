local UI = {}

local function Traceback(Error)
    if
        debug
        and type(debug.traceback)
            == "function"
    then
        return debug.traceback(
            tostring(Error),
            2
        )
    end

    return tostring(Error)
end

function UI.Init(
    Config,
    Dependencies
)
    local Players =
        game:GetService("Players")

    local LocalPlayer =
        Players.LocalPlayer

    assert(
        LocalPlayer,
        "UI precisa ser inicializada no cliente"
    )

    assert(
        type(Dependencies) == "table"
        and type(
            Dependencies.NeverLose
        ) == "table",
        "UI.Init precisa receber Dependencies.NeverLose"
    )

    local NeverLose =
        Dependencies.NeverLose

    local Freecam =
        Dependencies.Freecam

    local PlayerTools =
        Dependencies.PlayerTools

    local AimAssist =
        Dependencies.AimAssist

    local CharacterFeatures =
        Dependencies.CharacterFeatures

    local AdvancedESP =
        Dependencies.AdvancedESP

    local SensoryESP =
        Dependencies.SensoryESP

    local RemoteBridge =
        Dependencies.RemoteBridge

    assert(
        type(NeverLose.CreateWindow)
            == "function",
        "NeverLose invalida"
    )

    assert(
        type(Freecam) == "table"
        and type(Freecam.Toggle)
            == "function"
        and type(Freecam.SetKeybind)
            == "function",
        "Freecam invalida"
    )

    assert(
        type(PlayerTools) == "table"
        and type(PlayerTools.GetPlayerNames)
            == "function"
        and type(PlayerTools.GetInfo)
            == "function",
        "PlayerTools invalido"
    )

    assert(
        type(AimAssist) == "table"
        and type(AimAssist.SetEnabled)
            == "function",
        "AimAssist invalido"
    )

    assert(
        type(CharacterFeatures) == "table"
        and type(CharacterFeatures.SetZoom)
            == "function"
        and type(CharacterFeatures.SetNoclip)
            == "function"
        and type(CharacterFeatures.SetInvisible)
            == "function",
        "CharacterFeatures invalido"
    )

    assert(
        type(AdvancedESP) == "table"
        and type(AdvancedESP.Refresh)
            == "function",
        "AdvancedESP invalido"
    )

    assert(
        type(SensoryESP) == "table"
        and type(SensoryESP.SetEnabled)
            == "function"
        and type(SensoryESP.Load)
            == "function",
        "SensoryESP invalido"
    )

    assert(
        type(RemoteBridge) == "table"
        and type(RemoteBridge.FireTest)
            == "function",
        "RemoteBridge invalido"
    )

    local Destroyed = false
    local Threads = {}
    local Window
    local Watermark

    local function Cleanup()
        if Destroyed then
            return
        end

        Destroyed = true

        Freecam.SetStateChangedCallback(
            nil
        )

        PlayerTools.SetStateChangedCallback(
            nil
        )

        AimAssist.SetStateChangedCallback(
            nil
        )

        CharacterFeatures.SetStateChangedCallback(
            nil
        )

        SensoryESP.SetStateChangedCallback(
            nil
        )

        for _, Thread
            in pairs(
                Threads
            )
        do
            if
                typeof(Thread)
                == "thread"
            then
                pcall(
                    task.cancel,
                    Thread
                )
            end
        end

        table.clear(
            Threads
        )

        if
            Window
            and Window.ConfigManager
        then
            local ConfigManager =
                Window.ConfigManager

            if ConfigManager.UnsafeThread then
                pcall(function()
                    ConfigManager.UnsafeThread:
                        Disconnect()
                end)

                ConfigManager.UnsafeThread =
                    nil
            end
        end

        if
            NeverLose
            and type(
                NeverLose.Unload
            ) == "function"
        then
            pcall(function()
                NeverLose:Unload()
            end)
        end
    end

    local Success,
        Result =
            xpcall(function()
                NeverLose.UnloadEnabled =
                    true

                if Config.UI.AccentColor then
                    NeverLose.AccentColor =
                        Config.UI.AccentColor
                end

                local ConfigDirectory =
                    tostring(
                        Config.UI.ConfigDirectory
                        or "newz"
                    )

                local ConfigFolderName =
                    tostring(
                        Config.UI.ConfigFolder
                        or "Configs"
                    )

                local ConfigFolder =
                    ConfigDirectory
                    .. "/"
                    .. ConfigFolderName

                Window =
                    NeverLose:
                        CreateWindow({
                            Name =
                                Config.Project.Name,

                            Content =
                                "Entity Diagnostics  •  v"
                                .. tostring(
                                    Config.Project.Version
                                ),

                            Size =
                                NeverLose.Scales.Default,

                            ConfigFolder =
                                ConfigFolder,

                            Enable3DRenderer =
                                false,

                            Keybind =
                                Config.UI.Keybind
                                or "LeftAlt",
                        })

                assert(
                    Window,
                    "NeverLose.CreateWindow falhou"
                )

                Window:SetAccount({
                    Username =
                        LocalPlayer.DisplayName,

                    Expires =
                        "DEV",
                })

                Watermark =
                    Window:Watermark()

                Watermark:AddBlock(
                    "eye",
                    Config.Project.Name
                )

                Watermark:AddBlock(
                    "user",
                    LocalPlayer.Name
                )

                local WatermarkPlayers =
                    Watermark:AddBlock(
                        "users",
                        "Players: "
                        .. tostring(
                            #Players:GetPlayers()
                        )
                    )

                Watermark:SetRender(
                    Config.UI.Watermark
                    ~= false
                )

                Threads.Watermark =
                    task.spawn(function()
                        while not Destroyed do
                            task.wait(1.5)

                            if Destroyed then
                                break
                            end

                            WatermarkPlayers:
                                SetText(
                                    "Players: "
                                    .. tostring(
                                        #Players:GetPlayers()
                                    )
                                )
                        end
                    end)

                local function AddToggle(
                    Section,
                    Name,
                    Flag,
                    Default,
                    Callback
                )
                    return
                        Section:
                            AddLabel(Name):
                            AddToggle({
                                Flag =
                                    Flag,

                                Default =
                                    Default,

                                Callback =
                                    Callback,
                            })
                end

                local function AddSlider(
                    Section,
                    Name,
                    Flag,
                    Default,
                    Min,
                    Max,
                    Rounding,
                    Callback
                )
                    return
                        Section:
                            AddLabel(Name):
                            AddSlider({
                                Flag =
                                    Flag,

                                Default =
                                    Default,

                                Min =
                                    Min,

                                Max =
                                    Max,

                                Rounding =
                                    Rounding,

                                Callback =
                                    Callback,
                            })
                end

                local function AddColorPicker(
                    Section,
                    Name,
                    Flag,
                    Default,
                    Callback
                )
                    return
                        Section:
                            AddLabel(Name):
                            AddColorPicker({
                                Flag =
                                    Flag,

                                Default =
                                    Default,

                                Callback =
                                    Callback,
                            })
                end

                local function AddDropdown(
                    Section,
                    Name,
                    Flag,
                    Default,
                    Values,
                    Callback
                )
                    return
                        Section:
                            AddLabel(Name):
                            AddDropdown({
                                Flag =
                                    Flag,

                                Default =
                                    Default,

                                Values =
                                    Values,

                                Multi =
                                    false,

                                Callback =
                                    Callback,
                            })
                end

                local function AddKeybind(
                    Section,
                    Name,
                    Flag,
                    Default,
                    Callback
                )
                    return
                        Section:
                            AddLabel(Name):
                            AddKeybind({
                                Flag =
                                    Flag,

                                Default =
                                    Default,

                                Callback =
                                    Callback,
                            })
                end

                -----------------------------------------------------
                -- PLAYERS
                -----------------------------------------------------

                local PlayersTab =
                    Window:AddTab({
                        Icon =
                            "crosshairs",

                        Name =
                            "Players",

                        Type =
                            "Double",
                    })

                local ESPSection =
                    PlayersTab:
                        AddSection({
                            Name =
                                "ESP",

                            Position =
                                "left",
                        })

                AddToggle(
                    ESPSection,
                    "Enabled",
                    "esp_enabled",
                    Config.ESP.Enabled,
                    function(Value)
                        Config.ESP.Enabled =
                            Value

                        AdvancedESP.Refresh()
                    end
                )

                AddToggle(
                    ESPSection,
                    "Box",
                    "esp_box",
                    Config.ESP.Box,
                    function(Value)
                        Config.ESP.Box =
                            Value
                    end
                )

                AddToggle(
                    ESPSection,
                    "Name",
                    "esp_name",
                    Config.ESP.Name,
                    function(Value)
                        Config.ESP.Name =
                            Value
                    end
                )

                AddToggle(
                    ESPSection,
                    "Health",
                    "esp_health",
                    Config.ESP.Health,
                    function(Value)
                        Config.ESP.Health =
                            Value
                    end
                )

                AddToggle(
                    ESPSection,
                    "Weapon",
                    "esp_weapon",
                    Config.ESP.Weapon,
                    function(Value)
                        Config.ESP.Weapon =
                            Value
                    end
                )

                AddToggle(
                    ESPSection,
                    "Distance",
                    "esp_distance",
                    Config.ESP.Distance,
                    function(Value)
                        Config.ESP.Distance =
                            Value
                    end
                )

                local FiltersSection =
                    PlayersTab:
                        AddSection({
                            Name =
                                "Filters",

                            Position =
                                "left",
                        })

                AddToggle(
                    FiltersSection,
                    "Visibility Check",
                    "esp_visibility",
                    Config.ESP.VisibilityCheck,
                    function(Value)
                        Config.ESP.VisibilityCheck =
                            Value
                    end
                )

                AddToggle(
                    FiltersSection,
                    "Team Check",
                    "esp_team_check",
                    Config.ESP.TeamCheck,
                    function(Value)
                        Config.ESP.TeamCheck =
                            Value
                    end
                )

                AddToggle(
                    FiltersSection,
                    "Dynamic Health Color",
                    "esp_dynamic_health",
                    Config.ESP.DynamicHealthColor,
                    function(Value)
                        Config.ESP.DynamicHealthColor =
                            Value
                    end
                )

                local AppearanceSection =
                    PlayersTab:
                        AddSection({
                            Name =
                                "Appearance",

                            Position =
                                "right",
                        })

                AddDropdown(
                    AppearanceSection,
                    "Box Style",
                    "esp_box_style",
                    Config.ESP.BoxStyle,
                    {
                        "Corner",
                        "Full",
                    },
                    function(Value)
                        Config.ESP.BoxStyle =
                            Value
                    end
                )

                AddColorPicker(
                    AppearanceSection,
                    "Visible Color",
                    "esp_visible_color",
                    Config.ESP.VisibleColor,
                    function(Value)
                        Config.ESP.VisibleColor =
                            Value
                    end
                )

                AddColorPicker(
                    AppearanceSection,
                    "Hidden Color",
                    "esp_hidden_color",
                    Config.ESP.HiddenColor,
                    function(Value)
                        Config.ESP.HiddenColor =
                            Value
                    end
                )

                AddColorPicker(
                    AppearanceSection,
                    "Text Color",
                    "esp_text_color",
                    Config.ESP.TextColor,
                    function(Value)
                        Config.ESP.TextColor =
                            Value
                    end
                )

                AddSlider(
                    AppearanceSection,
                    "Box Thickness",
                    "esp_box_thickness",
                    Config.ESP.BoxThickness,
                    1,
                    4,
                    0,
                    function(Value)
                        Config.ESP.BoxThickness =
                            Value
                    end
                )

                AddSlider(
                    AppearanceSection,
                    "Corner Size",
                    "esp_corner_ratio",
                    Config.ESP.CornerRatio,
                    0.10,
                    0.50,
                    2,
                    function(Value)
                        Config.ESP.CornerRatio =
                            Value
                    end
                )

                AddSlider(
                    AppearanceSection,
                    "Box Padding",
                    "esp_box_padding",
                    Config.ESP.BoxPadding,
                    0,
                    10,
                    0,
                    function(Value)
                        Config.ESP.BoxPadding =
                            Value
                    end
                )

                AddSlider(
                    AppearanceSection,
                    "Max Distance",
                    "esp_max_distance",
                    Config.ESP.MaxDistance,
                    50,
                    3000,
                    0,
                    function(Value)
                        Config.ESP.MaxDistance =
                            Value
                    end
                )

                -----------------------------------------------------
                -- ADVANCED ESP
                -----------------------------------------------------

                local AdvancedSection =
                    PlayersTab:
                        AddSection({
                            Name =
                                "Advanced ESP",

                            Position =
                                "left",
                        })

                AddToggle(
                    AdvancedSection,
                    "Outlines",
                    "adv_outlines",
                    Config.ESP.Outlines,
                    function(Value)
                        Config.ESP.Outlines =
                            Value

                        AdvancedESP.Refresh()
                    end
                )

                AddToggle(
                    AdvancedSection,
                    "Health Bar",
                    "adv_healthbar",
                    Config.ESP.HealthBar.Enabled,
                    function(Value)
                        Config.ESP.HealthBar.Enabled =
                            Value

                        AdvancedESP.Refresh()
                    end
                )

                AddToggle(
                    AdvancedSection,
                    "Health Text",
                    "adv_healthtext",
                    Config.ESP.HealthBar.ShowText,
                    function(Value)
                        Config.ESP.HealthBar.ShowText =
                            Value
                    end
                )

                AddDropdown(
                    AdvancedSection,
                    "Health Position",
                    "adv_healthpos",
                    Config.ESP.HealthBar.Position,
                    {
                        "Left",
                        "Right",
                    },
                    function(Value)
                        Config.ESP.HealthBar.Position =
                            Value
                    end
                )

                AddToggle(
                    AdvancedSection,
                    "Skeleton",
                    "adv_skeleton",
                    Config.ESP.Skeleton.Enabled,
                    function(Value)
                        Config.ESP.Skeleton.Enabled =
                            Value

                        AdvancedESP.Refresh()
                    end
                )

                AddToggle(
                    AdvancedSection,
                    "Flags",
                    "adv_flags",
                    Config.ESP.Flags.Enabled,
                    function(Value)
                        Config.ESP.Flags.Enabled =
                            Value

                        AdvancedESP.Refresh()
                    end
                )

                AddToggle(
                    AdvancedSection,
                    "Offscreen Arrows",
                    "adv_arrows",
                    Config.ESP.OffScreenArrows.Enabled,
                    function(Value)
                        Config.ESP.OffScreenArrows.Enabled =
                            Value

                        AdvancedESP.Refresh()
                    end
                )

                AddSlider(
                    AdvancedSection,
                    "Arrow Radius",
                    "adv_arrow_radius",
                    Config.ESP.OffScreenArrows.OrbitRadius,
                    50,
                    350,
                    0,
                    function(Value)
                        Config.ESP.OffScreenArrows.OrbitRadius =
                            Value
                    end
                )

                AddToggle(
                    AdvancedSection,
                    "Chams",
                    "adv_chams",
                    Config.ESP.Chams.Enabled,
                    function(Value)
                        Config.ESP.Chams.Enabled =
                            Value

                        AdvancedESP.Refresh()
                    end
                )

                AddToggle(
                    AdvancedSection,
                    "Chams Always On Top",
                    "adv_chams_top",
                    Config.ESP.Chams.AlwaysOnTop,
                    function(Value)
                        Config.ESP.Chams.AlwaysOnTop =
                            Value
                    end
                )

                AddToggle(
                    AdvancedSection,
                    "Advanced Text",
                    "adv_text",
                    Config.ESP.AdvancedText.Enabled,
                    function(Value)
                        Config.ESP.AdvancedText.Enabled =
                            Value

                        AdvancedESP.Refresh()
                    end
                )

                local AdvancedColorsSection =
                    PlayersTab:
                        AddSection({
                            Name =
                                "Advanced Colors",

                            Position =
                                "right",
                        })

                AddColorPicker(
                    AdvancedColorsSection,
                    "Outline",
                    "adv_outline_color",
                    Config.ESP.OutlineColor,
                    function(Value)
                        Config.ESP.OutlineColor =
                            Value
                    end
                )

                AddColorPicker(
                    AdvancedColorsSection,
                    "Skeleton",
                    "adv_skeleton_color",
                    Config.ESP.Skeleton.Color,
                    function(Value)
                        Config.ESP.Skeleton.Color =
                            Value
                    end
                )

                AddColorPicker(
                    AdvancedColorsSection,
                    "Arrow",
                    "adv_arrow_color",
                    Config.ESP.OffScreenArrows.Color,
                    function(Value)
                        Config.ESP.OffScreenArrows.Color =
                            Value
                    end
                )

                AddColorPicker(
                    AdvancedColorsSection,
                    "Chams Fill",
                    "adv_chams_fill",
                    Config.ESP.Chams.FillColor,
                    function(Value)
                        Config.ESP.Chams.FillColor =
                            Value
                    end
                )

                AddColorPicker(
                    AdvancedColorsSection,
                    "Chams Outline",
                    "adv_chams_outline",
                    Config.ESP.Chams.OutlineColor,
                    function(Value)
                        Config.ESP.Chams.OutlineColor =
                            Value
                    end
                )

                AddSlider(
                    AdvancedColorsSection,
                    "Chams Fill Transparency",
                    "adv_chams_fill_trans",
                    Config.ESP.Chams.FillTransparency,
                    0,
                    1,
                    2,
                    function(Value)
                        Config.ESP.Chams.FillTransparency =
                            Value
                    end
                )

                AddDropdown(
                    AdvancedColorsSection,
                    "Advanced Text Position",
                    "adv_text_position",
                    Config.ESP.AdvancedText.Position,
                    {
                        "Bottom",
                        "Top",
                        "Side",
                    },
                    function(Value)
                        Config.ESP.AdvancedText.Position =
                            Value
                    end
                )

                -----------------------------------------------------
                -- PLAYER TOOLS
                -----------------------------------------------------

                local PlayerToolsSection =
                    PlayersTab:
                        AddSection({
                            Name =
                                "Player Tools",

                            Position =
                                "right",
                        })

                local EmptyPlayerValue =
                    "<no players>"

                local PlayerValues =
                    PlayerTools.GetPlayerNames()

                if #PlayerValues == 0 then
                    PlayerValues = {
                        EmptyPlayerValue,
                    }
                end

                local InitialPlayer =
                    tostring(
                        Config.PlayerTools.SelectedName
                        or ""
                    )

                if
                    InitialPlayer == ""
                    or not table.find(
                        PlayerValues,
                        InitialPlayer
                    )
                then
                    InitialPlayer =
                        PlayerValues[1]
                end

                if
                    InitialPlayer
                    ~= EmptyPlayerValue
                then
                    PlayerTools.Select(
                        InitialPlayer
                    )
                end

                local PlayerDropdown =
                    AddDropdown(
                        PlayerToolsSection,
                        "Target",
                        "player_tools_target",
                        InitialPlayer,
                        PlayerValues,
                        function(Value)
                            if
                                Value
                                == EmptyPlayerValue
                            then
                                Config.PlayerTools.SelectedName =
                                    ""
                            else
                                PlayerTools.Select(
                                    Value
                                )
                            end
                        end
                    )

                local PlayerInfoName =
                    PlayerToolsSection:
                        AddLabel(
                            "Name: -",
                            true
                        )

                local PlayerInfoHealth =
                    PlayerToolsSection:
                        AddLabel(
                            "Health: -",
                            true
                        )

                local PlayerInfoDistance =
                    PlayerToolsSection:
                        AddLabel(
                            "Distance: -",
                            true
                        )

                local PlayerInfoFriend =
                    PlayerToolsSection:
                        AddLabel(
                            "Friend: -",
                            true
                        )

                local PlayerInfoVisible =
                    PlayerToolsSection:
                        AddLabel(
                            "Visible: -",
                            true
                        )

                local PlayerInfoTeam =
                    PlayerToolsSection:
                        AddLabel(
                            "Team: -",
                            true
                        )

                local SpectateStatus =
                    PlayerToolsSection:
                        AddLabel(
                            "Spectate: OFF",
                            true
                        )

                local function RefreshPlayerValues()
                    local Names =
                        PlayerTools.GetPlayerNames()

                    local Values =
                        Names

                    if #Values == 0 then
                        Values = {
                            EmptyPlayerValue,
                        }
                    end

                    PlayerDropdown:
                        SetValues(
                            Values
                        )

                    local Selected =
                        Config.PlayerTools.SelectedName

                    if
                        Selected == ""
                        or not table.find(
                            Names,
                            Selected
                        )
                    then
                        Selected =
                            Names[1]
                            or EmptyPlayerValue
                    end

                    PlayerDropdown:
                        SetValue(
                            Selected
                        )

                    if
                        Selected
                        ~= EmptyPlayerValue
                    then
                        PlayerTools.Select(
                            Selected
                        )
                    else
                        Config.PlayerTools.SelectedName =
                            ""
                    end
                end

                PlayerToolsSection:
                    AddButton({
                        Icon =
                            "arrow-rotate-right",

                        Name =
                            "Refresh Players",

                        Callback =
                            RefreshPlayerValues,
                    })

                PlayerToolsSection:
                    AddButton({
                        Icon =
                            "eye",

                        Name =
                            "Spectate",

                        Callback =
                            function()
                                local Ok,
                                    Message =
                                        PlayerTools.Spectate()

                                if not Ok then
                                    SpectateStatus:
                                        SetText(
                                            "Spectate: "
                                            .. tostring(
                                                Message
                                            )
                                        )
                                end
                            end,
                    })

                PlayerToolsSection:
                    AddButton({
                        Icon =
                            "x",

                        Name =
                            "Stop Spectate",

                        Callback =
                            function()
                                PlayerTools.StopSpectate()
                            end,
                    })

                PlayerTools.SetStateChangedCallback(
                    function(
                        EventName,
                        Value
                    )
                        if Destroyed then
                            return
                        end

                        if
                            EventName
                            == "Spectate"
                        then
                            SpectateStatus:
                                SetText(
                                    Value
                                    and (
                                        "Spectate: "
                                        .. Value.Name
                                    )
                                    or "Spectate: OFF"
                                )
                        end
                    end
                )

                Threads.PlayerInfo =
                    task.spawn(function()
                        local ListTimer =
                            0

                        while not Destroyed do
                            task.wait(0.5)

                            if Destroyed then
                                break
                            end

                            ListTimer +=
                                0.5

                            if ListTimer >= 2 then
                                ListTimer =
                                    0

                                pcall(
                                    RefreshPlayerValues
                                )
                            end

                            local Info =
                                PlayerTools.GetInfo()

                            if Info then
                                PlayerInfoName:
                                    SetText(
                                        "Name: "
                                        .. Info.Name
                                        .. " (@"
                                        .. Info.DisplayName
                                        .. ")"
                                    )

                                PlayerInfoHealth:
                                    SetText(
                                        string.format(
                                            "Health: %d/%d",
                                            math.floor(
                                                Info.Health
                                            ),
                                            math.floor(
                                                Info.MaxHealth
                                            )
                                        )
                                    )

                                PlayerInfoDistance:
                                    SetText(
                                        "Distance: "
                                        .. (
                                            Info.Distance
                                            and (
                                                tostring(
                                                    math.floor(
                                                        Info.Distance
                                                        + 0.5
                                                    )
                                                )
                                                .. " studs"
                                            )
                                            or "-"
                                        )
                                    )

                                PlayerInfoFriend:
                                    SetText(
                                        "Friend: "
                                        .. (
                                            Info.Friend
                                            and "yes"
                                            or "no"
                                        )
                                    )

                                PlayerInfoVisible:
                                    SetText(
                                        "Visible: "
                                        .. (
                                            Info.Visible
                                            and "yes"
                                            or "no"
                                        )
                                    )

                                PlayerInfoTeam:
                                    SetText(
                                        "Team: "
                                        .. tostring(
                                            Info.Team
                                        )
                                    )
                            else
                                PlayerInfoName:
                                    SetText(
                                        "Name: -"
                                    )

                                PlayerInfoHealth:
                                    SetText(
                                        "Health: -"
                                    )

                                PlayerInfoDistance:
                                    SetText(
                                        "Distance: -"
                                    )

                                PlayerInfoFriend:
                                    SetText(
                                        "Friend: -"
                                    )

                                PlayerInfoVisible:
                                    SetText(
                                        "Visible: -"
                                    )

                                PlayerInfoTeam:
                                    SetText(
                                        "Team: -"
                                    )
                            end
                        end
                    end)

                -----------------------------------------------------
                -- COMBAT / AIM ASSIST
                -----------------------------------------------------

                local CombatTab =
                    Window:AddTab({
                        Icon =
                            "crosshairs",

                        Name =
                            "Combat",

                        Type =
                            "Double",
                    })

                local AimSection =
                    CombatTab:
                        AddSection({
                            Name =
                                "Aim Assist",

                            Position =
                                "left",
                        })

                AddToggle(
                    AimSection,
                    "Enabled",
                    "aim_enabled",
                    Config.AimAssist.Enabled,
                    function(Value)
                        AimAssist.SetEnabled(
                            Value
                        )
                    end
                )

                AddKeybind(
                    AimSection,
                    "Keybind",
                    "aim_keybind",
                    Config.AimAssist.Keybind,
                    function(Value)
                        Config.AimAssist.Keybind =
                            Value
                    end
                )

                AddToggle(
                    AimSection,
                    "Hold Mode",
                    "aim_hold",
                    Config.AimAssist.Hold,
                    function(Value)
                        Config.AimAssist.Hold =
                            Value

                        AimAssist.SetHeld(
                            false
                        )
                    end
                )

                AddDropdown(
                    AimSection,
                    "Target Part",
                    "aim_target_part",
                    Config.AimAssist.TargetPart,
                    {
                        "Head",
                        "HumanoidRootPart",
                        "UpperTorso",
                        "Torso",
                    },
                    function(Value)
                        Config.AimAssist.TargetPart =
                            Value
                    end
                )

                AddSlider(
                    AimSection,
                    "FOV",
                    "aim_fov",
                    Config.AimAssist.FOV,
                    20,
                    500,
                    0,
                    function(Value)
                        Config.AimAssist.FOV =
                            Value
                    end
                )

                AddSlider(
                    AimSection,
                    "Max Distance",
                    "aim_distance",
                    Config.AimAssist.MaxDistance,
                    50,
                    3000,
                    0,
                    function(Value)
                        Config.AimAssist.MaxDistance =
                            Value
                    end
                )

                AddSlider(
                    AimSection,
                    "Responsiveness",
                    "aim_response",
                    Config.AimAssist.Responsiveness,
                    1,
                    40,
                    0,
                    function(Value)
                        Config.AimAssist.Responsiveness =
                            Value
                    end
                )

                local AimFiltersSection =
                    CombatTab:
                        AddSection({
                            Name =
                                "Aim Filters",

                            Position =
                                "right",
                        })

                AddToggle(
                    AimFiltersSection,
                    "Team Check",
                    "aim_team",
                    Config.AimAssist.TeamCheck,
                    function(Value)
                        Config.AimAssist.TeamCheck =
                            Value
                    end
                )

                AddToggle(
                    AimFiltersSection,
                    "Visibility Check",
                    "aim_visibility",
                    Config.AimAssist.VisibilityCheck,
                    function(Value)
                        Config.AimAssist.VisibilityCheck =
                            Value
                    end
                )

                AddToggle(
                    AimFiltersSection,
                    "Show FOV",
                    "aim_show_fov",
                    Config.AimAssist.ShowFOV,
                    function(Value)
                        Config.AimAssist.ShowFOV =
                            Value
                    end
                )

                AddColorPicker(
                    AimFiltersSection,
                    "FOV Color",
                    "aim_fov_color",
                    Config.AimAssist.FOVColor,
                    function(Value)
                        Config.AimAssist.FOVColor =
                            Value
                    end
                )

                local AimStatus =
                    AimFiltersSection:
                        AddLabel(
                            "Target: -",
                            true
                        )

                local AimActiveStatus =
                    AimFiltersSection:
                        AddLabel(
                            "Active: OFF",
                            true
                        )

                AimAssist.SetStateChangedCallback(
                    function(
                        Active,
                        Target
                    )
                        if Destroyed then
                            return
                        end

                        AimActiveStatus:
                            SetText(
                                Active
                                and "Active: ON"
                                or "Active: OFF"
                            )

                        AimStatus:
                            SetText(
                                "Target: "
                                .. (
                                    Target
                                    and Target.Name
                                    or "-"
                                )
                            )
                    end
                )

                -----------------------------------------------------
                -- CORPSES
                -----------------------------------------------------

                local CorpsesTab =
                    Window:AddTab({
                        Icon =
                            "crosshairs",

                        Name =
                            "Corpses",

                        Type =
                            "Double",
                    })

                local CorpsesSection =
                    CorpsesTab:
                        AddSection({
                            Name =
                                "Corpse ESP",

                            Position =
                                "left",
                        })

                AddToggle(
                    CorpsesSection,
                    "Enabled",
                    "corpses_enabled",
                    Config.Corpses.Enabled,
                    function(Value)
                        Config.Corpses.Enabled =
                            Value
                    end
                )

                AddToggle(
                    CorpsesSection,
                    "Box",
                    "corpses_box",
                    Config.Corpses.Box,
                    function(Value)
                        Config.Corpses.Box =
                            Value
                    end
                )

                AddToggle(
                    CorpsesSection,
                    "Name",
                    "corpses_name",
                    Config.Corpses.Name,
                    function(Value)
                        Config.Corpses.Name =
                            Value
                    end
                )

                AddToggle(
                    CorpsesSection,
                    "Distance",
                    "corpses_distance",
                    Config.Corpses.Distance,
                    function(Value)
                        Config.Corpses.Distance =
                            Value
                    end
                )

                AddSlider(
                    CorpsesSection,
                    "Max Corpses",
                    "corpses_max_corpses",
                    Config.Corpses.MaxCorpses,
                    1,
                    30,
                    0,
                    function(Value)
                        Config.Corpses.MaxCorpses =
                            Value
                    end
                )

                local CorpseAppearanceSection =
                    CorpsesTab:
                        AddSection({
                            Name =
                                "Appearance",

                            Position =
                                "right",
                        })

                AddDropdown(
                    CorpseAppearanceSection,
                    "Box Style",
                    "corpses_box_style",
                    Config.Corpses.BoxStyle,
                    {
                        "Corner",
                        "Full",
                    },
                    function(Value)
                        Config.Corpses.BoxStyle =
                            Value
                    end
                )

                AddColorPicker(
                    CorpseAppearanceSection,
                    "Corpse Color",
                    "corpses_color",
                    Config.Corpses.Color,
                    function(Value)
                        Config.Corpses.Color =
                            Value
                    end
                )

                AddColorPicker(
                    CorpseAppearanceSection,
                    "Text Color",
                    "corpses_text_color",
                    Config.Corpses.TextColor,
                    function(Value)
                        Config.Corpses.TextColor =
                            Value
                    end
                )

                AddSlider(
                    CorpseAppearanceSection,
                    "Box Thickness",
                    "corpses_box_thickness",
                    Config.Corpses.BoxThickness,
                    1,
                    4,
                    0,
                    function(Value)
                        Config.Corpses.BoxThickness =
                            Value
                    end
                )

                AddSlider(
                    CorpseAppearanceSection,
                    "Corner Size",
                    "corpses_corner_ratio",
                    Config.Corpses.CornerRatio,
                    0.10,
                    0.50,
                    2,
                    function(Value)
                        Config.Corpses.CornerRatio =
                            Value
                    end
                )

                AddSlider(
                    CorpseAppearanceSection,
                    "Box Padding",
                    "corpses_box_padding",
                    Config.Corpses.BoxPadding,
                    0,
                    10,
                    0,
                    function(Value)
                        Config.Corpses.BoxPadding =
                            Value
                    end
                )

                AddSlider(
                    CorpseAppearanceSection,
                    "Max Distance",
                    "corpses_max_distance",
                    Config.Corpses.MaxDistance,
                    50,
                    3000,
                    0,
                    function(Value)
                        Config.Corpses.MaxDistance =
                            Value
                    end
                )

                -----------------------------------------------------
                -- MOVEMENT / FREECAM + CHARACTER FEATURES
                -----------------------------------------------------

                local MovementTab =
                    Window:AddTab({
                        Icon =
                            "camera",

                        Name =
                            "Movement",

                        Type =
                            "Double",
                    })

                local FreecamSection =
                    MovementTab:
                        AddSection({
                            Name =
                                "Freecam",

                            Position =
                                "left",
                        })

                local FreecamStatus =
                    FreecamSection:
                        AddLabel(
                            "Status: OFF",
                            true
                        )

                local function SetFreecamStatus(
                    IsEnabled
                )
                    if Destroyed then
                        return
                    end

                    FreecamStatus:
                        SetText(
                            IsEnabled
                            and "Status: ON"
                            or "Status: OFF"
                        )
                end

                Freecam.SetStateChangedCallback(
                    SetFreecamStatus
                )

                FreecamSection:
                    AddButton({
                        Icon =
                            "camera",

                        Name =
                            "Toggle Freecam",

                        ToolTip =
                            "Enters or leaves freecam. On normal exit the character can move to the final camera position.",

                        Callback =
                            function()
                                local Ok,
                                    Message =
                                        Freecam.Toggle()

                                if not Ok then
                                    FreecamStatus:
                                        SetText(
                                            "Status: error - "
                                            .. tostring(
                                                Message
                                            )
                                        )
                                end
                            end,
                    })

                AddKeybind(
                    FreecamSection,
                    "Freecam Key",
                    "freecam_keybind",
                    Config.Freecam.Keybind
                        or "V",
                    function(Value)
                        Config.Freecam.Keybind =
                            Freecam.SetKeybind(
                                Value
                            )
                    end
                )

                AddSlider(
                    FreecamSection,
                    "Speed",
                    "freecam_speed",
                    Config.Freecam.Speed,
                    10,
                    200,
                    0,
                    function(Value)
                        Freecam.SetSpeed(
                            Value
                        )
                    end
                )

                AddSlider(
                    FreecamSection,
                    "Boost",
                    "freecam_boost",
                    Config.Freecam.BoostMultiplier,
                    1,
                    6,
                    1,
                    function(Value)
                        Freecam.SetBoostMultiplier(
                            Value
                        )
                    end
                )

                AddSlider(
                    FreecamSection,
                    "Mouse Sensitivity",
                    "freecam_sensitivity",
                    Config.Freecam.MouseSensitivity,
                    0.03,
                    0.50,
                    2,
                    function(Value)
                        Freecam.SetMouseSensitivity(
                            Value
                        )
                    end
                )

                local FreecamBehaviorSection =
                    MovementTab:
                        AddSection({
                            Name =
                                "Recovered Behavior",

                            Position =
                                "right",
                        })

                FreecamBehaviorSection:
                    AddLabel(
                        "Scriptable camera only",
                        true
                    )

                FreecamBehaviorSection:
                    AddLabel(
                        "Character stays in place",
                        true
                    )

                FreecamBehaviorSection:
                    AddLabel(
                        "WASD: move",
                        true
                    )

                FreecamBehaviorSection:
                    AddLabel(
                        "Space / Ctrl: up / down",
                        true
                    )

                FreecamBehaviorSection:
                    AddLabel(
                        "Shift: boost",
                        true
                    )

                FreecamBehaviorSection:
                    AddLabel(
                        "Mouse: look",
                        true
                    )

                local CharacterSection =
                    MovementTab:
                        AddSection({
                            Name =
                                "Character",

                            Position =
                                "left",
                        })

                local SyncingCharacterToggles =
                    false

                local ZoomStatus =
                    CharacterSection:
                        AddLabel(
                            "Zoom: OFF",
                            true
                        )

                local NoclipStatus =
                    CharacterSection:
                        AddLabel(
                            "Noclip: OFF",
                            true
                        )

                local InvisibleStatus =
                    CharacterSection:
                        AddLabel(
                            "Invisible: OFF",
                            true
                        )

                local ZoomToggle =
                    AddToggle(
                        CharacterSection,
                        "Zoom",
                        "feature_zoom",
                        Config.Zoom.Enabled,
                        function(Value)
                            if SyncingCharacterToggles then
                                return
                            end

                            CharacterFeatures.SetZoom(
                                Value
                            )
                        end
                    )

                AddKeybind(
                    CharacterSection,
                    "Zoom Key",
                    "zoom_key",
                    Config.Zoom.Keybind,
                    function(Value)
                        Config.Zoom.Keybind =
                            Value
                    end
                )

                AddSlider(
                    CharacterSection,
                    "Zoom FOV",
                    "zoom_fov",
                    Config.Zoom.FOV,
                    5,
                    70,
                    0,
                    function(Value)
                        Config.Zoom.FOV =
                            Value

                        if
                            Config.Zoom.Enabled
                            == true
                        then
                            CharacterFeatures.SetZoom(
                                false
                            )

                            CharacterFeatures.SetZoom(
                                true
                            )
                        end
                    end
                )

                local NoclipToggle =
                    AddToggle(
                        CharacterSection,
                        "Noclip",
                        "feature_noclip",
                        Config.Noclip.Enabled,
                        function(Value)
                            if SyncingCharacterToggles then
                                return
                            end

                            CharacterFeatures.SetNoclip(
                                Value
                            )
                        end
                    )

                AddKeybind(
                    CharacterSection,
                    "Noclip Key",
                    "noclip_key",
                    Config.Noclip.Keybind,
                    function(Value)
                        Config.Noclip.Keybind =
                            Value
                    end
                )

                local InvisibleToggle =
                    AddToggle(
                        CharacterSection,
                        "Invisible (local)",
                        "feature_invisible",
                        Config.Invisible.Enabled,
                        function(Value)
                            if SyncingCharacterToggles then
                                return
                            end

                            CharacterFeatures.SetInvisible(
                                Value
                            )
                        end
                    )

                AddKeybind(
                    CharacterSection,
                    "Invisible Key",
                    "invisible_key",
                    Config.Invisible.Keybind,
                    function(Value)
                        Config.Invisible.Keybind =
                            Value
                    end
                )

                CharacterFeatures.SetStateChangedCallback(
                    function(
                        Feature,
                        Enabled
                    )
                        if Destroyed then
                            return
                        end

                        SyncingCharacterToggles =
                            true

                        if Feature == "Zoom" then
                            ZoomStatus:
                                SetText(
                                    Enabled
                                    and "Zoom: ON"
                                    or "Zoom: OFF"
                                )

                            if
                                ZoomToggle
                                and type(
                                    ZoomToggle.SetValue
                                ) == "function"
                            then
                                pcall(
                                    ZoomToggle.SetValue,
                                    ZoomToggle,
                                    Enabled
                                )
                            end

                        elseif Feature == "Noclip" then
                            NoclipStatus:
                                SetText(
                                    Enabled
                                    and "Noclip: ON"
                                    or "Noclip: OFF"
                                )

                            if
                                NoclipToggle
                                and type(
                                    NoclipToggle.SetValue
                                ) == "function"
                            then
                                pcall(
                                    NoclipToggle.SetValue,
                                    NoclipToggle,
                                    Enabled
                                )
                            end

                        elseif Feature == "Invisible" then
                            InvisibleStatus:
                                SetText(
                                    Enabled
                                    and "Invisible: ON"
                                    or "Invisible: OFF"
                                )

                            if
                                InvisibleToggle
                                and type(
                                    InvisibleToggle.SetValue
                                ) == "function"
                            then
                                pcall(
                                    InvisibleToggle.SetValue,
                                    InvisibleToggle,
                                    Enabled
                                )
                            end
                        end

                        SyncingCharacterToggles =
                            false
                    end
                )

                -----------------------------------------------------
                -- SETTINGS
                -----------------------------------------------------

                local SettingsTab =
                    Window:AddTab({
                        Icon =
                            "gear",

                        Name =
                            "Settings",

                        Type =
                            "Single",
                    })

                local InterfaceSection =
                    SettingsTab:
                        AddSection({
                            Name =
                                "Interface",

                            Position =
                                "left",
                        })

                AddToggle(
                    InterfaceSection,
                    "Watermark",
                    "ui_watermark",
                    Config.UI.Watermark
                        ~= false,
                    function(Value)
                        Config.UI.Watermark =
                            Value

                        Watermark:
                            SetRender(
                                Value
                            )
                    end
                )

                AddKeybind(
                    InterfaceSection,
                    "Menu Key",
                    "ui_menu_key",
                    Config.UI.Keybind
                        or "LeftAlt",
                    function(Value)
                        Config.UI.Keybind =
                            Value

                        Window.Keybind =
                            Value
                    end
                )

                local DiagnosticsSection =
                    SettingsTab:
                        AddSection({
                            Name =
                                "Diagnostics",

                            Position =
                                "right",
                        })

                AddToggle(
                    DiagnosticsSection,
                    "Profiler",
                    "profiler_enabled",
                    Config.Profiler.Enabled,
                    function(Value)
                        Config.Profiler.Enabled =
                            Value
                    end
                )

                AddToggle(
                    DiagnosticsSection,
                    "Profiler Overlay",
                    "profiler_overlay",
                    Config.Profiler.Overlay,
                    function(Value)
                        Config.Profiler.Overlay =
                            Value
                    end
                )

                AddSlider(
                    DiagnosticsSection,
                    "Report Interval",
                    "profiler_report_interval",
                    Config.Profiler.ReportInterval,
                    0.5,
                    3,
                    1,
                    function(Value)
                        Config.Profiler.ReportInterval =
                            Value
                    end
                )

                DiagnosticsSection:
                    AddLabel(
                        "Measures Newz CPU-side work only",
                        true
                    )

                local IntegrationsSection =
                    SettingsTab:
                        AddSection({
                            Name =
                                "Integrations",

                            Position =
                                "right",
                        })

                local SensoryStatus =
                    IntegrationsSection:
                        AddLabel(
                            "sensoryESP: OFF",
                            true
                        )

                AddToggle(
                    IntegrationsSection,
                    "Remote sensoryESP",
                    "external_sensory_esp",
                    Config.ExternalESP.Enabled == true,
                    function(Value)
                        local Ok, Message =
                            SensoryESP.SetEnabled(
                                Value
                            )

                        if not Ok then
                            SensoryStatus:
                                SetText(
                                    "sensoryESP: error - "
                                    .. tostring(Message)
                                )
                        end
                    end
                )

                SensoryESP.SetStateChangedCallback(
                    function(Loaded, ErrorMessage)
                        if Destroyed then
                            return
                        end

                        if ErrorMessage then
                            SensoryStatus:
                                SetText(
                                    "sensoryESP: error - "
                                    .. tostring(ErrorMessage)
                                )
                        else
                            SensoryStatus:
                                SetText(
                                    Loaded
                                    and "sensoryESP: ON"
                                    or "sensoryESP: OFF"
                                )
                        end
                    end
                )

                IntegrationsSection:
                    AddButton({
                        Name =
                            "Refresh sensoryESP",

                        Callback =
                            function()
                                local Ok, Message =
                                    SensoryESP.Refresh()

                                SensoryStatus:
                                    SetText(
                                        Ok
                                        and "sensoryESP: refreshed"
                                        or "sensoryESP: " .. tostring(Message)
                                    )
                            end,
                    })

                local RemoteStatus =
                    IntegrationsSection:
                        AddLabel(
                            "FireServer bridge: OFF",
                            true
                        )

                AddToggle(
                    IntegrationsSection,
                    "Configured FireServer bridge",
                    "remote_bridge_enabled",
                    Config.RemoteBridge.Enabled == true,
                    function(Value)
                        RemoteBridge.SetEnabled(
                            Value
                        )

                        RemoteStatus:
                            SetText(
                                Value
                                and "FireServer bridge: ON"
                                or "FireServer bridge: OFF"
                            )
                    end
                )

                IntegrationsSection:
                    AddButton({
                        Name =
                            "Fire Test Event",

                        ToolTip =
                            "Calls only the RemoteEvent path configured in Config.RemoteBridge.",

                        Callback =
                            function()
                                local Ok, Message =
                                    RemoteBridge.FireTest()

                                RemoteStatus:
                                    SetText(
                                        Ok
                                        and "FireServer bridge: sent"
                                        or "FireServer bridge: " .. tostring(Message)
                                    )
                            end,
                    })

                IntegrationsSection:
                    AddLabel(
                        "Stellar remote loader: not included",
                        true
                    )

                local ProjectSection =
                    SettingsTab:
                        AddSection({
                            Name =
                                "Project",

                            Position =
                                "left",
                        })

                ProjectSection:
                    AddLabel(
                        "Name: "
                        .. tostring(
                            Config.Project.Name
                        ),
                        true
                    )

                ProjectSection:
                    AddLabel(
                        "Version: "
                        .. tostring(
                            Config.Project.Version
                        ),
                        true
                    )

                ProjectSection:
                    AddLabel(
                        "Runtime: ESP + Advanced ESP + Combat + Player Tools + Movement + Integrations",
                        true
                    )

                local Controller = {
                    Window =
                        Window,

                    Library =
                        NeverLose,
                }

                function Controller.Destroy()
                    Cleanup()
                end

                return Controller
            end, Traceback)

    if not Success then
        Cleanup()

        error(
            "Falha ao inicializar UI:\n"
            .. tostring(Result),
            0
        )
    end

    return Result
end

return UI
