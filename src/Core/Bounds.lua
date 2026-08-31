local Bounds = {}

function Bounds.New(Dependencies)
    local Profiler =
        Dependencies
        and Dependencies.Profiler
        or nil

    local ProfileBegin =
        Profiler
        and Profiler.Begin
        or function()
            return nil
        end

    local ProfileFinish =
        Profiler
        and Profiler.Finish
        or function()
        end

    local BodyPartNames = {
        ["Head"] = true,
        ["Head2"] = true,
        ["Torso"] = true,
        ["Left Arm"] = true,
        ["Right Arm"] = true,
        ["Left Leg"] = true,
        ["Right Leg"] = true,

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

    local Projection = {
        Valid = false,
        CameraCFrame = CFrame.new(),

        CenterX = 0,
        CenterY = 0,

        FocalX = 0,
        FocalY = 0,

        ViewportX = 0,
        ViewportY = 0,
    }

    local function IsBodyPart(Object)
        if not Object or not Object:IsA("BasePart") then
            return false
        end

        if not BodyPartNames[Object.Name] then
            return false
        end

        if Object:FindFirstAncestorWhichIsA("Accessory") then
            return false
        end

        if Object:FindFirstAncestorWhichIsA("Tool") then
            return false
        end

        return true
    end

    local function AddLegacyProjectedCorner(
        Camera,
        State,
        PartCFrame,
        OffsetX,
        OffsetY,
        OffsetZ
    )
        local WorldPosition =
            PartCFrame:PointToWorldSpace(
                Vector3.new(
                    OffsetX,
                    OffsetY,
                    OffsetZ
                )
            )

        local ScreenPosition =
            Camera:WorldToViewportPoint(
                WorldPosition
            )

        if ScreenPosition.Z <= 0.05 then
            return
        end

        State.HasPoint = true

        if ScreenPosition.X < State.MinX then
            State.MinX = ScreenPosition.X
        end

        if ScreenPosition.Y < State.MinY then
            State.MinY = ScreenPosition.Y
        end

        if ScreenPosition.X > State.MaxX then
            State.MaxX = ScreenPosition.X
        end

        if ScreenPosition.Y > State.MaxY then
            State.MaxY = ScreenPosition.Y
        end
    end

    local function ProjectPartLegacy(
        Part,
        Camera,
        State
    )
        local Size = Part.Size
        local X = Size.X * 0.5
        local Y = Size.Y * 0.5
        local Z = Size.Z * 0.5
        local PartCFrame = Part.CFrame

        AddLegacyProjectedCorner(Camera, State, PartCFrame, -X, -Y, -Z)
        AddLegacyProjectedCorner(Camera, State, PartCFrame, -X, -Y,  Z)
        AddLegacyProjectedCorner(Camera, State, PartCFrame, -X,  Y, -Z)
        AddLegacyProjectedCorner(Camera, State, PartCFrame, -X,  Y,  Z)
        AddLegacyProjectedCorner(Camera, State, PartCFrame,  X, -Y, -Z)
        AddLegacyProjectedCorner(Camera, State, PartCFrame,  X, -Y,  Z)
        AddLegacyProjectedCorner(Camera, State, PartCFrame,  X,  Y, -Z)
        AddLegacyProjectedCorner(Camera, State, PartCFrame,  X,  Y,  Z)
    end

    local function ProjectPartFast(
        Part,
        State
    )
        local Size = Part.Size
        local X = Size.X * 0.5
        local Y = Size.Y * 0.5
        local Z = Size.Z * 0.5

        local CameraPartCFrame =
            Projection.CameraCFrame:ToObjectSpace(
                Part.CFrame
            )

        local PX,
            PY,
            PZ,
            R00,
            R01,
            R02,
            R10,
            R11,
            R12,
            R20,
            R21,
            R22 =
                CameraPartCFrame:GetComponents()

        local XX = R00 * X
        local XY = R01 * Y
        local XZ = R02 * Z

        local YX = R10 * X
        local YY = R11 * Y
        local YZ = R12 * Z

        local ZX = R20 * X
        local ZY = R21 * Y
        local ZZ = R22 * Z

        local CenterX = Projection.CenterX
        local CenterY = Projection.CenterY
        local FocalX = Projection.FocalX
        local FocalY = Projection.FocalY

        local MinX = State.MinX
        local MinY = State.MinY
        local MaxX = State.MaxX
        local MaxY = State.MaxY
        local HasPoint = State.HasPoint

        local CameraX
        local CameraY
        local Depth
        local ScreenX
        local ScreenY

        CameraX = PX - XX - XY - XZ
        CameraY = PY - YX - YY - YZ
        Depth = -(PZ - ZX - ZY - ZZ)

        if Depth > 0.05 then
            ScreenX = CenterX + CameraX * FocalX / Depth
            ScreenY = CenterY - CameraY * FocalY / Depth
            HasPoint = true

            if ScreenX < MinX then MinX = ScreenX end
            if ScreenY < MinY then MinY = ScreenY end
            if ScreenX > MaxX then MaxX = ScreenX end
            if ScreenY > MaxY then MaxY = ScreenY end
        end

        CameraX = PX - XX - XY + XZ
        CameraY = PY - YX - YY + YZ
        Depth = -(PZ - ZX - ZY + ZZ)

        if Depth > 0.05 then
            ScreenX = CenterX + CameraX * FocalX / Depth
            ScreenY = CenterY - CameraY * FocalY / Depth
            HasPoint = true

            if ScreenX < MinX then MinX = ScreenX end
            if ScreenY < MinY then MinY = ScreenY end
            if ScreenX > MaxX then MaxX = ScreenX end
            if ScreenY > MaxY then MaxY = ScreenY end
        end

        CameraX = PX - XX + XY - XZ
        CameraY = PY - YX + YY - YZ
        Depth = -(PZ - ZX + ZY - ZZ)

        if Depth > 0.05 then
            ScreenX = CenterX + CameraX * FocalX / Depth
            ScreenY = CenterY - CameraY * FocalY / Depth
            HasPoint = true

            if ScreenX < MinX then MinX = ScreenX end
            if ScreenY < MinY then MinY = ScreenY end
            if ScreenX > MaxX then MaxX = ScreenX end
            if ScreenY > MaxY then MaxY = ScreenY end
        end

        CameraX = PX - XX + XY + XZ
        CameraY = PY - YX + YY + YZ
        Depth = -(PZ - ZX + ZY + ZZ)

        if Depth > 0.05 then
            ScreenX = CenterX + CameraX * FocalX / Depth
            ScreenY = CenterY - CameraY * FocalY / Depth
            HasPoint = true

            if ScreenX < MinX then MinX = ScreenX end
            if ScreenY < MinY then MinY = ScreenY end
            if ScreenX > MaxX then MaxX = ScreenX end
            if ScreenY > MaxY then MaxY = ScreenY end
        end

        CameraX = PX + XX - XY - XZ
        CameraY = PY + YX - YY - YZ
        Depth = -(PZ + ZX - ZY - ZZ)

        if Depth > 0.05 then
            ScreenX = CenterX + CameraX * FocalX / Depth
            ScreenY = CenterY - CameraY * FocalY / Depth
            HasPoint = true

            if ScreenX < MinX then MinX = ScreenX end
            if ScreenY < MinY then MinY = ScreenY end
            if ScreenX > MaxX then MaxX = ScreenX end
            if ScreenY > MaxY then MaxY = ScreenY end
        end

        CameraX = PX + XX - XY + XZ
        CameraY = PY + YX - YY + YZ
        Depth = -(PZ + ZX - ZY + ZZ)

        if Depth > 0.05 then
            ScreenX = CenterX + CameraX * FocalX / Depth
            ScreenY = CenterY - CameraY * FocalY / Depth
            HasPoint = true

            if ScreenX < MinX then MinX = ScreenX end
            if ScreenY < MinY then MinY = ScreenY end
            if ScreenX > MaxX then MaxX = ScreenX end
            if ScreenY > MaxY then MaxY = ScreenY end
        end

        CameraX = PX + XX + XY - XZ
        CameraY = PY + YX + YY - YZ
        Depth = -(PZ + ZX + ZY - ZZ)

        if Depth > 0.05 then
            ScreenX = CenterX + CameraX * FocalX / Depth
            ScreenY = CenterY - CameraY * FocalY / Depth
            HasPoint = true

            if ScreenX < MinX then MinX = ScreenX end
            if ScreenY < MinY then MinY = ScreenY end
            if ScreenX > MaxX then MaxX = ScreenX end
            if ScreenY > MaxY then MaxY = ScreenY end
        end

        CameraX = PX + XX + XY + XZ
        CameraY = PY + YX + YY + YZ
        Depth = -(PZ + ZX + ZY + ZZ)

        if Depth > 0.05 then
            ScreenX = CenterX + CameraX * FocalX / Depth
            ScreenY = CenterY - CameraY * FocalY / Depth
            HasPoint = true

            if ScreenX < MinX then MinX = ScreenX end
            if ScreenY < MinY then MinY = ScreenY end
            if ScreenX > MaxX then MaxX = ScreenX end
            if ScreenY > MaxY then MaxY = ScreenY end
        end

        State.MinX = MinX
        State.MinY = MinY
        State.MaxX = MaxX
        State.MaxY = MaxY
        State.HasPoint = HasPoint
    end

    local function RootIsInFront(
        Camera,
        Root
    )
        if Projection.Valid then
            local CameraPosition =
                Projection.CameraCFrame:PointToObjectSpace(
                    Root.Position
                )

            return -CameraPosition.Z > 0.05
        end

        local RootScreen =
            Camera:WorldToViewportPoint(
                Root.Position
            )

        return RootScreen.Z > 0.05
    end

    local Controller = {}

    function Controller.CreateState()
        return {
            MinX = math.huge,
            MinY = math.huge,

            MaxX = -math.huge,
            MaxY = -math.huge,

            HasPoint = false,

            X = 0,
            Y = 0,

            Width = 0,
            Height = 0,

            CenterX = 0,
            CenterY = 0,
        }
    end

    function Controller.AddBodyPart(
        Data,
        Object
    )
        if not IsBodyPart(Object) then
            return false
        end

        Data.BodyParts[Object] = true

        if
            Object.Name == "Head"
            or Object.Name == "Head2"
        then
            Data.Head = Object
        elseif Object.Name == "UpperTorso" then
            Data.UpperTorso = Object
        elseif Object.Name == "LowerTorso" then
            Data.LowerTorso = Object
        elseif Object.Name == "Torso" then
            Data.Torso = Object
        end

        return true
    end

    function Controller.RemoveBodyPart(
        Data,
        Object
    )
        Data.BodyParts[Object] = nil

        if Data.Head == Object then
            Data.Head = nil
        end

        if Data.UpperTorso == Object then
            Data.UpperTorso = nil
        end

        if Data.LowerTorso == Object then
            Data.LowerTorso = nil
        end

        if Data.Torso == Object then
            Data.Torso = nil
        end
    end

    function Controller.FindCorpseRoot(
        Corpse
    )
        for _, Name in ipairs({
            "HumanoidRootPart",
            "UpperTorso",
            "LowerTorso",
            "Torso",
            "Head2",
            "Head",
        }) do
            local Part =
                Corpse:FindFirstChild(
                    Name
                )

            if Part and Part:IsA("BasePart") then
                return Part
            end
        end

        return nil
    end

    function Controller.UpdateProjection(
        Camera
    )
        local ProjectionStart =
            ProfileBegin(
                "Projection.Setup"
            )

        local CameraCFrame = Camera.CFrame
        local CameraPosition = CameraCFrame.Position

        local CenterWorld =
            CameraPosition
            + CameraCFrame.LookVector

        local RightWorld =
            CenterWorld
            + CameraCFrame.RightVector

        local UpWorld =
            CenterWorld
            + CameraCFrame.UpVector

        local CenterScreen =
            Camera:WorldToViewportPoint(
                CenterWorld
            )

        local RightScreen =
            Camera:WorldToViewportPoint(
                RightWorld
            )

        local UpScreen =
            Camera:WorldToViewportPoint(
                UpWorld
            )

        local FocalX =
            RightScreen.X
            - CenterScreen.X

        local FocalY =
            CenterScreen.Y
            - UpScreen.Y

        local Viewport = Camera.ViewportSize

        Projection.CameraCFrame = CameraCFrame
        Projection.CenterX = CenterScreen.X
        Projection.CenterY = CenterScreen.Y
        Projection.FocalX = FocalX
        Projection.FocalY = FocalY
        Projection.ViewportX = Viewport.X
        Projection.ViewportY = Viewport.Y

        Projection.Valid =
            CenterScreen.Z > 0.05
            and math.abs(FocalX) > 0.001
            and math.abs(FocalY) > 0.001
            and Viewport.X > 0
            and Viewport.Y > 0

        ProfileFinish(
            "Projection.Setup",
            ProjectionStart
        )
    end

    function Controller.GetCharacterBounds(
        Data,
        Camera,
        Root,
        StyleSettings
    )
        if not RootIsInFront(Camera, Root) then
            return nil
        end

        local State = Data.Bounds

        State.MinX = math.huge
        State.MinY = math.huge
        State.MaxX = -math.huge
        State.MaxY = -math.huge
        State.HasPoint = false

        if Projection.Valid then
            for Part in pairs(Data.BodyParts) do
                if Part.Parent then
                    ProjectPartFast(
                        Part,
                        State
                    )
                else
                    Controller.RemoveBodyPart(
                        Data,
                        Part
                    )
                end
            end
        else
            for Part in pairs(Data.BodyParts) do
                if Part.Parent then
                    ProjectPartLegacy(
                        Part,
                        Camera,
                        State
                    )
                else
                    Controller.RemoveBodyPart(
                        Data,
                        Part
                    )
                end
            end
        end

        if not State.HasPoint then
            return nil
        end

        local ViewportX
        local ViewportY

        if Projection.Valid then
            ViewportX = Projection.ViewportX
            ViewportY = Projection.ViewportY
        else
            local Viewport = Camera.ViewportSize
            ViewportX = Viewport.X
            ViewportY = Viewport.Y
        end

        if
            State.MaxX < 0
            or State.MinX > ViewportX
            or State.MaxY < 0
            or State.MinY > ViewportY
        then
            return nil
        end

        local Padding =
            tonumber(
                StyleSettings.BoxPadding
            )
            or 2

        local X = State.MinX - Padding
        local Y = State.MinY - Padding

        local Width =
            (
                State.MaxX
                - State.MinX
            )
            + Padding * 2

        local Height =
            (
                State.MaxY
                - State.MinY
            )
            + Padding * 2

        if Width <= 2 or Height <= 2 then
            return nil
        end

        State.X = X
        State.Y = Y
        State.Width = Width
        State.Height = Height
        State.CenterX = X + Width / 2
        State.CenterY = Y + Height / 2

        return State
    end

    return Controller
end

return Bounds
