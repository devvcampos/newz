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


    Compkiller:
        Loader(
            nil,
            1
        ).yield()


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


    ---------------------------------------------------------
    -- WINDOW
    ---------------------------------------------------------

    local Window =
        Compkiller.new({

            Keybind =
                Config.UI.Keybind,

        })


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
    -- CATEGORY
    ---------------------------------------------------------

    Window:
        DrawCategory({
            Name = "Visual"
        })


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
    -- SECTIONS
    ---------------------------------------------------------

    local ESPSection =
        Visuals:
            DrawSection({

                Name =
                    "ESP",

                Position =
                    "left",

            })


    local Appearance =
        Visuals:
            DrawSection({

                Name =
                    "Appearance",

                Position =
                    "right",

            })


    ---------------------------------------------------------
    -- MAIN ESP
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
    -- APPEARANCE
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
    -- CONFIG CATEGORY
    ---------------------------------------------------------

    Window:
        DrawCategory({
            Name = "Settings"
        })


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


    Configs:
        Init()


    ---------------------------------------------------------
    -- API
    ---------------------------------------------------------

    local Controller =
        {}


    Controller.Window =
        Window


    Controller.Library =
        Compkiller


    function Controller.Destroy()

        if
            Window
            and Window.Root
        then

            Window.Root:
                Destroy()

        end

    end


    return Controller

end


return UI