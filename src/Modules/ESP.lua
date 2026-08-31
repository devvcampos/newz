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
    -- ENTITY FOLDER
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


    local LocalEntity =
        nil


    ---------------------------------------------------------
    -- PERFORMANCE
    ---------------------------------------------------------

    local UPDATE_RATE =
        1 / 30


    local UpdateAccumulator =
        0


    ---------------------------------------------------------
    -- VISIBILITY
    ---------------------------------------------------------

    local VisibilityParams =
        RaycastParams.new()


    VisibilityParams.FilterType =
        Enum.RaycastFilterType.Exclude


    VisibilityParams.IgnoreWater =
        true


    ---------------------------------------------------------
    -- BODY PARTS
    ---------------------------------------------------------

    local BodyPartNames = {

        -----------------------------------------------------
        -- CUSTOM CHARACTER
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

        OldGui:
            Destroy()

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
                220,
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
            or Color3.new(
                1,
                1,
                1
            )


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


        -----------------------------------------------------
        -- FULL BOX STROKE
        -----------------------------------------------------

        local Stroke =
            Instance.new(
                "UIStroke"
            )


        Stroke.Color =
            Settings.BoxColor
            or Color3.new(
                1,
                1,
                1
            )


        Stroke.Thickness =
            Settings.BoxThickness
            or 1


        Stroke.LineJoinMode =
            Enum.LineJoinMode.Miter


        Stroke.Enabled =
            false


        Stroke.Parent =
            Box


        -----------------------------------------------------
        -- CORNER BOX
        -----------------------------------------------------

        local Corners =
            {}


        for Index = 1, 8 do

            local Line =
                Instance.new(
                    "Frame"
                )


            Line.Name =
                "Corner"
                .. Index


            Line.BorderSizePixel =
                0


            Line.BackgroundColor3 =
                Settings.BoxColor
                or Color3.new(
                    1,
                    1,
                    1
                )


            Line.Visible =
                false


            Line.ZIndex =
                11


            Line.Parent =
                Box


            Corners[
                Index
            ] =
                Line

        end


        -----------------------------------------------------
        -- DATA
        -----------------------------------------------------

        return {

            Box =
                Box,

            Stroke =
                Stroke,

            Corners =
                Corners,

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

        if
            not Data
            or not Data.Visuals
        then

            return

        end


        local Visuals =
            Data.Visuals


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
    -- RESOLVE PLAYER
    ---------------------------------------------------------

    local function ResolvePlayer(
        Character
    )

        -----------------------------------------------------
        -- USERID ATTRIBUTE
        -----------------------------------------------------

        local UserId =
            Character:
                GetAttribute(
                    "UserId"
                )


        if UserId then

            local NumericUserId =
                tonumber(
                    UserId
                )


            if NumericUserId then

                local Success,
                    Player =
                        pcall(
                            Players.GetPlayerByUserId,
                            Players,
                            NumericUserId
                        )


                if
                    Success
                    and Player
                then

                    return Player

                end

            end

        end


        -----------------------------------------------------
        -- CHARACTER NAME
        -----------------------------------------------------

        local Player =
            Players:
                FindFirstChild(
                    Character.Name
                )


        if
            Player
            and Player:IsA(
                "Player"
            )
        then

            return Player

        end


        -----------------------------------------------------
        -- DISPLAY NAME
        -----------------------------------------------------

        for _, OtherPlayer
            in ipairs(
                Players:
                    GetPlayers()
            )
        do

            if
                OtherPlayer.DisplayName
                == Character.Name
            then

                return OtherPlayer

            end

        end


        return nil

    end


    ---------------------------------------------------------
    -- LOCAL ENTITY
    ---------------------------------------------------------

    local function IsLocalEntity(
        Character
    )

        if
            LocalPlayer.Character
            == Character
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


        local Player =
            ResolvePlayer(
                Character
            )


        return
            Player
            == LocalPlayer

    end


    ---------------------------------------------------------
    -- BODY PART CHECK
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
        -- ACCESSORIES
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
        -- TOOLS
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
            IsBodyPart(
                Object
            )
        then

            Data.BodyParts[
                Object
            ] =
                true

        end

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


        -----------------------------------------------------
        -- LOCAL PLAYER
        -----------------------------------------------------

        if
            IsLocalEntity(
                Character
            )
        then

            LocalEntity =
                Character

            return

        end


        -----------------------------------------------------
        -- DATA
        -----------------------------------------------------

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

            LastVisibilityCheck =
                0,

            LastVisibility =
                false,

        }


        Entities[
            Character
        ] =
            Data


        -----------------------------------------------------
        -- INITIAL CACHE
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
        -- NEW PARTS
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
        -- REMOVED PARTS
        -----------------------------------------------------

        Data.Connections.DescendantRemoving =
            Character.DescendantRemoving:
                Connect(function(Object)

                    Data.BodyParts[
                        Object
                    ] =
                        nil

                end)

    end


    ---------------------------------------------------------
    -- UNREGISTER
    ---------------------------------------------------------

    local function UnregisterEntity(
        Character
    )

        local Data =
            Entities[
                Character
            ]


        if not Data then

            if
                Character
                == LocalEntity
            then

                LocalEntity =
                    nil

            end


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

                pcall(function()

                    Connection:
                        Disconnect()

                end)

            end

        end


        -----------------------------------------------------
        -- VISUALS
        -----------------------------------------------------

        if Data.Visuals then

            if
                Data.Visuals.Box
            then

                pcall(function()

                    Data.Visuals.Box:
                        Destroy()

                end)

            end


            for _, Name
                in ipairs({
                    "Name",
                    "Health",
                    "Distance"
                })
            do

                local Object =
                    Data.Visuals[
                        Name
                    ]


                if Object then

                    pcall(function()

                        Object:
                            Destroy()

                    end)

                end

            end

        end


        Entities[
            Character
        ] =
            nil

    end


    ---------------------------------------------------------
    -- TEAM CHECK
    ---------------------------------------------------------

    local function IsTeammate(
        Character
    )

        if
            not Settings.TeamCheck
        then

            return false

        end


        local Player =
            ResolvePlayer(
                Character
            )


        if not Player then
            return false
        end


        if
            not LocalPlayer.Team
            or not Player.Team
        then

            return false
        end


        return
            Player.Team
            == LocalPlayer.Team

    end


    ---------------------------------------------------------
    -- HEALTH COLOR
    ---------------------------------------------------------

    local function GetHealthColor(
        Humanoid
    )

        if
            not Settings.DynamicHealthColor
        then

            return
                Settings.TextColor
                or Color3.new(
                    1,
                    1,
                    1
                )

        end


        local MaxHealth =
            math.max(
                Humanoid.MaxHealth,
                1
            )


        local Ratio =
            math.clamp(
                Humanoid.Health
                / MaxHealth,
                0,
                1
            )


        -----------------------------------------------------
        -- RED -> YELLOW -> GREEN
        -----------------------------------------------------

        return Color3.fromHSV(
            Ratio * 0.33,
            0.85,
            1
        )

    end


    ---------------------------------------------------------
    -- VISIBILITY CHECK
    ---------------------------------------------------------

    local function IsEntityVisible(
        Data,
        Camera,
        Root
    )

        if
            not Settings.VisibilityCheck
        then

            return true

        end


        -----------------------------------------------------
        -- THROTTLE
        -----------------------------------------------------

        local Now =
            os.clock()


        if
            Now
            - Data.LastVisibilityCheck
            < 0.10
        then

            return
                Data.LastVisibility

        end


        Data.LastVisibilityCheck =
            Now


        -----------------------------------------------------
        -- TARGET
        -----------------------------------------------------

        local Character =
            Data.Character


        local Target =
            Character:
                FindFirstChild(
                    "Cabeça"
                )
            or Character:
                FindFirstChild(
                    "Cabeca"
                )
            or Character:
                FindFirstChild(
                    "Head"
                )
            or Character:
                FindFirstChild(
                    "Tronco"
                )
            or Root


        if not Target then

            Data.LastVisibility =
                false

            return false

        end


        -----------------------------------------------------
        -- IGNORE
        -----------------------------------------------------

        local Ignore =
            {
                Camera
            }


        if LocalPlayer.Character then

            table.insert(
                Ignore,
                LocalPlayer.Character
            )

        end


        if LocalEntity then

            table.insert(
                Ignore,
                LocalEntity
            )

        end


        VisibilityParams.FilterDescendantsInstances =
            Ignore


        -----------------------------------------------------
        -- RAYCAST
        -----------------------------------------------------

        local Origin =
            Camera.CFrame.Position


        local Direction =
            Target.Position
            - Origin


        local Result =
            Workspace:
                Raycast(
                    Origin,
                    Direction,
                    VisibilityParams
                )


        local Visible =
            false


        if not Result then

            Visible =
                true

        elseif
            Result.Instance
            and Result.Instance:
                IsDescendantOf(
                    Character
                )
        then

            Visible =
                true

        end


        Data.LastVisibility =
            Visible


        return Visible

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


        local X =
            Half.X

        local Y =
            Half.Y

        local Z =
            Half.Z


        local PartCFrame =
            Part.CFrame


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
                        Corners[
                            Index
                        ]
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
        Data,
        Camera,
        Root
    )

        -----------------------------------------------------
        -- ROOT IN FRONT OF CAMERA
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
        -- CACHED BODY PARTS
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
        -- VIEWPORT
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
    -- CORNER BOX
    ---------------------------------------------------------

    local function UpdateCornerBox(
        Visuals,
        Width,
        Height,
        Color
    )

        local Thickness =
            math.max(
                1,

                tonumber(
                    Settings.BoxThickness
                )
                or 1
            )


        local Ratio =
            tonumber(
                Settings.CornerRatio
            )
            or 0.25


        Ratio =
            math.clamp(
                Ratio,
                0.05,
                0.50
            )


        local Corner =
            math.max(
                5,

                math.floor(
                    math.min(
                        Width,
                        Height
                    )
                    * Ratio
                )
            )


        Corner =
            math.min(
                Corner,
                Width / 2,
                Height / 2
            )


        local C =
            Visuals.Corners


        for _, Line
            in ipairs(
                C
            )
        do

            Line.BackgroundColor3 =
                Color

        end


        -----------------------------------------------------
        -- TOP LEFT
        -----------------------------------------------------

        C[1].Position =
            UDim2.fromOffset(
                0,
                0
            )


        C[1].Size =
            UDim2.fromOffset(
                Corner,
                Thickness
            )


        C[2].Position =
            UDim2.fromOffset(
                0,
                0
            )


        C[2].Size =
            UDim2.fromOffset(
                Thickness,
                Corner
            )


        -----------------------------------------------------
        -- TOP RIGHT
        -----------------------------------------------------

        C[3].Position =
            UDim2.fromOffset(
                Width - Corner,
                0
            )


        C[3].Size =
            UDim2.fromOffset(
                Corner,
                Thickness
            )


        C[4].Position =
            UDim2.fromOffset(
                Width - Thickness,
                0
            )


        C[4].Size =
            UDim2.fromOffset(
                Thickness,
                Corner
            )


        -----------------------------------------------------
        -- BOTTOM LEFT
        -----------------------------------------------------

        C[5].Position =
            UDim2.fromOffset(
                0,
                Height - Thickness
            )


        C[5].Size =
            UDim2.fromOffset(
                Corner,
                Thickness
            )


        C[6].Position =
            UDim2.fromOffset(
                0,
                Height - Corner
            )


        C[6].Size =
            UDim2.fromOffset(
                Thickness,
                Corner
            )


        -----------------------------------------------------
        -- BOTTOM RIGHT
        -----------------------------------------------------

        C[7].Position =
            UDim2.fromOffset(
                Width - Corner,
                Height - Thickness
            )


        C[7].Size =
            UDim2.fromOffset(
                Corner,
                Thickness
            )


        C[8].Position =
            UDim2.fromOffset(
                Width - Thickness,
                Height - Corner
            )


        C[8].Size =
            UDim2.fromOffset(
                Thickness,
                Corner
            )

    end


    ---------------------------------------------------------
    -- UPDATE ENTITY
    ---------------------------------------------------------

    local function UpdateEntity(
        Data,
        Camera
    )

        -----------------------------------------------------
        -- MASTER
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

            HideEntity(
                Data
            )

            return

        end


        -----------------------------------------------------
        -- LOCAL ENTITY SAFETY
        -----------------------------------------------------

        if
            IsLocalEntity(
                Character
            )
        then

            LocalEntity =
                Character


            HideEntity(
                Data
            )


            return

        end


        -----------------------------------------------------
        -- PLAYER
        -----------------------------------------------------

        local Player =
            ResolvePlayer(
                Character
            )


        -----------------------------------------------------
        -- PLAYERS ONLY
        -----------------------------------------------------

        if
            Settings.PlayersOnly
            and not Player
        then

            HideEntity(
                Data
            )

            return

        end


        -----------------------------------------------------
        -- TEAM CHECK
        -----------------------------------------------------

        if
            IsTeammate(
                Character
            )
        then

            HideEntity(
                Data
            )

            return

        end


        -----------------------------------------------------
        -- ROOT / HUMANOID
        -----------------------------------------------------

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


        -----------------------------------------------------
        -- VISIBILITY
        -----------------------------------------------------

        local Visible =
            IsEntityVisible(
                Data,
                Camera,
                Root
            )


        -----------------------------------------------------
        -- BOX COLOR
        -----------------------------------------------------

