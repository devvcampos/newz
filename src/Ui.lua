local UI = {}

function UI.Init(Config)

    ---------------------------------------------------------
    -- LIBRARY
    ---------------------------------------------------------

    local Compkiller =
        loadstring(
            game:HttpGet(
                "https://raw.githubusercontent.com/4lpaca-pin/CompKiller/refs/heads/main/src/source.luau"
            )
        )()


    ---------------------------------------------------------
    -- STATE
    ---------------------------------------------------------

    local Destroyed =
        false


    local Threads =
        {}


    ---------------------------------------------------------
    -- LOADER
    ---------------------------------------------------------

    Compkiller:
        Loader(
            nil,
            1
        ).yield()


    ---------------------------------------------------------
    -- INITIAL COLORS
    ---------------------------------------------------------

    if Config.UI.HighlightColor then

        Compkiller:
            ChangeHighlightColor(
                Config.UI.HighlightColor
            )

    end


    ---------------------------------------------------------
    -- PERFORMANCE
    ---------------------------------------------------------

    Compkiller:
        OptimizeMode(
            Config.UI.PerformanceMode
            == true
        )


    ---------------------------------------------------------
    -- CONFIG MANAGER
    ---------------------------------------------------------

    local FileWatcher =
        Compkiller:
            ConfigManager({

                Directory =
                    Config.UI.ConfigDirectory,

                Config =
                    Config.UI.ConfigFolder,

            })


    -- Ativa notificações nativas
    -- ao carregar/salvar configs.

    FileWatcher.EnableNotify =
        true


    ---------------------------------------------------------
    -- WINDOW
    ---------------------------------------------------------

    local Window =
        Compkiller.new({

            Name =
                Config.Project.Name,

            Keybind =
                Config.UI.Keybind,

        })


    Window.PerformanceMode =
        Config.UI.PerformanceMode
        == true


    Window.AlwayShowTab =
        Config.UI.AlwaysShowTab
        == true


    Window:
        Update({

            WindowName =
                Config.Project.Name,

            Username =
                game:GetService(
                    "Players"
                ).LocalPlayer.DisplayName,

            ExpireDate =
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
            AddText({

                Icon =
                    "eye",

                Text =
                    Config.Project.Name,

            })


    local WatermarkUser =
        Watermark:
            AddText({

                Icon =
                    "user",

                Text =
                    game:GetService(
                        "Players"
                    ).LocalPlayer.Name,

            })


    local WatermarkTime =
        Watermark:
            AddText({

                Icon =
                    "clock",

                Text =
                    Compkiller:GetTimeNow(),

            })


    local WatermarkPlayers =
        Watermark:
            AddText({

                Icon =
                    "users",

                Text =
                    "Players: 0",

            })


    local WatermarkItems = {

        WatermarkProject,
        WatermarkUser,
        WatermarkTime,
        WatermarkPlayers,

    }


    local function SetWatermarkVisible(
        Value
    )

        Config.UI.Watermark =
            Value == true


        for _, Item
            in ipairs(
                WatermarkItems
            )
        do

            if Item
                and Item.Visible
            then

                Item:
                    Visible(
                        Config.UI.Watermark
                    )

            end

        end

    end


    SetWatermarkVisible(
        Config.UI.Watermark
    )


    ---------------------------------------------------------
    -- WATERMARK UPDATE
    ---------------------------------------------------------

    Threads.Watermark =
        task.spawn(function()

            local Players =
                game:GetService(
                    "Players"
                )


            while
                not Destroyed
            do

                task.wait(
                    1
                )


                if Destroyed then
                    break
                end


                WatermarkTime:
                    SetText(
                        Compkiller:
                            GetTimeNow()
                    )


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
    -- VISUAL CATEGORY
    ---------------------------------------------------------

    Window:
        DrawCategory({
            Name = "Visual"
        })


    ---------------------------------------------------------
    -- PLAYERS TAB
    ---------------------------------------------------------

    local Visuals =
        Window:
            DrawTab({

                Icon =
                    "eye",

                Name =
                    "Players",

                Type =
                    "Double",

            })


    ---------------------------------------------------------
    -- ESP SECTION
    ---------------------------------------------------------

    local ESPSection =
        Visuals:
            DrawSection({

                Name =
                    "ESP",

                Position =
                    "left",

            })

            ESPSection:
    AddToggle({

        Name =
            "Visibility Check",

        Flag =
            "esp_visibility",

        Default =
            Config.ESP.VisibilityCheck,

        Callback =
            function(Value)

                Config.ESP.VisibilityCheck =
                    Value

            end,

    })


ESPSection:
    AddToggle({

        Name =
            "Team Check",

        Flag =
            "esp_team_check",

        Default =
            Config.ESP.TeamCheck,

        Callback =
            function(Value)

                Config.ESP.TeamCheck =
                    Value

            end,

    })


ESPSection:
    AddToggle({

        Name =
            "Players Only",

        Flag =
            "esp_players_only",

        Default =
            Config.ESP.PlayersOnly,

        Callback =
            function(Value)

                Config.ESP.PlayersOnly =
                    Value

            end,

    })


ESPSection:
    AddToggle({

        Name =
            "Dynamic Health Color",

        Flag =
            "esp_dynamic_health",

        Default =
            Config.ESP.DynamicHealthColor,

        Callback =
            function(Value)

                Config.ESP.DynamicHealthColor =
                    Value

            end,

    })


    ---------------------------------------------------------
    -- APPEARANCE SECTION
    ---------------------------------------------------------

    local Appearance =
        Visuals:
            DrawSection({

                Name =
                    "Appearance",

                Position =
                    "right",

            })


            Appearance:
    AddDropdown({

        Name =
            "Box Style",

        Flag =
            "esp_box_style",

        Values = {
            "Corner",
            "Full",
        },

        Default =
            Config.ESP.BoxStyle,

        Multi =
            false,

        Callback =
            function(Value)

                Config.ESP.BoxStyle =
                    Value

            end,

    })


Appearance:
    AddColorPicker({

        Name =
            "Visible Color",

        Flag =
            "esp_visible_color",

        Default =
            Config.ESP.VisibleColor,

        Callback =
            function(Value)

                Config.ESP.VisibleColor =
                    Value

            end,

    })


Appearance:
    AddColorPicker({

        Name =
            "Hidden Color",

        Flag =
            "esp_hidden_color",

        Default =
            Config.ESP.HiddenColor,

        Callback =
            function(Value)

                Config.ESP.HiddenColor =
                    Value

            end,

    })


Appearance:
    AddSlider({

        Name =
            "Corner Size",

        Flag =
            "esp_corner_ratio",

        Min =
            0.10,

        Max =
            0.50,

        Round =
            2,

        Default =
            Config.ESP.CornerRatio,

        Callback =
            function(Value)

                Config.ESP.CornerRatio =
                    Value

            end,

    })


    ---------------------------------------------------------
    -- ESP ENABLED
    ---------------------------------------------------------

    ESPSection:
        AddToggle({

            Name =
                "Enabled",

            Flag =
                "esp_enabled",

            Default =
                Config.ESP.Enabled,

            Callback =
                function(Value)

                    Config.ESP.Enabled =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- BOX
    ---------------------------------------------------------

    ESPSection:
        AddToggle({

            Name =
                "Box",

            Flag =
                "esp_box",

            Default =
                Config.ESP.Box,

            Callback =
                function(Value)

                    Config.ESP.Box =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- NAME
    ---------------------------------------------------------

    ESPSection:
        AddToggle({

            Name =
                "Name",

            Flag =
                "esp_name",

            Default =
                Config.ESP.Name,

            Callback =
                function(Value)

                    Config.ESP.Name =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- HEALTH
    ---------------------------------------------------------

    ESPSection:
        AddToggle({

            Name =
                "Health",

            Flag =
                "esp_health",

            Default =
                Config.ESP.Health,

            Callback =
                function(Value)

                    Config.ESP.Health =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- DISTANCE
    ---------------------------------------------------------

    ESPSection:
        AddToggle({

            Name =
                "Distance",

            Flag =
                "esp_distance",

            Default =
                Config.ESP.Distance,

            Callback =
                function(Value)

                    Config.ESP.Distance =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- INFORMATION
    ---------------------------------------------------------

    ESPSection:
        AddParagraph({

            Title =
                "Entity ESP",

            Content =
                "Tracking Workspace.Players\n"
                .. "Cached body-part bounds",

        })


    ---------------------------------------------------------
    -- BOX COLOR
    ---------------------------------------------------------

    Appearance:
        AddColorPicker({

            Name =
                "Box Color",

            Flag =
                "esp_box_color",

            Default =
                Config.ESP.BoxColor,

            Callback =
                function(Value)

                    Config.ESP.BoxColor =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- TEXT COLOR
    ---------------------------------------------------------

    Appearance:
        AddColorPicker({

            Name =
                "Text Color",

            Flag =
                "esp_text_color",

            Default =
                Config.ESP.TextColor,

            Callback =
                function(Value)

                    Config.ESP.TextColor =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- THICKNESS
    ---------------------------------------------------------

    Appearance:
        AddSlider({

            Name =
                "Box Thickness",

            Flag =
                "esp_box_thickness",

            Min =
                1,

            Max =
                4,

            Round =
                0,

            Default =
                Config.ESP.BoxThickness,

            Callback =
                function(Value)

                    Config.ESP.BoxThickness =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- PADDING
    ---------------------------------------------------------

    Appearance:
        AddSlider({

            Name =
                "Box Padding",

            Flag =
                "esp_box_padding",

            Min =
                0,

            Max =
                10,

            Round =
                0,

            Default =
                Config.ESP.BoxPadding,

            Callback =
                function(Value)

                    Config.ESP.BoxPadding =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- MAX DISTANCE
    ---------------------------------------------------------

    Appearance:
        AddSlider({

            Name =
                "Max Distance",

            Flag =
                "esp_max_distance",

            Min =
                50,

            Max =
                3000,

            Round =
                0,

            Default =
                Config.ESP.MaxDistance,

            Callback =
                function(Value)

                    Config.ESP.MaxDistance =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- SETTINGS CATEGORY
    ---------------------------------------------------------

    Window:
        DrawCategory({
            Name = "Settings"
        })


    ---------------------------------------------------------
    -- GENERAL SETTINGS TAB
    ---------------------------------------------------------

    local SettingsTab =
        Window:
            DrawTab({

                Icon =
                    "settings-3",

                Name =
                    "Settings",

                Type =
                    "Single",

            })


    local General =
        SettingsTab:
            DrawSection({

                Name =
                    "Interface",

            })


    ---------------------------------------------------------
    -- HIGHLIGHT
    ---------------------------------------------------------

    local HighlightOptions =
        General:
            AddColorPicker({

                Name =
                    "Highlight",

                Flag =
                    "ui_highlight",

                Default =
                    Config.UI.HighlightColor,

                Callback =
                    function(Value)

                        Config.UI.HighlightColor =
                            Value


                        Compkiller:
                            ChangeHighlightColor(
                                Value
                            )

                    end,

            }).Link:
            AddOption()


    ---------------------------------------------------------
    -- RAINBOW
    ---------------------------------------------------------

    HighlightOptions:
        AddToggle({

            Name =
                "Rainbow",

            Flag =
                "ui_rainbow",

            Default =
                Config.UI.Rainbow,

            Callback =
                function(Value)

                    Config.UI.Rainbow =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- RAINBOW SPEED
    ---------------------------------------------------------

    HighlightOptions:
        AddSlider({

            Name =
                "Speed",

            Flag =
                "ui_rainbow_speed",

            Min =
                0.01,

            Max =
                1,

            Round =
                2,

            Default =
                Config.UI.RainbowSpeed,

            Callback =
                function(Value)

                    Config.UI.RainbowSpeed =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- ALWAYS SHOW TAB
    ---------------------------------------------------------

    General:
        AddToggle({

            Name =
                "Always Show Tab",

            Flag =
                "ui_always_tab",

            Default =
                Config.UI.AlwaysShowTab,

            Callback =
                function(Value)

                    Config.UI.AlwaysShowTab =
                        Value


                    Window.AlwayShowTab =
                        Value

                end,

        })


    ---------------------------------------------------------
    -- PERFORMANCE MODE
    ---------------------------------------------------------

    General:
        AddToggle({

            Name =
                "Performance Mode",

            Flag =
                "ui_performance",

            Default =
                Config.UI.PerformanceMode,

            Callback =
                function(Value)

                    Config.UI.PerformanceMode =
                        Value


                    Window.PerformanceMode =
                        Value


                    Compkiller:
                        OptimizeMode(
                            Value
                        )

                end,

        })


    ---------------------------------------------------------
    -- WATERMARK
    ---------------------------------------------------------

    General:
        AddToggle({

            Name =
                "Watermark",

            Flag =
                "ui_watermark",

            Default =
                Config.UI.Watermark,

            Callback =
                function(Value)

                    SetWatermarkVisible(
                        Value
                    )

                end,

        })


    ---------------------------------------------------------
    -- MENU KEY
    ---------------------------------------------------------

    General:
        AddKeybind({

            Name =
                "Menu Key",

            Flag =
                "ui_menu_key",

            Default =
                Config.UI.Keybind,

            Callback =
                function(Value)

                    Config.UI.Keybind =
                        Value


                    Window:
                        SetMenuKey(
                            Value
                        )

                end,

        })


    ---------------------------------------------------------
    -- UI INFO
    ---------------------------------------------------------

    General:
        AddParagraph({

            Title =
                "newz",

            Content =
                "Version "
                .. tostring(
                    Config.Project.Version
                )
                .. "\nCompkiller UI",

        })


    ---------------------------------------------------------
    -- CONFIGS
    ---------------------------------------------------------

    local Configs =
        Window:
            DrawConfig({

                Name =
                    "Configs",

                Icon =
                    "folder",

                Config =
                    FileWatcher,

            })


    local ConfigRuntime =
        Configs:
            Init()


    ---------------------------------------------------------
    -- RAINBOW THREAD
    ---------------------------------------------------------

    Threads.Rainbow =
        task.spawn(function()

            local Hue =
                0


            while
                not Destroyed
            do

                task.wait(
                    Config.UI.RainbowSpeed
                    or 0.1
                )


                if Destroyed then
                    break
                end


                if
                    Config.UI.Rainbow
                then

                    Compkiller:
                        ChangeHighlightColor(
                            Color3.fromHSV(
                                Hue,
                                1,
                                1
                            )
                        )


                    Hue +=
                        2 / 255


                    if Hue >= 1 then
                        Hue = 0
                    end

                end

            end

        end)


    ---------------------------------------------------------
    -- CONTROLLER
    ---------------------------------------------------------

    local Controller =
        {}


    Controller.Window =
        Window


    Controller.Library =
        Compkiller


    ---------------------------------------------------------
    -- RESOURCE CLEANUP
    ---------------------------------------------------------

    local function CleanupResource(
        Resource
    )

        if not Resource then
            return
        end


        local ResourceType =
            typeof(
                Resource
            )


        if
            ResourceType
            == "RBXScriptConnection"
        then

            pcall(function()

                Resource:
                    Disconnect()

            end)


        elseif
            ResourceType
            == "thread"
        then

            pcall(
                task.cancel,
                Resource
            )

        end

    end


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

        for _, Thread
            in pairs(
                Threads
            )
        do

            CleanupResource(
                Thread
            )

        end


        table.clear(
            Threads
        )


        -----------------------------------------------------
        -- CONFIG WATCHER
        -----------------------------------------------------

        if ConfigRuntime then

            CleanupResource(
                ConfigRuntime.THREAD
            )

        end


        -----------------------------------------------------
        -- DISABLE OLD MENU KEY
        -----------------------------------------------------

        if
            Window
            and Window.SetMenuKey
        then

            pcall(function()

                Window:
                    SetMenuKey(
                        Enum.KeyCode.Unknown
                    )

            end)

        end


        -----------------------------------------------------
        -- COMPKILLER INTERNAL THREADS
        -----------------------------------------------------

        if Window then

            CleanupResource(
                Window.LOOP_THREAD
            )


            if Window.THREADS then

                for _, Resource
                    in pairs(
                        Window.THREADS
                    )
                do

                    CleanupResource(
                        Resource
                    )

                end

            end

        end


        -----------------------------------------------------
        -- DESTROY GUI
        -----------------------------------------------------

        if
            Window
            and Window.Root
        then

            pcall(function()

                Window.Root:
                    Destroy()

            end)

        end

    end


    return Controller

end


return UI