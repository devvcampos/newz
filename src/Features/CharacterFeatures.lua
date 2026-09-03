local CharacterFeatures = {}

function CharacterFeatures.Init(Config)
    local Players =
        game:GetService("Players")

    local RunService =
        game:GetService("RunService")

    local Workspace =
        game:GetService("Workspace")

    local LocalPlayer =
        Players.LocalPlayer

    assert(
        LocalPlayer,
        "CharacterFeatures precisa ser inicializado no cliente"
    )

    Config.Zoom =
        Config.Zoom
        or {}

    Config.Noclip =
        Config.Noclip
        or {}

    Config.Invisible =
        Config.Invisible
        or {}

    local ZoomSettings =
        Config.Zoom

    local NoclipSettings =
        Config.Noclip

    local InvisibleSettings =
        Config.Invisible

    local Destroyed = false
    local StateChangedCallback = nil

    local SavedFOV = nil

    local NoclipOriginal =
        setmetatable(
            {},
            {
                __mode = "k",
            }
        )

    local InvisibleOriginal =
        setmetatable(
            {},
            {
                __mode = "k",
            }
        )

    local Connections = {}

    local Controller = {}

    local function Notify(
        Feature,
        Enabled
    )
        if
            type(StateChangedCallback)
            == "function"
        then
            pcall(
                StateChangedCallback,
                Feature,
                Enabled
            )
        end
    end

    local function GetCharacter()
        return
            LocalPlayer.Character
    end

    local function CacheNoclipPart(
        Part
    )
        if
            NoclipOriginal[
                Part
            ]
        then
            return
        end

        NoclipOriginal[
            Part
        ] = {
            CanCollide =
                Part.CanCollide,

            CanTouch =
                Part.CanTouch,

            CanQuery =
                Part.CanQuery,
        }
    end

    local function ApplyNoclipPart(
        Part
    )
        if
            not Part:IsA(
                "BasePart"
            )
        then
            return
        end

        CacheNoclipPart(
            Part
        )

        Part.CanCollide =
            false

        Part.CanTouch =
            false

        Part.CanQuery =
            false
    end

    local function ApplyNoclipCharacter(
        Character
    )
        if not Character then
            return
        end

        for _, Object
            in ipairs(
                Character:
                    GetDescendants()
            )
        do
            if Object:IsA(
                "BasePart"
            ) then
                ApplyNoclipPart(
                    Object
                )
            end
        end
    end

    local function RestoreNoclip()
        for Part,
            State
            in pairs(
                NoclipOriginal
            )
        do
            if
                Part
                and Part.Parent
            then
                pcall(function()
                    Part.CanCollide =
                        State.CanCollide

                    Part.CanTouch =
                        State.CanTouch

                    Part.CanQuery =
                        State.CanQuery
                end)
            end

            NoclipOriginal[
                Part
            ] =
                nil
        end
    end

    local function CacheInvisiblePart(
        Part
    )
        if
            InvisibleOriginal[
                Part
            ]
            ~= nil
        then
            return
        end

        InvisibleOriginal[
            Part
        ] =
            Part.LocalTransparencyModifier
    end

    local function ApplyInvisiblePart(
        Part
    )
        if
            not Part:IsA(
                "BasePart"
            )
        then
            return
        end

        CacheInvisiblePart(
            Part
        )

        Part.LocalTransparencyModifier =
            1
    end

    local function ApplyInvisibleCharacter(
        Character
    )
        if not Character then
            return
        end

        for _, Object
            in ipairs(
                Character:
                    GetDescendants()
            )
        do
            if Object:IsA(
                "BasePart"
            ) then
                ApplyInvisiblePart(
                    Object
                )
            end
        end
    end

    local function RestoreInvisible()
        for Part,
            Value
            in pairs(
                InvisibleOriginal
            )
        do
            if
                Part
                and Part.Parent
            then
                pcall(function()
                    Part.LocalTransparencyModifier =
                        Value
                end)
            end

            InvisibleOriginal[
                Part
            ] =
                nil
        end
    end

    function Controller.SetZoom(
        Value
    )
        local Enabled =
            Value == true

        local Camera =
            Workspace.CurrentCamera

        if
            Enabled
            and not ZoomSettings.Enabled
        then
            if Camera then
                SavedFOV =
                    Camera.FieldOfView

                Camera.FieldOfView =
                    math.clamp(
                        tonumber(
                            ZoomSettings.FOV
                        )
                        or 25,
                        1,
                        120
                    )
            end

        elseif
            not Enabled
            and ZoomSettings.Enabled
        then
            if Camera then
                Camera.FieldOfView =
                    SavedFOV
                    or 70
            end

            SavedFOV =
                nil
        end

        ZoomSettings.Enabled =
            Enabled

        Notify(
            "Zoom",
            Enabled
        )

        return Enabled
    end

    function Controller.ToggleZoom()
        return
            Controller.SetZoom(
                not ZoomSettings.Enabled
            )
    end

    function Controller.SetNoclip(
        Value
    )
        local Enabled =
            Value == true

        NoclipSettings.Enabled =
            Enabled

        if Enabled then
            ApplyNoclipCharacter(
                GetCharacter()
            )
        else
            RestoreNoclip()
        end

        Notify(
            "Noclip",
            Enabled
        )

        return Enabled
    end

    function Controller.ToggleNoclip()
        return
            Controller.SetNoclip(
                not NoclipSettings.Enabled
            )
    end

    function Controller.SetInvisible(
        Value
    )
        local Enabled =
            Value == true

        InvisibleSettings.Enabled =
            Enabled

        if Enabled then
            ApplyInvisibleCharacter(
                GetCharacter()
            )
        else
            RestoreInvisible()
        end

        Notify(
            "Invisible",
            Enabled
        )

        return Enabled
    end

    function Controller.ToggleInvisible()
        return
            Controller.SetInvisible(
                not InvisibleSettings.Enabled
            )
    end

    function Controller.SetStateChangedCallback(
        Callback
    )
        if
            Callback ~= nil
            and type(Callback)
                ~= "function"
        then
            return false
        end

        StateChangedCallback =
            Callback

        return true
    end

    Connections.Stepped =
        RunService.Stepped:
            Connect(function()
                if
                    Destroyed
                    or NoclipSettings.Enabled
                        ~= true
                then
                    return
                end

                ApplyNoclipCharacter(
                    GetCharacter()
                )
            end)

    Connections.CharacterAdded =
        LocalPlayer.CharacterAdded:
            Connect(function(
                Character
            )
                task.defer(function()
                    if Destroyed then
                        return
                    end

                    if
                        NoclipSettings.Enabled
                        == true
                    then
                        ApplyNoclipCharacter(
                            Character
                        )
                    end

                    if
                        InvisibleSettings.Enabled
                        == true
                    then
                        ApplyInvisibleCharacter(
                            Character
                        )
                    end
                end)
            end)

    Connections.CharacterDescendantAdded =
        nil

    local function BindCharacter(
        Character
    )
        if
            Connections.CharacterDescendantAdded
        then
            pcall(
                Connections.CharacterDescendantAdded.Disconnect,
                Connections.CharacterDescendantAdded
            )

            Connections.CharacterDescendantAdded =
                nil
        end

        if not Character then
            return
        end

        Connections.CharacterDescendantAdded =
            Character.DescendantAdded:
                Connect(function(
                    Object
                )
                    if
                        Object:IsA(
                            "BasePart"
                        )
                    then
                        if
                            NoclipSettings.Enabled
                            == true
                        then
                            ApplyNoclipPart(
                                Object
                            )
                        end

                        if
                            InvisibleSettings.Enabled
                            == true
                        then
                            ApplyInvisiblePart(
                                Object
                            )
                        end
                    end
                end)
    end

    Connections.CharacterAddedBind =
        LocalPlayer.CharacterAdded:
            Connect(
                BindCharacter
            )

    BindCharacter(
        GetCharacter()
    )

    function Controller.Destroy()
        if Destroyed then
            return
        end

        Destroyed =
            true

        Controller.SetZoom(
            false
        )

        Controller.SetNoclip(
            false
        )

        Controller.SetInvisible(
            false
        )

        for _, Connection
            in pairs(
                Connections
            )
        do
            if Connection then
                pcall(
                    Connection.Disconnect,
                    Connection
                )
            end
        end

        table.clear(
            Connections
        )

        StateChangedCallback =
            nil
    end

    return Controller
end

return CharacterFeatures
