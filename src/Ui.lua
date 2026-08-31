local UI = {}

function UI.Init(Config)

    ---------------------------------------------------------
    -- SERVICES
    ---------------------------------------------------------

    local Players =
        game:GetService("Players")


    local LocalPlayer =
        Players.LocalPlayer


    assert(
        LocalPlayer,
        "UI precisa ser inicializada no cliente"
    )


    ---------------------------------------------------------
    -- STATE
    ---------------------------------------------------------

    local Destroyed =
        false


    local Threads =
        {}


    ---------------------------------------------------------
    -- LOAD NEVERLOSE
    ---------------------------------------------------------

    local VendorURL =
        "https://raw.githubusercontent.com/devvcampos/newz/main/vendor/NeverLose.lua"


    local CacheBust =
        tostring(
            DateTime.now().UnixTimestampMillis
        )


    local Source =
        game:HttpGet(
            VendorURL
            .. "?cb="
            .. CacheBust
        )


    local Chunk,
        LoadError =
            loadstring(
                Source
            )


    assert(
        Chunk,
        "Falha ao carregar NeverLose: "
        .. tostring(
            LoadError
        )
    )


    local NeverLose =
        Chunk()


    assert(
        type(NeverLose) == "table"
        and type(NeverLose.CreateWindow) == "function",
        "NeverLose invalida"
    )


    ---------------------------------------------------------
    -- LIBRARY SETTINGS
    ---------------------------------------------------------

    NeverLose.UnloadEnabled =
        true


    if Config.UI.AccentColor then

        NeverLose.AccentColor =
            Config.UI.AccentColor

    end


    ---------------------------------------------------------
    -- CONFIG FOLDER
    ---------------------------------------------------------

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


    ---------------------------------------------------------
    -- WINDOW
    ---------------------------------------------------------

    local Window =
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


    Window:
        SetAccount({

            Username =
                LocalPlayer.DisplayName,

            Expires =
                "DEV",

        })


    ---------------------------------------------------------
    -- WATERMARK
    ---------------------------------------------------------

    local Watermark =
        Window:
            Watermark()


    local WatermarkProject =
        Watermark:
            AddBlock(
                "eye",
                Config.Project.Name
            )


    local WatermarkUser =
        Watermark:
            AddBlock(
                "user",
                LocalPlayer.Name
            )


    local WatermarkPlayers =
        Watermark:
            AddBlock(
                "users",
                "Players: "
                .. tostring(
                    #Players:
                        GetPlayers()
                )
            )


    Watermark:
        SetRender(
            Config.UI.Watermark
            ~= false
        )


    Threads.Watermark =
        task.spawn(function()

            while
                not Destroyed
            do

                task.wait(
                    1.5
                )


                if Destroyed then
                    break
                end


                WatermarkPlayers:
                    SetText(
                        "Players: "
                        .. tostring(
                            #Players:
                                GetPlayers()
                        )
                    )

            end

        end)


    ---------------------------------------------------------
    -- HELPERS
    ---------------------------------------------------------

    local function AddToggle(
        Section,
        Name,
        Flag,
        Default,
        Callback
    )

        return
            Section:
                AddLabel(
                    Name
                ):
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
                AddLabel(
                    Name
                ):
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
                AddLabel(
                    Name
                ):
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
                AddLabel(
                    Name
                ):
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


    ---------------------------------------------------------
    -- PLAYERS TAB
    ---------------------------------------------------------

    local PlayersTab =
        Window:
            AddTab({

                Icon =
                    "crosshairs",

                Name =
                    "Players",

                Type =
                    "Double",

            })


    ---------------------------------------------------------
    -- ESP SECTION
    ---------------------------------------------------------

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
        "Distance",
        "esp_distance",
        Config.ESP.Distance,
        function(Value)

            Config.ESP.Distance =
                Value

        end
    )


    ---------------------------------------------------------
    -- FILTERS
    ---------------------------------------------------------

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
        "Players Only",
        "esp_players_only",
        Config.ESP.PlayersOnly,
        function(Value)

            Config.ESP.PlayersOnly =
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


    ---------------------------------------------------------
    -- APPEARANCE
    ---------------------------------------------------------

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


    ---------------------------------------------------------
    -- SETTINGS TAB
    ---------------------------------------------------------

    local SettingsTab =
        Window:
            AddTab({

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
        Config.UI.Watermark ~= false,
        function(Value)

            Config.UI.Watermark =
                Value


            Watermark:
                SetRender(
                    Value
                )

        end
    )


    InterfaceSection:
        AddLabel(
            "Menu Key"
        ):
        AddKeybind({

            Flag =
                "ui_menu_key",

            Default =
                Config.UI.Keybind
                or "LeftAlt",

            Callback =
                function(Value)

                    Config.UI.Keybind =
                        Value


                    Window.Keybind =
                        Value

                end,

        })


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
            "Runtime: Workspace."
            .. tostring(
                (
                    Config.Runtime
                    and Config.Runtime.EntitiesFolder
                )
                or "Players"
            ),
            true
        )


    ---------------------------------------------------------
    -- CONTROLLER
    ---------------------------------------------------------

    local Controller =
        {}


    Controller.Window =
        Window


    Controller.Library =
        NeverLose


    ---------------------------------------------------------
    -- DESTROY
    ---------------------------------------------------------

    function Controller.Destroy()

        if Destroyed then
            return
        end


        Destroyed =
            true


        -----------------------------------------------------
        -- OUR THREADS
        -----------------------------------------------------

        for _,
            Thread
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


        -----------------------------------------------------
        -- CONFIG TEMP CONNECTION
        -----------------------------------------------------

        if
            Window
            and Window.ConfigManager
        then

            local ConfigManager =
                Window.ConfigManager


            if
                ConfigManager.UnsafeThread
            then

                pcall(function()

                    ConfigManager.UnsafeThread:
                        Disconnect()

                end)


                ConfigManager.UnsafeThread =
                    nil

            end

        end


        -----------------------------------------------------
        -- LIBRARY CLEANUP
        -----------------------------------------------------

        if
            NeverLose
            and type(
                NeverLose.Unload
            ) == "function"
        then

            pcall(function()

                NeverLose:
                    Unload()

            end)

        end

    end


    return Controller

end


return UI