-----------------------------------------------------
-- BOX COLOR
-----------------------------------------------------

local DefaultBoxColor =
    Settings.BoxColor
    or Color3.fromRGB(
        255,
        255,
        255
    )


local HiddenBoxColor =
    Settings.HiddenColor
    or Color3.fromRGB(
        255,
        90,
        90
    )


local BoxColor =
    DefaultBoxColor


-----------------------------------------------------
-- VISIBILITY COLOR
-----------------------------------------------------

if
    Settings.VisibilityCheck
    and not Visible
then

    BoxColor =
        HiddenBoxColor

end


        -----------------------------------------------------
        -- VISUAL DATA
        -----------------------------------------------------

        local Visuals =
            Data.Visuals


        Visuals.Stroke.Color =
            BoxColor


        Visuals.Stroke.Thickness =
            tonumber(
                Settings.BoxThickness
            )
            or 1


        -----------------------------------------------------
        -- BOX POSITION
        -----------------------------------------------------

        local BoxWidth =
            math.floor(
                Bounds.Width
            )


        local BoxHeight =
            math.floor(
                Bounds.Height
            )


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
                BoxWidth,
                BoxHeight
            )


        -----------------------------------------------------
        -- BOX STYLE
        -----------------------------------------------------

        local BoxEnabled =
            Settings.Box
            == true


        local BoxStyle =
            Settings.BoxStyle
            or "Corner"


        local CornerStyle =
            BoxStyle
            == "Corner"


        Visuals.Box.Visible =
            BoxEnabled


        Visuals.Stroke.Enabled =
            BoxEnabled
            and not CornerStyle


        for _, Line
            in ipairs(
                Visuals.Corners
            )
        do

            Line.Visible =
                BoxEnabled
                and CornerStyle

        end


        if
            BoxEnabled
            and CornerStyle
        then

            UpdateCornerBox(
                Visuals,
                BoxWidth,
                BoxHeight,
                BoxColor
            )

        end


        -----------------------------------------------------
        -- TEXT COLORS
        -----------------------------------------------------

        local TextColor =
            Settings.TextColor
            or Color3.new(
                1,
                1,
                1
            )


        Visuals.Name.TextColor3 =
            TextColor


        Visuals.Distance.TextColor3 =
            TextColor


        Visuals.Health.TextColor3 =
            GetHealthColor(
                Humanoid
            )


        -----------------------------------------------------
        -- NAME
        -----------------------------------------------------

        local DisplayName


        if Player then

            DisplayName =
                Player.Name

        else

            DisplayName =
                Character.Name

        end


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
        -- DISTANCE
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
    -- REGISTER EXISTING
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

                task.defer(function()

                    if
                        Character.Parent
                        == EntitiesFolder
                    then

                        RegisterEntity(
                            Character
                        )

                    end

                end)

            end)


    ---------------------------------------------------------
    -- ENTITY REMOVED
    ---------------------------------------------------------

    Connections.EntityRemoved =
        EntitiesFolder.ChildRemoved:
            Connect(function(Character)

                if
                    Character
                    == LocalEntity
                then

                    LocalEntity =
                        nil

                end


                UnregisterEntity(
                    Character
                )

            end)


    ---------------------------------------------------------
    -- RENDER
    ---------------------------------------------------------

    Connections.Render =
        RunService.RenderStepped:
            Connect(function(
                DeltaTime
            )

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
                    UpdateAccumulator
                    - UPDATE_RATE


                -------------------------------------------------
                -- CAMERA
                -------------------------------------------------

                local Camera =
                    Workspace.CurrentCamera


                if not Camera then
                    return
                end


                -------------------------------------------------
                -- ESP DISABLED
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
                -- UPDATE ENTITIES
                -------------------------------------------------

                local RemoveQueue =
                    {}


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

                        table.insert(
                            RemoveQueue,
                            Character
                        )

                    end

                end


                -------------------------------------------------
                -- CLEAN STALE ENTITIES
                -------------------------------------------------

                for _, Character
                    in ipairs(
                        RemoveQueue
                    )
                do

                    UnregisterEntity(
                        Character
                    )

                end

            end)


    ---------------------------------------------------------
    -- CONTROLLER
    ---------------------------------------------------------

    local Controller =
        {}


    ---------------------------------------------------------
    -- TOGGLE
    ---------------------------------------------------------

    function Controller.Toggle(
        Value
    )

        Settings.Enabled =
            Value == true

    end


    ---------------------------------------------------------
    -- ENTITY COUNT
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
    -- GET LOCAL ENTITY
    ---------------------------------------------------------

    function Controller.GetLocalEntity()

        return
            LocalEntity

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

                pcall(function()

                    Connection:
                        Disconnect()

                end)

            end

        end


        table.clear(
            Connections
        )


        -----------------------------------------------------
        -- ENTITY LIST
        -----------------------------------------------------

        local RemoveQueue =
            {}


        for Character
            in pairs(
                Entities
            )
        do

            table.insert(
                RemoveQueue,
                Character
            )

        end


        for _, Character
            in ipairs(
                RemoveQueue
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

            pcall(function()

                ScreenGui:
                    Destroy()

            end)

        end

    end


    return Controller

end


return ESP