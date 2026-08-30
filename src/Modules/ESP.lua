local ESP = {}

function ESP.Init(Config)

    ---------------------------------------------------------
    -- SERVICES
    ---------------------------------------------------------

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


    ---------------------------------------------------------
    -- GAME ENTITIES
    ---------------------------------------------------------

    local EntitiesFolder =
        Workspace:WaitForChild(
            "Players"
        )


    ---------------------------------------------------------
    -- STATE
    ---------------------------------------------------------

    local Destroyed =
        false


    local Entities =
        {}


    local Connections =
        {}


    ---------------------------------------------------------
    -- PERFORMANCE
    ---------------------------------------------------------

    -- O ESP visual é atualizado a 30 Hz.
    -- Isso já é suficientemente suave e corta bastante
    -- o custo das projeções 3D -> 2D.

    local UPDATE_RATE =
        1 / 30


    local UpdateAccumulator =
        0


    ---------------------------------------------------------
    -- BODY PART NAMES
    ---------------------------------------------------------

    local BodyPartNames = {

        -----------------------------------------------------
        -- CUSTOM PT-BR
        -----------------------------------------------------

        ["Cabeça"] = true,
        ["Cabeca"] = true,

        ["Tronco"] = true,

        ["Braço esquerdo"] = true,
        ["Braco esquerdo"] = true,

        ["Braço direito"] = true,
        ["Braco direito"] = true,

        ["Perna esquerda"] = true,
        ["Perna direita"] = true,


        -----------------------------------------------------
        -- R6
        -----------------------------------------------------

        ["Head"] = true,
        ["Torso"] = true,

        ["Left Arm"] = true,
        ["Right Arm"] = true,

        ["Left Leg"] = true,
        ["Right Leg"] = true,


        -----------------------------------------------------
        -- R15
        -----------------------------------------------------

        ["UpperTorso"] = true,
        ["LowerTorso"] = true,

        ["LeftUpperArm"] = true,
        ["LeftLowerArm"] = true,
        ["LeftHand"] = true,

        ["RightUpperArm"] = true,
        ["RightLowerArm"] = true,
        ["RightHand"] = true,

        ["LeftUpperLeg"] = true,
        ["LeftLowerLeg"] = true,
        ["LeftFoot"] = true,

        ["RightUpperLeg"] = true,
        ["RightLowerLeg"] = true,
        ["RightFoot"] = true,

    }


    ---------------------------------------------------------
    -- ESP GUI
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
    -- CREATE TEXT
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


        Text.Font =
            Enum.Font.Gotham


        Text.TextSize =
            13


        Text.TextColor3 =
            Settings.TextColor


        Text.TextStrokeColor3 =
            Color3.new(
                0,
                0,
                0
            )


        Text.TextStrokeTransparency =
            0.25


        Text.ZIndex =
            11


        Text.Visible =
            false


        Text.Parent =
            ScreenGui


        return Text

    end


    ---------------------------------------------------------
    -- CREATE VISUALS
    ---------------------------------------------------------

    local function CreateVisuals(
        Character
    )

        local Box =
            Instance.new(
                "Frame"
            )


        Box.Name =
            "ESP_"
            .. Character.Name


        Box.BackgroundTransparency =
            1


        Box.BorderSizePixel =
            0


        Box.Visible =
            false


        Box.ZIndex =
            10


        Box.Parent =
            ScreenGui


        local Stroke =
            Instance.new(
                "UIStroke"
            )


        Stroke.Color =
            Settings.BoxColor


        Stroke.Thickness =
            Settings.BoxThickness


        Stroke.LineJoinMode =
            Enum.LineJoinMode.Miter


        Stroke.Parent =
            Box


        return {

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

    end


    ---------------------------------------------------------
    -- HIDE
    ---------------------------------------------------------

    local function HideEntity(
        Data
    )

        if not Data then
            return
        end


        local Visuals =
            Data.Visuals


        if not Visuals then
            return
        end


        Visuals.Box.Visible =
            false


        Visuals.Name.Visible =
            false


        Visuals.Health.Visible =
            false


        Visuals.Distance.Visible =
            false

    end


    ---------------------------------------------------------
    -- PLAYER RESOLUTION
    ---------------------------------------------------------

    local function ResolvePlayer(
        Character
    )

        -----------------------------------------------------
        -- ATRIBUTO USER ID
        -----------------------------------------------------

        local UserId =
            Character:
                GetAttribute(
                    "UserId"
                )


        if UserId then

            local Success,
                Player =
                    pcall(
                        Players.GetPlayerByUserId,
                        Players,
                        tonumber(UserId)
                    )


            if Success
                and Player
            then

                return Player

            end

        end


        -----------------------------------------------------
        -- NOME DO MODEL
        -----------------------------------------------------

        local Player =
            Players:
                FindFirstChild(
                    Character.Name
                )


        if Player
            and Player:IsA("Player")
        then

            return Player

        end


        return nil

    end


    ---------------------------------------------------------
    -- LOCAL ENTITY?
    ---------------------------------------------------------

    local function IsLocalEntity(
        Character
    )

        local Player =
            ResolvePlayer(
                Character
            )


        if Player
            == LocalPlayer
        then

            return true

        end


        if
            Character.Name
            == LocalPlayer.Name
        then

            return true

        end


        if
            Character.Name
            == LocalPlayer.DisplayName
        then

            return true

        end


        if
            LocalPlayer.Character
            == Character
        then

            return true

        end


        return false

    end


    ---------------------------------------------------------
    -- BODY PART VALIDATION
    ---------------------------------------------------------

    local function IsBodyPart(
        Object
    )

        if
            not Object:
                IsA(
                    "BasePart"
                )
        then

            return false

        end


        if
            not BodyPartNames[
                Object.Name
            ]
        then

            return false

        end


        -----------------------------------------------------
        -- ACCESSORY
        -----------------------------------------------------

        if
            Object:
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
            Object:
                FindFirstAncestorWhichIsA(
                    "Tool"
                )
        then

            return false

        end


        -----------------------------------------------------
        -- WEAPON RIG
        -----------------------------------------------------

        local Parent =
            Object.Parent


        while Parent do

            if
                Parent.Name
                == "WeaponRig"
            then

                return false

            end


            Parent =
                Parent.Parent

        end


        return true

    end


    ---------------------------------------------------------
    -- CACHE BODY PART
    ---------------------------------------------------------

    local function AddBodyPart(
        Data,
        Object
    )

        if
            not IsBodyPart(
                Object
            )
        then

            return

        end


        Data.BodyParts[
            Object
        ] =
            true

    end


    ---------------------------------------------------------
    -- REMOVE BODY PART
    ---------------------------------------------------------

    local function RemoveBodyPart(
        Data,
        Object
    )

        Data.BodyParts[
            Object
        ] =
            nil

    end


    ---------------------------------------------------------
    -- REGISTER ENTITY
    ---------------------------------------------------------

    local function RegisterEntity(
        Character
    )

        if Destroyed then
            return
        end


        if
            not Character:
                IsA(
                    "Model"
                )
        then

            return
        end


        if
            Entities[
                Character
            ]
        then

            return
        end


        if
            IsLocalEntity(
                Character
            )
        then

            return
        end


        local Data = {

            Character =
                Character,

            BodyParts =
                {},

            Visuals =
                CreateVisuals(
                    Character
                ),

            Connections =
                {},

        }


        Entities[
            Character
        ] =
            Data


        -----------------------------------------------------
        -- BUILD INITIAL BODY CACHE
        -----------------------------------------------------

        for _, Object
            in ipairs(
                Character:
                    GetDescendants()
            )
        do

            AddBodyPart(
                Data,
                Object
            )

        end


        -----------------------------------------------------
        -- NEW BODY PARTS
        -----------------------------------------------------

        Data.Connections.DescendantAdded =
            Character.DescendantAdded:
                Connect(function(Object)

                    AddBodyPart(
                        Data,
                        Object
                    )

                end)


        -----------------------------------------------------
        -- REMOVED BODY PARTS
        -----------------------------------------------------

        Data.Connections.DescendantRemoving =
            Character.DescendantRemoving:
                Connect(function(Object)

                    RemoveBodyPart(
                        Data,
                        Object
                    )

                end)

    end


    ---------------------------------------------------------
    -- UNREGISTER ENTITY
    ---------------------------------------------------------

    local function UnregisterEntity(
        Character
    )

        local Data =
            Entities[
                Character
            ]


        if not Data then
            return
        end


        -----------------------------------------------------
        -- CONNECTIONS
        -----------------------------------------------------

        for _, Connection
            in pairs(
                Data.Connections
            )
        do

            if Connection then

                Connection:
                    Disconnect()

            end

        end


        -----------------------------------------------------
        -- VISUALS
        -----------------------------------------------------

        for _, Object
            in pairs(
                Data.Visuals
            )
        do

            if
                typeof(Object)
                == "Instance"
            then

                Object:
                    Destroy()

            end

        end


        Entities[
            Character
        ] =
            nil

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


        local PartCFrame =
            Part.CFrame


        -----------------------------------------------------
        -- 8 CORNERS
        -----------------------------------------------------

        local X =
            Half.X

        local Y =
            Half.Y

        local Z =
            Half.Z


        local Corners = {

            Vector3.new(-X, -Y, -Z),
            Vector3.new(-X, -Y,  Z),

            Vector3.new(-X,  Y, -Z),
            Vector3.new(-X,  Y,  Z),

            Vector3.new( X, -Y, -Z),
            Vector3.new( X, -Y,  Z),

            Vector3.new( X,  Y, -Z),
            Vector3.new( X,  Y,  Z),

        }


        for Index = 1, 8 do

            local WorldPosition =
                PartCFrame:
                    PointToWorldSpace(
                        Corners[Index]
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


                if
                    ScreenPosition.X
                    < Bounds.MinX
                then

                    Bounds.MinX =
                        ScreenPosition.X

                end


                if
                    ScreenPosition.Y
                    < Bounds.MinY
                then

                    Bounds.MinY =
                        ScreenPosition.Y

                end


                if
                    ScreenPosition.X
                    > Bounds.MaxX
                then

                    Bounds.MaxX =
                        ScreenPosition.X

                end


                if
                    ScreenPosition.Y
                    > Bounds.MaxY
                then

                    Bounds.MaxY =
                        ScreenPosition.Y

                end

            end

        end

    end


    ---------------------------------------------------------
    -- CHARACTER SCREEN BOUNDS
    ---------------------------------------------------------

    local function GetCharacterBounds(
        Data,
        Camera,
        Root
    )

        -----------------------------------------------------
        -- ROOT MUST BE IN FRONT
        -----------------------------------------------------

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


        -----------------------------------------------------
        -- CACHED PARTS
        -----------------------------------------------------

        for Part
            in pairs(
                Data.BodyParts
            )
        do

            if
                Part.Parent
                and Part:
                    IsDescendantOf(
                        Data.Character
                    )
            then

                ProjectPart(
                    Part,
                    Camera,
                    Bounds
                )

            else

                Data.BodyParts[
                    Part
                ] =
                    nil

            end

        end


        if
            not Bounds.HasPoint
        then

            return nil

        end


        -----------------------------------------------------
        -- VIEWPORT CHECK
        -----------------------------------------------------

        local Viewport =
            Camera.ViewportSize


        if
            Bounds.MaxX < 0
            or Bounds.MinX > Viewport.X
            or Bounds.MaxY < 0
            or Bounds.MinY > Viewport.Y
        then

            return nil

        end


        -----------------------------------------------------
        -- PADDING
        -----------------------------------------------------

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
            Bounds.MaxX
            - Bounds.MinX
            + Padding * 2


        local Height =
            Bounds.MaxY
            - Bounds.MinY
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

        }

    end


    ---------------------------------------------------------
    -- UPDATE ENTITY
    ---------------------------------------------------------

    local function UpdateEntity(
        Data,
        Camera
    )

        -----------------------------------------------------
        -- MASTER TOGGLE
        -----------------------------------------------------

        if
            not Settings.Enabled
        then

            HideEntity(
                Data
            )

            return

        end


        local Character =
            Data.Character


        if
            not Character.Parent
        then

            return

        end


        -----------------------------------------------------
        -- ROOT
        -----------------------------------------------------

        local Root =
            Character:
                FindFirstChild(
                    "HumanoidRootPart"
                )


        -----------------------------------------------------
        -- HUMANOID
        -----------------------------------------------------

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

            HideEntity(
                Data
            )

            return

        end


        -----------------------------------------------------
        -- DISTANCE
        -----------------------------------------------------

        local Distance =
            (
                Root.Position
                - Camera.CFrame.Position
            ).Magnitude


        local MaxDistance =
            tonumber(
                Settings.MaxDistance
            )
            or 1000


        if
            Distance
            > MaxDistance
        then

            HideEntity(
                Data
            )

            return

        end


        -----------------------------------------------------
        -- SCREEN BOUNDS
        -----------------------------------------------------

        local Bounds =
            GetCharacterBounds(
                Data,
                Camera,
                Root
            )


        if not Bounds then

            HideEntity(
                Data
            )

            return

        end


        local Visuals =
            Data.Visuals


        -----------------------------------------------------
        -- APPEARANCE
        -----------------------------------------------------

        Visuals.Stroke.Color =
            Settings.BoxColor


        Visuals.Stroke.Thickness =
            tonumber(
                Settings.BoxThickness
            )
            or 1


        Visuals.Name.TextColor3 =
            Settings.TextColor


        Visuals.Health.TextColor3 =
            Settings.TextColor


        Visuals.Distance.TextColor3 =
            Settings.TextColor


        -----------------------------------------------------
        -- BOX
        -----------------------------------------------------

        Visuals.Box.Position =
            UDim2.fromOffset(
                math.floor(
                    Bounds.X
                ),

                math.floor(
                    Bounds.Y
                )
            )


        Visuals.Box.Size =
            UDim2.fromOffset(
                math.floor(
                    Bounds.Width
                ),

                math.floor(
                    Bounds.Height
                )
            )


        Visuals.Box.Visible =
            Settings.Box
            == true


        -----------------------------------------------------
        -- PLAYER NAME
        -----------------------------------------------------

        local Player =
            ResolvePlayer(
                Character
            )


        local DisplayName =
            Player
            and Player.Name
            or Character.Name


        Visuals.Name.Text =
            DisplayName


        Visuals.Name.Position =
            UDim2.fromOffset(
                Bounds.CenterX,
                Bounds.Y - 12
            )


        Visuals.Name.Visible =
            Settings.Name
            == true


        -----------------------------------------------------
        -- HEALTH
        -----------------------------------------------------

        Visuals.Health.Text =
            string.format(
                "%d/%d HP",

                math.floor(
                    Humanoid.Health
                ),

                math.floor(
                    Humanoid.MaxHealth
                )
            )


        Visuals.Health.Position =
            UDim2.fromOffset(
                Bounds.CenterX,

                Bounds.Y
                + Bounds.Height
                + 10
            )


        Visuals.Health.Visible =
            Settings.Health
            == true


        -----------------------------------------------------
        -- DISTANCE TEXT
        -----------------------------------------------------

        Visuals.Distance.Text =
            string.format(
                "%.0f studs",
                Distance
            )


        Visuals.Distance.Position =
            UDim2.fromOffset(
                Bounds.CenterX,

                Bounds.Y
                + Bounds.Height
                + 27
            )


        Visuals.Distance.Visible =
            Settings.Distance
            == true

    end


    ---------------------------------------------------------
    -- REGISTER EXISTING ENTITIES
    ---------------------------------------------------------

    for _, Character
        in ipairs(
            EntitiesFolder:
                GetChildren()
        )
    do

        RegisterEntity(
            Character
        )

    end


    ---------------------------------------------------------
    -- ENTITY ADDED
    ---------------------------------------------------------

    Connections.EntityAdded =
        EntitiesFolder.ChildAdded:
            Connect(function(Character)

                RegisterEntity(
                    Character
                )

            end)


    ---------------------------------------------------------
    -- ENTITY REMOVED
    ---------------------------------------------------------

    Connections.EntityRemoved =
        EntitiesFolder.ChildRemoved:
            Connect(function(Character)

                UnregisterEntity(
                    Character
                )

            end)


    ---------------------------------------------------------
    -- RENDER LOOP
    ---------------------------------------------------------

    Connections.Render =
        RunService.RenderStepped:
            Connect(function(DeltaTime)

                if Destroyed then
                    return
                end


                UpdateAccumulator +=
                    DeltaTime


                if
                    UpdateAccumulator
                    < UPDATE_RATE
                then

                    return

                end


                UpdateAccumulator =
                    0


                local Camera =
                    Workspace.CurrentCamera


                if not Camera then
                    return
                end


                -------------------------------------------------
                -- MASTER DISABLED
                -------------------------------------------------

                if
                    not Settings.Enabled
                then

                    for _, Data
                        in pairs(
                            Entities
                        )
                    do

                        HideEntity(
                            Data
                        )

                    end


                    return

                end


                -------------------------------------------------
                -- UPDATE
                -------------------------------------------------

                for Character,
                    Data
                    in pairs(
                        Entities
                    )
                do

                    if
                        Character.Parent
                        == EntitiesFolder
                    then

                        UpdateEntity(
                            Data,
                            Camera
                        )

                    else

                        UnregisterEntity(
                            Character
                        )

                    end

                end

            end)


    ---------------------------------------------------------
    -- CONTROLLER
    ---------------------------------------------------------

    local Controller =
        {}


    function Controller.Toggle(
        Value
    )

        Settings.Enabled =
            Value == true

    end


    ---------------------------------------------------------
    -- DEBUG API
    ---------------------------------------------------------

    function Controller.GetEntityCount()

        local Count =
            0


        for _
            in pairs(
                Entities
            )
        do

            Count += 1

        end


        return Count

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
        -- GLOBAL CONNECTIONS
        -----------------------------------------------------

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


        -----------------------------------------------------
        -- ENTITIES
        -----------------------------------------------------

        local ToRemove =
            {}


        for Character
            in pairs(
                Entities
            )
        do

            table.insert(
                ToRemove,
                Character
            )

        end


        for _, Character
            in ipairs(
                ToRemove
            )
        do

            UnregisterEntity(
                Character
            )

        end


        -----------------------------------------------------
        -- GUI
        -----------------------------------------------------

        if ScreenGui then

            ScreenGui:
                Destroy()

        end

    end


    return Controller

end


return ESP