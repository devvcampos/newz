local ESP = {}

local function Traceback(Error)
    if
        debug
        and type(debug.traceback) == "function"
    then
        return debug.traceback(
            tostring(Error),
            2
        )
    end

    return tostring(Error)
end

local function CleanupController(Controller)
    if
        Controller
        and type(Controller.Destroy) == "function"
    then
        pcall(
            Controller.Destroy
        )
    end
end

function ESP.Init(Config, Dependencies)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")

    local LocalPlayer = Players.LocalPlayer

    assert(
        LocalPlayer,
        "ESP precisa ser inicializado no cliente"
    )

    assert(
        type(Dependencies) == "table",
        "ESP precisa de dependencias"
    )

    local Profiler = Dependencies.Profiler
    local BoundsModule = Dependencies.BoundsModule
    local VisualsModule = Dependencies.VisualsModule
    local SchedulerModule = Dependencies.SchedulerModule
    local PlayerESPModule = Dependencies.PlayerESPModule
    local CorpseESPModule = Dependencies.CorpseESPModule

    assert(
        BoundsModule
        and type(BoundsModule.New) == "function",
        "BoundsModule invalido"
    )

    assert(
        VisualsModule
        and type(VisualsModule.New) == "function",
        "VisualsModule invalido"
    )

    assert(
        SchedulerModule
        and type(SchedulerModule.New) == "function",
        "SchedulerModule invalido"
    )

    assert(
        PlayerESPModule
        and type(PlayerESPModule.Init) == "function",
        "PlayerESPModule invalido"
    )

    assert(
        CorpseESPModule
        and type(CorpseESPModule.Init) == "function",
        "CorpseESPModule invalido"
    )


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

    local ProfileGauge =
        Profiler
        and Profiler.SetGauge
        or function()
        end

    local ProfileFrame =
        Profiler
        and Profiler.Frame
        or function()
        end

    ---------------------------------------------------------
    -- SHARED GUI / CORE (SEGURANÇA: OCULTO NO COREGUI)
    ---------------------------------------------------------

    -- Obtém o CoreGui escondido (se o executor tiver gethui) ou usa o CoreGui padrão
    local CoreGui = (gethui and gethui()) or game:GetService("CoreGui")
    
    -- Gera um nome aleatório/ofuscado para a GUI
    local GuiName = string.char(120, 121, 122, 65, 66) -- "xyzAB"

    local OldGui = CoreGui:FindFirstChild(GuiName)

    if OldGui then
        OldGui:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = GuiName
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.DisplayOrder = 999
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = CoreGui

    local Bounds =
        BoundsModule.New({
            Profiler = Profiler,
        })

    local Visuals =
        VisualsModule.New(
            ScreenGui
        )

    ---------------------------------------------------------
    -- FEATURE MODULES
    ---------------------------------------------------------

    local PlayerController
    local CorpseController
    local RenderConnection

    local InitSuccess, InitError =
        xpcall(function()
            PlayerController =
                PlayerESPModule.Init(
                    Config,
                    {
                        Bounds = Bounds,
                        Visuals = Visuals,
                        SchedulerModule = SchedulerModule,
                        Profiler = Profiler,
                    }
                )

            assert(
                type(PlayerController) == "table",
                "PlayerESP.Init nao retornou controller"
            )

            CorpseController =
                CorpseESPModule.Init(
                    Config,
                    {
                        Bounds = Bounds,
                        Visuals = Visuals,
                        SchedulerModule = SchedulerModule,
                        Profiler = Profiler,
                    }
                )

            assert(
                type(CorpseController) == "table",
                "CorpseESP.Init nao retornou controller"
            )

            local PlayerStep =
                PlayerController.Step

            local PlayerGetCount =
                PlayerController.GetCount

            local CorpseStep =
                CorpseController.Step

            local CorpseGetCount =
                CorpseController.GetCount

            local UpdateProjection =
                Bounds.UpdateProjection

            RenderConnection =
                RunService.RenderStepped:Connect(function(DeltaTime)
                    ProfileFrame(DeltaTime)

                    ProfileGauge(
                        "PlayersTracked",
                        PlayerGetCount()
                    )

                    ProfileGauge(
                        "CorpsesTracked",
                        CorpseGetCount()
                    )

                    local RenderStart =
                        ProfileBegin(
                            "Newz.Render"
                        )

                    local PlayersEnabled =
                        Config.ESP.Enabled == true

                    local CorpsesEnabled =
                        Config.Corpses.Enabled == true

                    if
                        not PlayersEnabled
                        and not CorpsesEnabled
                    then
                        PlayerStep(
                            DeltaTime,
                            nil
                        )

                        CorpseStep(
                            DeltaTime,
                            nil
                        )

                        ProfileFinish(
                            "Newz.Render",
                            RenderStart
                        )

                        return
                    end

                    local Camera =
                        Workspace.CurrentCamera

                    if not Camera then
                        PlayerStep(
                            DeltaTime,
                            nil
                        )

                        CorpseStep(
                            DeltaTime,
                            nil
                        )

                        ProfileFinish(
                            "Newz.Render",
                            RenderStart
                        )

                        return
                    end

                    UpdateProjection(
                        Camera
                    )

                    PlayerStep(
                        DeltaTime,
                        Camera
                    )

                    CorpseStep(
                        DeltaTime,
                        Camera
                    )

                    ProfileFinish(
                        "Newz.Render",
                        RenderStart
                    )
                end)
        end, Traceback)

    if not InitSuccess then
        if RenderConnection then
            pcall(
                RenderConnection.Disconnect,
                RenderConnection
            )
        end

        CleanupController(CorpseController)
        CleanupController(PlayerController)
        CleanupController(Visuals)

        if ScreenGui then
            pcall(
                ScreenGui.Destroy,
                ScreenGui
            )
        end

        error(
            "Falha ao inicializar ESP modular:\n"
            .. tostring(InitError),
            0
        )
    end

    ---------------------------------------------------------
    -- CONTROLLER
    ---------------------------------------------------------

    local Destroyed = false
    local Controller = {}

    function Controller.Toggle(Value)
        PlayerController.Toggle(
            Value
        )
    end

    function Controller.GetEntityCount()
        return PlayerController.GetCount()
    end

    function Controller.GetLocalEntity()
        return PlayerController.GetLocalEntity()
    end

    function Controller.GetCorpseCount()
        return CorpseController.GetCount()
    end

    function Controller.Destroy()
        if Destroyed then
            return
        end

        Destroyed = true

        if RenderConnection then
            pcall(
                RenderConnection.Disconnect,
                RenderConnection
            )

            RenderConnection = nil
        end

        CleanupController(CorpseController)
        CleanupController(PlayerController)
        CleanupController(Visuals)

        CorpseController = nil
        PlayerController = nil
        Visuals = nil
        Bounds = nil

        if ScreenGui then
            pcall(
                ScreenGui.Destroy,
                ScreenGui
            )
        end
    end

    return Controller
end

return ESP
