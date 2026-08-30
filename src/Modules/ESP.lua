local ESP = {}

function ESP.Init(Config)

    local Players =
        game:GetService("Players")

    local RunService =
        game:GetService("RunService")

    local Workspace =
        game:GetService("Workspace")


    local LocalPlayer =
        Players.LocalPlayer


    local Settings =
        Config.ESP


    local Destroyed =
        false


    local ESPObjects =
        {}


    local Connections =
        {}


    ---------------------------------------------------------
    -- GUI
    ---------------------------------------------------------

    local PlayerGui =
        LocalPlayer:
            WaitForChild(
                "PlayerGui"
            )


    local OldGui =
        PlayerGui:
            FindFirstChild(
                "newz_ESP"
            )


    if OldGui then
        OldGui:Destroy()
    end


    local ScreenGui =
        Instance.new(
            "ScreenGui"
        )


    ScreenGui.Name =
        "newz_ESP"

    ScreenGui.ResetOnSpawn =
        false

    ScreenGui.IgnoreGuiInset =
        true

    ScreenGui.DisplayOrder =
        999

    ScreenGui.ZIndexBehavior =
        Enum.ZIndexBehavior.Sibling

    ScreenGui.Parent =
        PlayerGui


    ---------------------------------------------------------
    -- TEXT
    ---------------------------------------------------------

    local function CreateText()

        local Text =
            Instance.new(
                "TextLabel"
            )


        Text.BackgroundTransparency =
            1


        Text.Size =
            UDim2.fromOffset(
                200,
                18
            )


        Text.AnchorPoint =
            Vector2.new(
                0.5,
                0.5
            )


        Text.TextColor3 =
            Settings.TextColor


        Text.TextStrokeTransparency =
            0.25


        Text.TextStrokeColor3 =
            Color3.new(
                0,
                0,
                0
            )


        Text.Font =
            Enum.Font.Gotham


        Text.TextSize =
            13


        Text.ZIndex =
            11


        Text.Parent =
            ScreenGui


        return Text

    end


    ---------------------------------------------------------
    -- CREATE ESP
    ---------------------------------------------------------

    local function CreateESP(Player)

        local Box =
            Instance.new(
                "Frame"
            )


        Box.Name =
            "ESP_"
            .. Player.Name


        Box.BackgroundTransparency =
            1


        Box.BorderSizePixel =
            0


        Box.ZIndex =
            10


        Box.Parent =
            ScreenGui


        local Stroke =
            Instance.new(
                "UIStroke"
            )


        Stroke.Thickness =
            Settings.BoxThickness


        Stroke.Color =
            Settings.BoxColor


        Stroke.LineJoinMode =
            Enum.LineJoinMode.Miter


        Stroke.Parent =
            Box


        local Data = {

            Box =
                Box,

            Stroke =
                Stroke,

            Name =
                CreateText(),

            Health =
                CreateText(),

            Distance =
                CreateText(),

        }


        ESPObjects[
            Player
        ] =
            Data


        return Data

    end


    ---------------------------------------------------------
    -- HIDE
    ---------------------------------------------------------

    local function HideESP(Data)

        if not Data then
            return
        end


        Data.Box.Visible =
            false

        Data.Name.Visible =
            false

        Data.Health.Visible =
            false

        Data.Distance.Visible =
            false

    end


    ---------------------------------------------------------
    -- REMOVE
    ---------------------------------------------------------

    local function RemoveESP(Player)

        local Data =
            ESPObjects[
                Player
            ]


        if not Data then
            return
        end


        for _, Object
            in pairs(Data)
        do

            if
                typeof(Object)
                == "Instance"
            then

                Object:Destroy()

            end

        end


        ESPObjects[
            Player
        ] =
            nil

    end


    ---------------------------------------------------------
    -- BODY FILTER
    ---------------------------------------------------------

    local function IsBodyPart(
        Part,
        Character
    )

        if
            not Part:
                IsA(
                    "BasePart"
                )
        then
            return false
        end


        -----------------------------------------------------
        -- ROOT NÃO REPRESENTA O CORPO VISUAL
        -----------------------------------------------------

        if
            Part.Name
            == "HumanoidRootPart"
        then
            return false
        end


        -----------------------------------------------------
        -- ACCESSORY
        -----------------------------------------------------

        if
            Part:
                FindFirstAncestorWhichIsA(
                    "Accessory"
                )
        then

            return false

        end


        -----------------------------------------------------
        -- TOOL
        -----------------------------------------------------

        if
            Part:
                FindFirstAncestorWhichIsA(
                    "Tool"
                )
        then

            return false

        end


        -----------------------------------------------------
        -- WEAPON RIG
        -----------------------------------------------------

        local WeaponRig =
            Character:
                FindFirstChild(
                    "WeaponRig"
                )


        if
            WeaponRig
            and Part:
                IsDescendantOf(
                    WeaponRig
                )
        then

            return false

        end


        return true

    end


    ---------------------------------------------------------
    -- PROJECT PART
    ---------------------------------------------------------

    local function ProjectPart(
        Part,
        Camera,
        Bounds
    )

        local Half =
            Part.Size / 2


        local Corners = {

            Vector3.new(
                -Half.X,
                -Half.Y,
                -Half.Z
            ),

            Vector3.new(
                -Half.X,
                -Half.Y,
                Half.Z
            ),

            Vector3.new(
                -Half.X,
                Half.Y,
                -Half.Z
            ),

            Vector3.new(
                -Half.X,
                Half.Y,
                Half.Z
            ),

            Vector3.new(
                Half.X,
                -Half.Y,
                -Half.Z
            ),

            Vector3.new(
                Half.X,
                -Half.Y,
                Half.Z
            ),

            Vector3.new(
                Half.X,
                Half.Y,
                -Half.Z
            ),

            Vector3.new(
                Half.X,
                Half.Y,
                Half.Z
            ),

        }


        for _, Offset
            in ipairs(
                Corners
            )
        do

            local WorldPosition =
                Part.CFrame:
                    PointToWorldSpace(
                        Offset
                    )


            local ScreenPosition =
                Camera:
                    WorldToViewportPoint(
                        WorldPosition
                    )


            if
                ScreenPosition.Z
                > 0.05
            then

                Bounds.HasPoint =
                    true


                Bounds.MinX =
                    math.min(
                        Bounds.MinX,
                        ScreenPosition.X
                    )


                Bounds.MinY =
                    math.min(
                        Bounds.MinY,
                        ScreenPosition.Y
                    )


                Bounds.MaxX =
                    math.max(
                        Bounds.MaxX,
                        ScreenPosition.X
                    )


                Bounds.MaxY =
                    math.max(
                        Bounds.MaxY,
                        ScreenPosition.Y
                    )

            end
        end
    end


    ---------------------------------------------------------
    -- CHARACTER BOUNDS
    ---------------------------------------------------------

    local function GetCharacterBounds(
        Character,
        Camera
    )

        local Root =
            Character:
                FindFirstChild(
                    "HumanoidRootPart"
                )


        if not Root then
            return nil
        end


        local RootScreen =
            Camera:
                WorldToViewportPoint(
                    Root.Position
                )


        if
            RootScreen.Z
            <= 0.05
        then

            return nil

        end


        local Bounds = {

            MinX =
                math.huge,

            MinY =
                math.huge,

            MaxX =
                -math.huge,

            MaxY =
                -math.huge,

            HasPoint =
                false,

        }


        for _, Object
            in ipairs(
                Character:
                    GetDescendants()
            )
        do

            if
                IsBodyPart(
                    Object,
                    Character
                )
            then

                ProjectPart(
                    Object,
                    Camera,
                    Bounds
                )

            end

        end


        if
            not Bounds.HasPoint
        then

            return nil

        end


        local Viewport =
            Camera.ViewportSize


        -----------------------------------------------------
        -- COMPLETAMENTE FORA DA TELA
        -----------------------------------------------------

        if
            Bounds.MaxX < 0
            or Bounds.MinX > Viewport.X
            or Bounds.MaxY < 0
            or Bounds.MinY > Viewport.Y
        then

            return nil

        end


        local Padding =
            tonumber(
                Settings.BoxPadding
            )
            or 2


        local X =
            Bounds.MinX
            - Padding


        local Y =
            Bounds.MinY
            - Padding


        local Width =
            (
                Bounds.MaxX
                - Bounds.MinX
            )
            + Padding * 2


        local Height =
            (
                Bounds.MaxY
                - Bounds.MinY
            )
            + Padding * 2


        if
            Width <= 2
            or Height <= 2
        then

            return nil

        end


        return {

            X =
                X,

            Y =
                Y,

            Width =
                Width,

            Height =
                Height,

            CenterX =
                X
                + Width / 2,

            CenterY =
                Y
                + Height / 2,

        }

    end


    ---------------------------------------------------------
    -- UPDATE PLAYER
    ---------------------------------------------------------

    local function UpdatePlayer(
        Player,
        Camera,
        LocalRoot
    )

        local Data =
            ESPObjects[
                Player
            ]
            or CreateESP(
                Player
            )


        if
            not Settings.Enabled
        then

            HideESP(
                Data
            )

            return

        end


        local Character =
            Player.Character


        if not Character then

            HideESP(
                Data
            )

            return

        end


        local Root =
            Character:
                FindFirstChild(
                    "HumanoidRootPart"
                )


        local Humanoid =
            Character:
                FindFirstChildOfClass(
                    "Humanoid"
                )


        if
            not Root
            or not Humanoid
            or Humanoid.Health <= 0
        then

            HideESP(
                Data
            )

            return

        end


        -----------------------------------------------------
        -- DISTANCE
        -----------------------------------------------------

        local Distance =
            LocalRoot
            and (
                Root.Position
                - LocalRoot.Position
            ).Magnitude
            or 0


        local MaxDistance =
            tonumber(
                Settings.MaxDistance
            )
            or 1000


        if
            Distance
            > MaxDistance
        then

            HideESP(
                Data
            )

            return

        end


        -----------------------------------------------------
        -- BOUNDS
        -----------------------------------------------------

        local Bounds =
            GetCharacterBounds(
                Character,
                Camera
            )


        if not Bounds then

            HideESP(
                Data
            )

            return

        end


        -----------------------------------------------------
        -- COLORS / THICKNESS
        -----------------------------------------------------

        Data.Stroke.Color =
            Settings.BoxColor


        Data.Stroke.Thickness =
            tonumber(
                Settings.BoxThickness
            )
            or 1


        Data.Name.TextColor3 =
            Settings.TextColor


        Data.Health.TextColor3 =
            Settings.TextColor


        Data.Distance.TextColor3 =
            Settings.TextColor


        -----------------------------------------------------
        -- BOX
        -----------------------------------------------------

        Data.Box.Position =
            UDim2.fromOffset(
                math.floor(
                    Bounds.X
                ),

                math.floor(
                    Bounds.Y
                )
            )


        Data.Box.Size =
            UDim2.fromOffset(
                math.floor(
                    Bounds.Width
                ),

                math.floor(
                    Bounds.Height
                )
            )


        Data.Box.Visible =
            Settings.Box
            == true


        -----------------------------------------------------
        -- NAME
        -----------------------------------------------------

        Data.Name.Position =
            UDim2.fromOffset(
                Bounds.CenterX,
                Bounds.Y - 12
            )


        Data.Name.Text =
            Player.Name


        Data.Name.Visible =
            Settings.Name
            == true


        -----------------------------------------------------
        -- HEALTH
        -----------------------------------------------------

        Data.Health.Position =
            UDim2.fromOffset(
                Bounds.CenterX,

                Bounds.Y
                + Bounds.Height
                + 10
            )


        Data.Health.Text =
            string.format(
                "%d/%d HP",

                math.floor(
                    Humanoid.Health
                ),

                math.floor(
                    Humanoid.MaxHealth
                )
            )


        Data.Health.Visible =
            Settings.Health
            == true


        -----------------------------------------------------
        -- DISTANCE
        -----------------------------------------------------

        Data.Distance.Position =
            UDim2.fromOffset(
                Bounds.CenterX,

                Bounds.Y
                + Bounds.Height
                + 27
            )


        Data.Distance.Text =
            string.format(
                "%.0f studs",
                Distance
            )


        Data.Distance.Visible =
            Settings.Distance
            == true

    end


    ---------------------------------------------------------
    -- RENDER
    ---------------------------------------------------------

    Connections.Render =
        RunService.RenderStepped:
            Connect(function()

                if Destroyed then
                    return
                end


                local Camera =
                    Workspace.CurrentCamera


                if not Camera then
                    return
                end


                local LocalCharacter =
                    LocalPlayer.Character


                local LocalRoot =
                    LocalCharacter
                    and LocalCharacter:
                        FindFirstChild(
                            "HumanoidRootPart"
                        )


                for _, Player
                    in ipairs(
                        Players:
                            GetPlayers()
                    )
                do

                    if
                        Player
                        ~= LocalPlayer
                    then

                        UpdatePlayer(
                            Player,
                            Camera,
                            LocalRoot
                        )

                    end

                end

            end)


    ---------------------------------------------------------
    -- PLAYER REMOVING
    ---------------------------------------------------------

    Connections.PlayerRemoving =
        Players.PlayerRemoving:
            Connect(function(Player)

                RemoveESP(
                    Player
                )

            end)


    ---------------------------------------------------------
    -- API
    ---------------------------------------------------------

    local Controller =
        {}


    function Controller.Toggle(
        Value
    )

        Settings.Enabled =
            Value == true

    end


    function Controller.Destroy()

        if Destroyed then
            return
        end


        Destroyed =
            true


        for _, Connection
            in pairs(
                Connections
            )
        do

            if Connection then
                Connection:
                    Disconnect()
            end

        end


        table.clear(
            Connections
        )


        for Player
            in pairs(
                ESPObjects
            )
        do

            RemoveESP(
                Player
            )

        end


        if ScreenGui then
            ScreenGui:
                Destroy()
        end

    end


    return Controller

end


return ESP