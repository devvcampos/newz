local UI = {}

local function Traceback(Error)
    if debug and type(debug.traceback) == "function" then
        return debug.traceback(tostring(Error), 2)
    end

    return tostring(Error)
end

function UI.Init(Config, Dependencies)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    assert(LocalPlayer, "UI precisa ser inicializada no cliente")
    assert(
        type(Dependencies) == "table"
        and type(Dependencies.NeverLose) == "table",
        "UI.Init precisa receber Dependencies.NeverLose"
    )

    local NeverLose = Dependencies.NeverLose
    local CorpseIllusion = Dependencies.CorpseIllusion

    assert(
        type(NeverLose.CreateWindow) == "function",
        "NeverLose invalida"
    )

    assert(
        type(CorpseIllusion) == "table"
        and type(CorpseIllusion.GetCorpseNames) == "function"
        and type(CorpseIllusion.Show) == "function"
        and type(CorpseIllusion.Clear) == "function"
        and type(CorpseIllusion.GoTo) == "function"
        and type(CorpseIllusion.ReturnToPreviousPosition) == "function",
        "CorpseIllusion invalido"
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

        for _, Thread in pairs(Threads) do
            if typeof(Thread) == "thread" then
                pcall(task.cancel, Thread)
            end
        end

        table.clear(Threads)

        if Window and Window.ConfigManager then
            local ConfigManager = Window.ConfigManager

            if ConfigManager.UnsafeThread then
                pcall(function()
                    ConfigManager.UnsafeThread:Disconnect()
                end)

                ConfigManager.UnsafeThread = nil
            end
        end

        if NeverLose and type(NeverLose.Unload) == "function" then
            pcall(function()
                NeverLose:Unload()
            end)
        end
    end

    local Success, Result = xpcall(function()
        NeverLose.UnloadEnabled = true

        if Config.UI.AccentColor then
            NeverLose.AccentColor = Config.UI.AccentColor
        end

        local ConfigDirectory = tostring(Config.UI.ConfigDirectory or "newz")
        local ConfigFolderName = tostring(Config.UI.ConfigFolder or "Configs")
        local ConfigFolder = ConfigDirectory .. "/" .. ConfigFolderName

        Window = NeverLose:CreateWindow({
            Name = Config.Project.Name,
            Content = "Entity Diagnostics  •  v" .. tostring(Config.Project.Version),
            Size = NeverLose.Scales.Default,
            ConfigFolder = ConfigFolder,
            Enable3DRenderer = false,
            Keybind = Config.UI.Keybind or "LeftAlt",
        })

        assert(Window, "NeverLose.CreateWindow falhou")

        Window:SetAccount({
            Username = LocalPlayer.DisplayName,
            Expires = "DEV",
        })

        Watermark = Window:Watermark()
        Watermark:AddBlock("eye", Config.Project.Name)
        Watermark:AddBlock("user", LocalPlayer.Name)

        local WatermarkPlayers =
            Watermark:AddBlock(
                "users",
                "Players: " .. tostring(#Players:GetPlayers())
            )

        Watermark:SetRender(Config.UI.Watermark ~= false)

        Threads.Watermark = task.spawn(function()
            while not Destroyed do
                task.wait(1.5)

                if Destroyed then
                    break
                end

                WatermarkPlayers:SetText(
                    "Players: " .. tostring(#Players:GetPlayers())
                )
            end
        end)

        local function AddToggle(Section, Name, Flag, Default, Callback)
            return Section:AddLabel(Name):AddToggle({
                Flag = Flag,
                Default = Default,
                Callback = Callback,
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
            return Section:AddLabel(Name):AddSlider({
                Flag = Flag,
                Default = Default,
                Min = Min,
                Max = Max,
                Rounding = Rounding,
                Callback = Callback,
            })
        end

        local function AddColorPicker(Section, Name, Flag, Default, Callback)
            return Section:AddLabel(Name):AddColorPicker({
                Flag = Flag,
                Default = Default,
                Callback = Callback,
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
            return Section:AddLabel(Name):AddDropdown({
                Flag = Flag,
                Default = Default,
                Values = Values,
                Multi = false,
                Callback = Callback,
            })
        end

        -----------------------------------------------------
        -- PLAYERS
        -----------------------------------------------------

        local PlayersTab = Window:AddTab({
            Icon = "crosshairs",
            Name = "Players",
            Type = "Double",
        })

        local ESPSection = PlayersTab:AddSection({
            Name = "ESP",
            Position = "left",
        })

        AddToggle(ESPSection, "Enabled", "esp_enabled", Config.ESP.Enabled, function(Value)
            Config.ESP.Enabled = Value
        end)

        AddToggle(ESPSection, "Box", "esp_box", Config.ESP.Box, function(Value)
            Config.ESP.Box = Value
        end)

        AddToggle(ESPSection, "Name", "esp_name", Config.ESP.Name, function(Value)
            Config.ESP.Name = Value
        end)

        AddToggle(ESPSection, "Health", "esp_health", Config.ESP.Health, function(Value)
            Config.ESP.Health = Value
        end)

        AddToggle(ESPSection, "Weapon", "esp_weapon", Config.ESP.Weapon, function(Value)
            Config.ESP.Weapon = Value
        end)

        AddToggle(ESPSection, "Distance", "esp_distance", Config.ESP.Distance, function(Value)
            Config.ESP.Distance = Value
        end)

        local FiltersSection = PlayersTab:AddSection({
            Name = "Filters",
            Position = "left",
        })

        AddToggle(
            FiltersSection,
            "Visibility Check",
            "esp_visibility",
            Config.ESP.VisibilityCheck,
            function(Value)
                Config.ESP.VisibilityCheck = Value
            end
        )

        AddToggle(
            FiltersSection,
            "Team Check",
            "esp_team_check",
            Config.ESP.TeamCheck,
            function(Value)
                Config.ESP.TeamCheck = Value
            end
        )

        AddToggle(
            FiltersSection,
            "Dynamic Health Color",
            "esp_dynamic_health",
            Config.ESP.DynamicHealthColor,
            function(Value)
                Config.ESP.DynamicHealthColor = Value
            end
        )

        local AppearanceSection = PlayersTab:AddSection({
            Name = "Appearance",
            Position = "right",
        })

        AddDropdown(
            AppearanceSection,
            "Box Style",
            "esp_box_style",
            Config.ESP.BoxStyle,
            { "Corner", "Full" },
            function(Value)
                Config.ESP.BoxStyle = Value
            end
        )

        AddColorPicker(
            AppearanceSection,
            "Visible Color",
            "esp_visible_color",
            Config.ESP.VisibleColor,
            function(Value)
                Config.ESP.VisibleColor = Value
            end
        )

        AddColorPicker(
            AppearanceSection,
            "Hidden Color",
            "esp_hidden_color",
            Config.ESP.HiddenColor,
            function(Value)
                Config.ESP.HiddenColor = Value
            end
        )

        AddColorPicker(
            AppearanceSection,
            "Text Color",
            "esp_text_color",
            Config.ESP.TextColor,
            function(Value)
                Config.ESP.TextColor = Value
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
                Config.ESP.BoxThickness = Value
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
                Config.ESP.CornerRatio = Value
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
                Config.ESP.BoxPadding = Value
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
                Config.ESP.MaxDistance = Value
            end
        )

        -----------------------------------------------------
        -- CORPSES
        -----------------------------------------------------

        local CorpsesTab = Window:AddTab({
            Icon = "crosshairs",
            Name = "Corpses",
            Type = "Double",
        })

        local CorpsesSection = CorpsesTab:AddSection({
            Name = "Corpse ESP",
            Position = "left",
        })

        AddToggle(
            CorpsesSection,
            "Enabled",
            "corpses_enabled",
            Config.Corpses.Enabled,
            function(Value)
                Config.Corpses.Enabled = Value
            end
        )

        AddToggle(
            CorpsesSection,
            "Box",
            "corpses_box",
            Config.Corpses.Box,
            function(Value)
                Config.Corpses.Box = Value
            end
        )

        AddToggle(
            CorpsesSection,
            "Name",
            "corpses_name",
            Config.Corpses.Name,
            function(Value)
                Config.Corpses.Name = Value
            end
        )

        AddToggle(
            CorpsesSection,
            "Distance",
            "corpses_distance",
            Config.Corpses.Distance,
            function(Value)
                Config.Corpses.Distance = Value
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
                Config.Corpses.MaxCorpses = Value
            end
        )

        -----------------------------------------------------
        -- LOCAL ILLUSION
        -----------------------------------------------------

        local CorpseIllusionSection = CorpsesTab:AddSection({
            Name = "Corpse Actions",
            Position = "left",
        })

        local EmptyTargetValue =
            "<no corpses>"

        local InitialTargets =
            CorpseIllusion.GetCorpseNames()

        local InitialValues =
            InitialTargets

        if #InitialValues == 0 then
            InitialValues = {
                EmptyTargetValue,
            }
        end

        local InitialTarget =
            tostring(
                Config.CorpseIllusion.TargetName
                or ""
            )

        if
            InitialTarget == ""
            or not table.find(
                InitialTargets,
                InitialTarget
            )
        then
            InitialTarget =
                InitialTargets[1]
                or EmptyTargetValue
        end

        Config.CorpseIllusion.TargetName =
            InitialTarget ~= EmptyTargetValue
            and InitialTarget
            or ""

        local CorpseTargetDropdown =
            AddDropdown(
                CorpseIllusionSection,
                "Target Corpse",
                "corpse_illusion_target",
                InitialTarget,
                InitialValues,
                function(Value)
                    if
                        Value
                        == EmptyTargetValue
                    then
                        Config.CorpseIllusion.TargetName = ""
                    else
                        Config.CorpseIllusion.TargetName =
                            tostring(Value or "")
                    end
                end
            )

        AddSlider(
            CorpseIllusionSection,
            "Illusion Distance",
            "corpse_illusion_distance",
            Config.CorpseIllusion.Distance,
            2,
            20,
            0,
            function(Value)
                Config.CorpseIllusion.Distance = Value
            end
        )

        AddSlider(
            CorpseIllusionSection,
            "Teleport Distance",
            "corpse_teleport_distance",
            Config.CorpseIllusion.TeleportDistance,
            2,
            12,
            0,
            function(Value)
                Config.CorpseIllusion.TeleportDistance = Value
            end
        )

        local CorpseIllusionStatus =
            CorpseIllusionSection:AddLabel(
                "Status: ready",
                true
            )

        local function RefreshCorpseTargets()
            local Names =
                CorpseIllusion.GetCorpseNames()

            local Values =
                Names

            if #Values == 0 then
                Values = {
                    EmptyTargetValue,
                }
            end

            CorpseTargetDropdown:SetValues(
                Values
            )

            local Current =
                tostring(
                    Config.CorpseIllusion.TargetName
                    or ""
                )

            if
                Current == ""
                or not table.find(
                    Names,
                    Current
                )
            then
                Current =
                    Names[1]
                    or EmptyTargetValue
            end

            CorpseTargetDropdown:SetValue(
                Current
            )

            CorpseIllusionStatus:SetText(
                "Status: "
                .. tostring(#Names)
                .. " corpses found"
            )
        end

        CorpseIllusionSection:AddButton({
            Icon = "arrow-rotate-right",
            Name = "Refresh Corpses",
            Callback = function()
                RefreshCorpseTargets()
            end,
        })

        CorpseIllusionSection:AddButton({
            Icon = "arrow-right-to-portrait-rectangle",
            Name = "Go To Corpse",
            ToolTip = "Moves your local character near the selected corpse.",
            Callback = function()
                local TargetName =
                    tostring(
                        Config.CorpseIllusion.TargetName
                        or ""
                    )

                local Success,
                    Message =
                        CorpseIllusion.GoTo(
                            TargetName
                        )

                CorpseIllusionStatus:SetText(
                    (
                        Success
                        and "Status: "
                        or "Status: error - "
                    )
                    .. tostring(Message)
                )
            end,
        })

        CorpseIllusionSection:AddButton({
            Icon = "arrow-curl-to-left",
            Name = "Return",
            ToolTip = "Returns to the position saved before Go To Corpse.",
            Callback = function()
                local Success,
                    Message =
                        CorpseIllusion.ReturnToPreviousPosition()

                CorpseIllusionStatus:SetText(
                    (
                        Success
                        and "Status: "
                        or "Status: error - "
                    )
                    .. tostring(Message)
                )
            end,
        })

        CorpseIllusionSection:AddButton({
            Icon = "eye",
            Name = "Show Local Illusion",
            ToolTip = "Creates a visual-only local copy near your character.",
            Callback = function()
                local TargetName =
                    tostring(
                        Config.CorpseIllusion.TargetName
                        or ""
                    )

                local Success,
                    Message =
                        CorpseIllusion.Show(
                            TargetName
                        )

                CorpseIllusionStatus:SetText(
                    (
                        Success
                        and "Status: "
                        or "Status: error - "
                    )
                    .. tostring(Message)
                )
            end,
        })

        CorpseIllusionSection:AddButton({
            Icon = "x",
            Name = "Clear Local Illusion",
            Callback = function()
                local Success,
                    Message =
                        CorpseIllusion.Clear()

                CorpseIllusionStatus:SetText(
                    (
                        Success
                        and "Status: "
                        or "Status: error - "
                    )
                    .. tostring(Message)
                )
            end,
        })

        local CorpseAppearanceSection = CorpsesTab:AddSection({
            Name = "Appearance",
            Position = "right",
        })

        AddDropdown(
            CorpseAppearanceSection,
            "Box Style",
            "corpses_box_style",
            Config.Corpses.BoxStyle,
            { "Corner", "Full" },
            function(Value)
                Config.Corpses.BoxStyle = Value
            end
        )

        AddColorPicker(
            CorpseAppearanceSection,
            "Corpse Color",
            "corpses_color",
            Config.Corpses.Color,
            function(Value)
                Config.Corpses.Color = Value
            end
        )

        AddColorPicker(
            CorpseAppearanceSection,
            "Text Color",
            "corpses_text_color",
            Config.Corpses.TextColor,
            function(Value)
                Config.Corpses.TextColor = Value
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
                Config.Corpses.BoxThickness = Value
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
                Config.Corpses.CornerRatio = Value
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
                Config.Corpses.BoxPadding = Value
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
                Config.Corpses.MaxDistance = Value
            end
        )

        -----------------------------------------------------
        -- SETTINGS
        -----------------------------------------------------

        local SettingsTab = Window:AddTab({
            Icon = "gear",
            Name = "Settings",
            Type = "Single",
        })

        local InterfaceSection = SettingsTab:AddSection({
            Name = "Interface",
            Position = "left",
        })

        AddToggle(
            InterfaceSection,
            "Watermark",
            "ui_watermark",
            Config.UI.Watermark ~= false,
            function(Value)
                Config.UI.Watermark = Value
                Watermark:SetRender(Value)
            end
        )

        InterfaceSection:AddLabel("Menu Key"):AddKeybind({
            Flag = "ui_menu_key",
            Default = Config.UI.Keybind or "LeftAlt",
            Callback = function(Value)
                Config.UI.Keybind = Value
                Window.Keybind = Value
            end,
        })

        local DiagnosticsSection = SettingsTab:AddSection({
            Name = "Diagnostics",
            Position = "right",
        })

        AddToggle(
            DiagnosticsSection,
            "Profiler",
            "profiler_enabled",
            Config.Profiler.Enabled,
            function(Value)
                Config.Profiler.Enabled = Value
            end
        )

        AddToggle(
            DiagnosticsSection,
            "Profiler Overlay",
            "profiler_overlay",
            Config.Profiler.Overlay,
            function(Value)
                Config.Profiler.Overlay = Value
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
                Config.Profiler.ReportInterval = Value
            end
        )

        DiagnosticsSection:AddLabel(
            "Measures Newz CPU-side work only",
            true
        )

        local ProjectSection = SettingsTab:AddSection({
            Name = "Project",
            Position = "left",
        })

        ProjectSection:AddLabel(
            "Name: " .. tostring(Config.Project.Name),
            true
        )

        ProjectSection:AddLabel(
            "Version: " .. tostring(Config.Project.Version),
            true
        )

        ProjectSection:AddLabel(
            "Runtime: Players.Character + Workspace.Corpses",
            true
        )

        local Controller = {
            Window = Window,
            Library = NeverLose,
        }

        function Controller.Destroy()
            Cleanup()
        end

        return Controller
    end, Traceback)

    if not Success then
        Cleanup()

        error(
            "Falha ao inicializar UI:\n" .. tostring(Result),
            0
        )
    end

    return Result
end

return UI
