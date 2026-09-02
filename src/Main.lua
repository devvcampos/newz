local Environment =
    (getgenv and getgenv())
    or _G

local function Traceback(Error)
    if
        debug
        and type(debug.traceback)
            == "function"
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
        and type(Controller.Destroy)
            == "function"
    then
        pcall(
            Controller.Destroy
        )
    end
end

local Bundled =
    Environment.NEWZ_BUNDLE

assert(
    type(Bundled) == "table",
    "Newz deve ser executado atraves do bundle dist/newz.lua"
)

local Config =
    Bundled.Config

local ProfilerModule =
    Bundled.ProfilerModule

local BoundsModule =
    Bundled.BoundsModule

local VisualsModule =
    Bundled.VisualsModule

local SchedulerModule =
    Bundled.SchedulerModule

local PlayerESPModule =
    Bundled.PlayerESPModule

local CorpseESPModule =
    Bundled.CorpseESPModule

local FreecamModule =
    Bundled.FreecamModule

local ESPModule =
    Bundled.ESPModule

local UIModule =
    Bundled.UIModule

local NeverLose =
    Bundled.NeverLose

local SourceRef =
    "bundle"

assert(
    type(Config) == "table",
    "Config.lua nao retornou uma tabela"
)

assert(
    type(ProfilerModule) == "table"
    and type(ProfilerModule.Init)
        == "function",
    "Profiler.lua invalido"
)

assert(
    type(BoundsModule) == "table"
    and type(BoundsModule.New)
        == "function",
    "Bounds.lua invalido"
)

assert(
    type(VisualsModule) == "table"
    and type(VisualsModule.New)
        == "function",
    "Visuals.lua invalido"
)

assert(
    type(SchedulerModule) == "table"
    and type(SchedulerModule.New)
        == "function",
    "Scheduler.lua invalido"
)

assert(
    type(PlayerESPModule) == "table"
    and type(PlayerESPModule.Init)
        == "function",
    "PlayerESP.lua invalido"
)

assert(
    type(CorpseESPModule) == "table"
    and type(CorpseESPModule.Init)
        == "function",
    "CorpseESP.lua invalido"
)

assert(
    type(FreecamModule) == "table"
    and type(FreecamModule.Init)
        == "function",
    "Freecam.lua invalido"
)

assert(
    type(ESPModule) == "table"
    and type(ESPModule.Init)
        == "function",
    "ESP.lua invalido"
)

assert(
    type(UIModule) == "table"
    and type(UIModule.Init)
        == "function",
    "Ui.lua invalido"
)

assert(
    type(NeverLose) == "table"
    and type(NeverLose.CreateWindow)
        == "function",
    "NeverLose invalida"
)

if
    Environment.NEWZ
    and type(Environment.NEWZ.Destroy)
        == "function"
then
    pcall(
        Environment.NEWZ.Destroy
    )
end

local Profiler
local ESPController
local FreecamController
local UIController

local InitSuccess,
    InitError =
        xpcall(function()
            Profiler =
                ProfilerModule.Init(
                    Config
                )

            assert(
                type(Profiler)
                    == "table",
                "Profiler.Init nao retornou controller"
            )

            ESPController =
                ESPModule.Init(
                    Config,
                    {
                        Profiler =
                            Profiler,

                        BoundsModule =
                            BoundsModule,

                        VisualsModule =
                            VisualsModule,

                        SchedulerModule =
                            SchedulerModule,

                        PlayerESPModule =
                            PlayerESPModule,

                        CorpseESPModule =
                            CorpseESPModule,
                    }
                )

            assert(
                type(ESPController)
                    == "table",
                "ESP.Init nao retornou controller"
            )

            FreecamController =
                FreecamModule.Init(
                    Config
                )

            assert(
                type(FreecamController)
                    == "table",
                "Freecam.Init nao retornou controller"
            )

            UIController =
                UIModule.Init(
                    Config,
                    {
                        NeverLose =
                            NeverLose,

                        Freecam =
                            FreecamController,
                    }
                )

            assert(
                type(UIController)
                    == "table",
                "UI.Init nao retornou controller"
            )
        end, Traceback)

if not InitSuccess then
    CleanupController(
        UIController
    )

    CleanupController(
        FreecamController
    )

    CleanupController(
        ESPController
    )

    CleanupController(
        Profiler
    )

    error(
        "Falha ao inicializar Newz:\n"
        .. tostring(InitError),
        0
    )
end

local Project = {
    Config = Config,
    Profiler = Profiler,
    ESP = ESPController,
    Freecam = FreecamController,
    UI = UIController,
    SourceRef = SourceRef,
}

local ProjectDestroyed =
    false

function Project.Destroy()
    if ProjectDestroyed then
        return
    end

    ProjectDestroyed =
        true

    CleanupController(
        UIController
    )

    CleanupController(
        FreecamController
    )

    CleanupController(
        ESPController
    )

    CleanupController(
        Profiler
    )

    UIController = nil
    FreecamController = nil
    ESPController = nil
    Profiler = nil

    Project.UI = nil
    Project.Freecam = nil
    Project.ESP = nil
    Project.Profiler = nil

    if
        Environment.NEWZ
        == Project
    then
        Environment.NEWZ =
            nil
    end
end

Environment.NEWZ =
    Project

return Project
