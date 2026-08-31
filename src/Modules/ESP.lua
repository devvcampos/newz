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
    -- SHARED GUI / CORE
    ---------------------------------------------------------

    local PlayerGui =
        LocalPlayer:WaitForChild(
            "PlayerGui"
        )

    local OldGui =
        PlayerGui:FindFirstChild(
            "newz_ESP"
        )

    if OldGui then
        OldGui:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "newz_ESP"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.DisplayOrder = 999
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = PlayerGui

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

            RenderConnection =
                RunService.RenderStepped:Connect(function(DeltaTime)
                    ProfileFrame(DeltaTime)

                    ProfileGauge(
                        "PlayersTracked",
                        PlayerController.GetCount()
                    )

                    ProfileGauge(
                        "CorpsesTracked",
                        CorpseController.GetCount()
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
                        PlayerController.Step(
                            DeltaTime,
                            nil
                        )

                        CorpseController.Step(
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
                        PlayerController.Step(
                            DeltaTime,
                            nil
                        )

                        CorpseController.Step(
                            DeltaTime,
                            nil
                        )

                        ProfileFinish(
                            "Newz.Render",
                            RenderStart
                        )

                        return
                    end

                    Bounds.UpdateProjection(
                        Camera
                    )

                    PlayerController.Step(
                        DeltaTime,
                        Camera
                    )

                    CorpseController.Step(
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
