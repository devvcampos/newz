local CorpseIllusion = {}

function CorpseIllusion.Init(Config)
    local Players =
        game:GetService(
            "Players"
        )

    local Workspace =
        game:GetService(
            "Workspace"
        )

    local LocalPlayer =
        Players.LocalPlayer

    assert(
        LocalPlayer,
        "CorpseIllusion precisa ser inicializado no cliente"
    )

    local Settings =
        Config.CorpseIllusion
        or {}

    local CorpseSettings =
        Config.Corpses
        or {}

    local Destroyed = false
    local CurrentClone = nil
    local CurrentSourceName = nil
    local LocalContainer = nil

    local Controller = {}

    local function GetCorpseFolder()
        local FolderName =
            tostring(
                CorpseSettings.FolderName
                or "Corpses"
            )

        return
            Workspace:FindFirstChild(
                FolderName
            )
    end

    local function EnsureContainer()
        if
            LocalContainer
            and LocalContainer.Parent
        then
            return LocalContainer
        end

        local ContainerName =
            tostring(
                Settings.ContainerName
                or "newz_LocalIllusions"
            )

        local Existing =
            Workspace:FindFirstChild(
                ContainerName
            )

        if Existing then
            Existing:Destroy()
        end

        LocalContainer =
            Instance.new(
                "Folder"
            )

        LocalContainer.Name =
            ContainerName

        LocalContainer:SetAttribute(
            "NEWZ_LocalOnly",
            true
        )

        LocalContainer.Parent =
            Workspace

        return LocalContainer
    end

    local function ClearCurrent()
        if CurrentClone then
            pcall(
                CurrentClone.Destroy,
                CurrentClone
            )

            CurrentClone = nil
        end

        CurrentSourceName = nil
    end

    local function FindCorpseByName(TargetName)
        local Folder =
            GetCorpseFolder()

        if not Folder then
            return nil,
                "Workspace."
                .. tostring(
                    CorpseSettings.FolderName
                    or "Corpses"
                )
                .. " nao encontrada"
        end

        local Query =
            string.lower(
                tostring(
                    TargetName
                    or ""
                )
            )

        if Query == "" then
            return nil,
                "Selecione um corpo"
        end

        for _, Object
            in ipairs(
                Folder:GetChildren()
            )
        do
            if
                Object:IsA("Model")
                and string.lower(
                    Object.Name
                ) == Query
            then
                return Object,
                    nil
            end
        end

        return nil,
            "Corpo nao encontrado"
    end

    local function StripLocalInteraction(Clone)
        -- Loot data is intentionally not duplicated into the visual copy.
        local LootContainer =
            Clone:FindFirstChild(
                "Loot_Corpse",
                true
            )

        if LootContainer then
            LootContainer:Destroy()
        end

        for _, Object
            in ipairs(
                Clone:GetDescendants()
            )
        do
            if
                Object:IsA("Script")
                or Object:IsA("LocalScript")
                or Object:IsA("ModuleScript")
                or Object:IsA("ClickDetector")
                or Object:IsA("ProximityPrompt")
                or Object:IsA("Animator")
            then
                Object:Destroy()

            elseif Object:IsA("BasePart") then
                Object.Anchored = true
                Object.CanCollide = false
                Object.CanTouch = false
                Object.CanQuery = false

                Object.AssemblyLinearVelocity =
                    Vector3.zero

                Object.AssemblyAngularVelocity =
                    Vector3.zero

            elseif Object:IsA("Sound") then
                Object:Stop()

            elseif
                Object:IsA("ParticleEmitter")
                or Object:IsA("Trail")
                or Object:IsA("Beam")
                or Object:IsA("Smoke")
                or Object:IsA("Fire")
                or Object:IsA("Sparkles")
            then
                Object.Enabled = false
            end
        end

        local Humanoid =
            Clone:FindFirstChildOfClass(
                "Humanoid"
            )

        if Humanoid then
            Humanoid.AutoRotate = false
            Humanoid.PlatformStand = true
            Humanoid.DisplayDistanceType =
                Enum.HumanoidDisplayDistanceType.None
        end
    end

    local function CloneCorpse(Corpse)
        local PreviousArchivable =
            Corpse.Archivable

        Corpse.Archivable = true

        local Success,
            CloneOrError =
                pcall(
                    Corpse.Clone,
                    Corpse
                )

        Corpse.Archivable =
            PreviousArchivable

        if
            not Success
            or not CloneOrError
        then
            return nil,
                "Nao foi possivel clonar o corpo: "
                .. tostring(
                    CloneOrError
                )
        end

        return CloneOrError,
            nil
    end

    function Controller.GetCorpseNames()
        local Result = {}
        local Folder =
            GetCorpseFolder()

        if not Folder then
            return Result
        end

        for _, Object
            in ipairs(
                Folder:GetChildren()
            )
        do
            if Object:IsA("Model") then
                Result[
                    #Result + 1
                ] =
                    Object.Name
            end
        end

        table.sort(
            Result,
            function(A, B)
                return
                    string.lower(A)
                    < string.lower(B)
            end
        )

        return Result
    end

    function Controller.Show(TargetName)
        if Destroyed then
            return false,
                "CorpseIllusion foi destruido"
        end

        local Character =
            LocalPlayer.Character

        local Root =
            Character
            and Character:FindFirstChild(
                "HumanoidRootPart"
            )

        if
            not Root
            or not Root:IsA("BasePart")
        then
            return false,
                "Seu personagem nao esta pronto"
        end

        local Corpse,
            FindError =
                FindCorpseByName(
                    TargetName
                )

        if not Corpse then
            return false,
                FindError
                or "Corpo nao encontrado"
        end

        local Clone,
            CloneError =
                CloneCorpse(
                    Corpse
                )

        if not Clone then
            return false,
                CloneError
        end

        ClearCurrent()
        StripLocalInteraction(Clone)

        Clone.Name =
            "NEWZ_LOCAL_"
            .. Corpse.Name

        Clone:SetAttribute(
            "NEWZ_LocalIllusion",
            true
        )

        Clone:SetAttribute(
            "NEWZ_SourceCorpse",
            Corpse.Name
        )

        Clone.Parent =
            EnsureContainer()

        local Distance =
            math.clamp(
                tonumber(
                    Settings.Distance
                )
                or 5,
                2,
                20
            )

        local VerticalOffset =
            math.clamp(
                tonumber(
                    Settings.VerticalOffset
                )
                or 0,
                -5,
                5
            )

        local TargetPosition =
            (
                Root.CFrame
                * CFrame.new(
                    0,
                    VerticalOffset,
                    -Distance
                )
            ).Position

        local SourcePivot =
            Corpse:GetPivot()

        local SourceRotation =
            SourcePivot
            - SourcePivot.Position

        Clone:PivotTo(
            CFrame.new(
                TargetPosition
            )
            * SourceRotation
        )

        CurrentClone = Clone
        CurrentSourceName =
            Corpse.Name

        Settings.TargetName =
            Corpse.Name

        return true,
            "Ilusao local: "
            .. Corpse.Name
    end

    function Controller.Clear()
        if Destroyed then
            return false,
                "CorpseIllusion foi destruido"
        end

        local HadClone =
            CurrentClone ~= nil

        ClearCurrent()

        if HadClone then
            return true,
                "Ilusao removida"
        end

        return true,
            "Nenhuma ilusao ativa"
    end

    function Controller.GetCurrentName()
        return CurrentSourceName
    end

    function Controller.Destroy()
        if Destroyed then
            return
        end

        Destroyed = true
        ClearCurrent()

        if LocalContainer then
            pcall(
                LocalContainer.Destroy,
                LocalContainer
            )

            LocalContainer = nil
        end
    end

    return Controller
end

return CorpseIllusion
