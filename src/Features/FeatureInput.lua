local FeatureInput = {}

function FeatureInput.Init(
    Config,
    Dependencies
)
    local UserInputService =
        game:GetService(
            "UserInputService"
        )

    assert(
        type(Dependencies)
        == "table",
        "FeatureInput precisa de dependencias"
    )

    local AimAssist =
        Dependencies.AimAssist

    local CharacterFeatures =
        Dependencies.CharacterFeatures

    assert(
        AimAssist
        and type(
            AimAssist.SetHeld
        ) == "function"
        and type(
            AimAssist.ToggleActive
        ) == "function",
        "AimAssist invalido"
    )

    assert(
        CharacterFeatures
        and type(
            CharacterFeatures.ToggleZoom
        ) == "function"
        and type(
            CharacterFeatures.ToggleNoclip
        ) == "function"
        and type(
            CharacterFeatures.ToggleInvisible
        ) == "function",
        "CharacterFeatures invalido"
    )

    local Destroyed =
        false

    local function ResolveKey(
        Value,
        Fallback
    )
        if
            typeof(Value)
            == "EnumItem"
            and Value.EnumType
                == Enum.KeyCode
        then
            return Value
        end

        local Name =
            tostring(
                Value
                or Fallback
                or "Unknown"
            )

        Name =
            string.gsub(
                Name,
                "^Enum%.KeyCode%.",
                ""
            )

        return
            Enum.KeyCode[
                Name
            ]
            or Enum.KeyCode[
                Fallback
                or "Unknown"
            ]
    end

    local function IsTyping()
        return
            UserInputService:
                GetFocusedTextBox()
            ~= nil
    end

    local function HandleBegan(
        Input,
        GameProcessed
    )
        if
            Destroyed
            or GameProcessed
            or IsTyping()
            or Input.UserInputType
                ~= Enum.UserInputType.Keyboard
        then
            return
        end

        local Key =
            Input.KeyCode

        local AimSettings =
            Config.AimAssist
            or {}

        local ZoomSettings =
            Config.Zoom
            or {}

        local NoclipSettings =
            Config.Noclip
            or {}

        local InvisibleSettings =
            Config.Invisible
            or {}

        if
            Key
            == ResolveKey(
                AimSettings.Keybind,
                "E"
            )
        then
            if
                AimSettings.Hold
                ~= false
            then
                AimAssist.SetHeld(
                    true
                )
            else
                AimAssist.ToggleActive()
            end

            return
        end

        if
            Key
            == ResolveKey(
                ZoomSettings.Keybind,
                "Z"
            )
        then
            CharacterFeatures:
                ToggleZoom()

            return
        end

        if
            Key
            == ResolveKey(
                InvisibleSettings.Keybind,
                "I"
            )
        then
            CharacterFeatures:
                ToggleInvisible()

            return
        end

        if
            Key
            == ResolveKey(
                NoclipSettings.Keybind,
                "B"
            )
        then
            CharacterFeatures:
                ToggleNoclip()
        end
    end

    local function HandleEnded(
        Input
    )
        if
            Destroyed
            or Input.UserInputType
                ~= Enum.UserInputType.Keyboard
        then
            return
        end

        local AimSettings =
            Config.AimAssist
            or {}

        if
            AimSettings.Hold
            ~= false
            and Input.KeyCode
                == ResolveKey(
                    AimSettings.Keybind,
                    "E"
                )
        then
            AimAssist.SetHeld(
                false
            )
        end
    end

    local BeganConnection =
        UserInputService.InputBegan:
            Connect(
                HandleBegan
            )

    local EndedConnection =
        UserInputService.InputEnded:
            Connect(
                HandleEnded
            )

    local Controller = {}

    function Controller.Destroy()
        if Destroyed then
            return
        end

        Destroyed =
            true

        AimAssist.SetHeld(
            false
        )

        if BeganConnection then
            BeganConnection:
                Disconnect()
        end

        if EndedConnection then
            EndedConnection:
                Disconnect()
        end
    end

    return Controller
end

return FeatureInput
