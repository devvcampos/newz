local Visuals = {}

function Visuals.New(ScreenGui)
    assert(
        ScreenGui,
        "Visuals.New precisa receber ScreenGui"
    )

    local Destroyed = false

    local function CreateText(TextColor)
        local Text =
            Instance.new(
                "TextLabel"
            )

        Text.BackgroundTransparency = 1
        Text.Size = UDim2.fromOffset(220, 18)
        Text.AnchorPoint = Vector2.new(0.5, 0.5)
        Text.Font = Enum.Font.Gotham
        Text.TextSize = 13

        Text.TextColor3 =
            TextColor
            or Color3.new(1, 1, 1)

        Text.TextStrokeColor3 =
            Color3.new(0, 0, 0)

        Text.TextStrokeTransparency = 0.25
        Text.ZIndex = 11
        Text.Visible = false
        Text.Parent = ScreenGui

        return Text
    end

    local Controller = {}

    function Controller.Create(
        Name,
        LabelNames,
        BoxColor,
        TextColor
    )
        assert(
            not Destroyed,
            "Visuals ja foi destruido"
        )

        local Box = Instance.new("Frame")
        Box.Name = Name
        Box.BackgroundTransparency = 1
        Box.BorderSizePixel = 0
        Box.Visible = false
        Box.ZIndex = 10
        Box.Parent = ScreenGui

        local Stroke = Instance.new("UIStroke")
        Stroke.Color = BoxColor
        Stroke.Thickness = 1
        Stroke.LineJoinMode = Enum.LineJoinMode.Miter
        Stroke.Enabled = false
        Stroke.Parent = Box

        local Corners = {}

        for Index = 1, 8 do
            local Line = Instance.new("Frame")
            Line.Name = "Corner" .. Index
            Line.BorderSizePixel = 0
            Line.BackgroundColor3 = BoxColor
            Line.Visible = false
            Line.ZIndex = 11
            Line.Parent = Box
            Corners[Index] = Line
        end

        local Labels = {}

        for _, LabelName in ipairs(LabelNames) do
            Labels[LabelName] =
                CreateText(TextColor)
        end

        return {
            Box = Box,
            Stroke = Stroke,
            Corners = Corners,
            Labels = Labels,
        }
    end

    function Controller.Hide(Data)
        if
            not Data
            or not Data.Visuals
            or Data.Hidden
        then
            return
        end

        Data.Hidden = true
        Data.Visuals.Box.Visible = false

        for _, Label
            in pairs(
                Data.Visuals.Labels
            )
        do
            Label.Visible = false
        end

        table.clear(
            Data.RenderState
        )
    end

    function Controller.SetVisible(
        State,
        Key,
        Object,
        Value
    )
        if State[Key] ~= Value then
            Object.Visible = Value
            State[Key] = Value
        end
    end

    function Controller.SetText(
        State,
        Key,
        Object,
        Value
    )
        if State[Key] ~= Value then
            Object.Text = Value
            State[Key] = Value
        end
    end

    function Controller.SetTextColor(
        State,
        Key,
        Object,
        Value
    )
        if State[Key] ~= Value then
            Object.TextColor3 = Value
            State[Key] = Value
        end
    end

    local function UpdateCornerBox(
        Data,
        Width,
        Height,
        Color,
        StyleSettings
    )
        local DataVisuals = Data.Visuals
        local State = Data.RenderState

        local Thickness =
            math.max(
                1,
                tonumber(
                    StyleSettings.BoxThickness
                )
                or 1
            )

        local Ratio =
            math.clamp(
                tonumber(
                    StyleSettings.CornerRatio
                )
                or 0.25,
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

        if
            State.CornerWidth == Width
            and State.CornerHeight == Height
            and State.CornerThickness == Thickness
            and State.CornerLength == Corner
            and State.CornerColor == Color
        then
            return
        end

        State.CornerWidth = Width
        State.CornerHeight = Height
        State.CornerThickness = Thickness
        State.CornerLength = Corner
        State.CornerColor = Color

        local C = DataVisuals.Corners

        for _, Line in ipairs(C) do
            Line.BackgroundColor3 = Color
        end

        C[1].Position = UDim2.fromOffset(0, 0)
        C[1].Size = UDim2.fromOffset(Corner, Thickness)

        C[2].Position = UDim2.fromOffset(0, 0)
        C[2].Size = UDim2.fromOffset(Thickness, Corner)

        C[3].Position = UDim2.fromOffset(Width - Corner, 0)
        C[3].Size = UDim2.fromOffset(Corner, Thickness)

        C[4].Position = UDim2.fromOffset(Width - Thickness, 0)
        C[4].Size = UDim2.fromOffset(Thickness, Corner)

        C[5].Position = UDim2.fromOffset(0, Height - Thickness)
        C[5].Size = UDim2.fromOffset(Corner, Thickness)

        C[6].Position = UDim2.fromOffset(0, Height - Corner)
        C[6].Size = UDim2.fromOffset(Thickness, Corner)

        C[7].Position = UDim2.fromOffset(Width - Corner, Height - Thickness)
        C[7].Size = UDim2.fromOffset(Corner, Thickness)

        C[8].Position = UDim2.fromOffset(Width - Thickness, Height - Corner)
        C[8].Size = UDim2.fromOffset(Thickness, Corner)
    end

    function Controller.UpdateBox(
        Data,
        Bounds,
        StyleSettings,
        Color
    )
        local DataVisuals = Data.Visuals
        local State = Data.RenderState

        local BoxWidth =
            math.floor(Bounds.Width)

        local BoxHeight =
            math.floor(Bounds.Height)

        local BoxX =
            math.floor(Bounds.X)

        local BoxY =
            math.floor(Bounds.Y)

        local BoxEnabled =
            StyleSettings.Box == true

        local CornerStyle =
            (
                StyleSettings.BoxStyle
                or "Corner"
            )
            == "Corner"

        if BoxEnabled then
            if
                State.BoxX ~= BoxX
                or State.BoxY ~= BoxY
            then
                DataVisuals.Box.Position =
                    UDim2.fromOffset(
                        BoxX,
                        BoxY
                    )

                State.BoxX = BoxX
                State.BoxY = BoxY
            end

            if
                State.BoxWidth ~= BoxWidth
                or State.BoxHeight ~= BoxHeight
            then
                DataVisuals.Box.Size =
                    UDim2.fromOffset(
                        BoxWidth,
                        BoxHeight
                    )

                State.BoxWidth = BoxWidth
                State.BoxHeight = BoxHeight
            end
        end

        Controller.SetVisible(
            State,
            "BoxVisible",
            DataVisuals.Box,
            BoxEnabled
        )

        if BoxEnabled and CornerStyle then
            if State.StrokeEnabled ~= false then
                DataVisuals.Stroke.Enabled = false
                State.StrokeEnabled = false
            end

            if State.CornersVisible ~= true then
                for _, Line in ipairs(DataVisuals.Corners) do
                    Line.Visible = true
                end

                State.CornersVisible = true
            end

            UpdateCornerBox(
                Data,
                BoxWidth,
                BoxHeight,
                Color,
                StyleSettings
            )

        elseif BoxEnabled then
            if State.CornersVisible ~= false then
                for _, Line in ipairs(DataVisuals.Corners) do
                    Line.Visible = false
                end

                State.CornersVisible = false
            end

            if State.StrokeEnabled ~= true then
                DataVisuals.Stroke.Enabled = true
                State.StrokeEnabled = true
            end

            local Thickness =
                tonumber(
                    StyleSettings.BoxThickness
                )
                or 1

            if State.StrokeColor ~= Color then
                DataVisuals.Stroke.Color = Color
                State.StrokeColor = Color
            end

            if State.StrokeThickness ~= Thickness then
                DataVisuals.Stroke.Thickness = Thickness
                State.StrokeThickness = Thickness
            end
        end
    end

    function Controller.DestroyEntity(Data)
        if not Data or not Data.Visuals then
            return
        end

        if Data.Visuals.Box then
            pcall(
                Data.Visuals.Box.Destroy,
                Data.Visuals.Box
            )
        end

        for _, Label in pairs(Data.Visuals.Labels) do
            if Label then
                pcall(
                    Label.Destroy,
                    Label
                )
            end
        end

        Data.Visuals = nil
    end

    function Controller.Destroy()
        Destroyed = true
    end

    return Controller
end

return Visuals
