local HttpService = game:GetService("HttpService")

local Environment = (getgenv and getgenv()) or _G

local function Traceback(Error)
    if debug and type(debug.traceback) == "function" then
        return debug.traceback(tostring(Error), 2)
    end

    return tostring(Error)
end

local function CleanupController(Controller)
    if Controller and type(Controller.Destroy) == "function" then
        pcall(Controller.Destroy)
    end
end

local CacheBust = tostring(DateTime.now().UnixTimestampMillis)

local function ResolveSourceRef()
    local ExplicitRef = Environment.NEWZ_SOURCE_REF

    if type(ExplicitRef) == "string" and ExplicitRef ~= "" and ExplicitRef ~= "main" then
        return ExplicitRef
    end

    local ApiURL =
        "https://api.github.com/repos/devvcampos/newz/commits/main?cb="
        .. CacheBust

    local Success, Body = pcall(game.HttpGet, game, ApiURL)

    assert(
        Success,
        "Nao foi possivel resolver o commit atual do Newz. "
        .. "Use dist/newz.lua ou defina NEWZ_SOURCE_REF para um commit/tag imutavel."
    )

    local DecodeSuccess, Data =
        pcall(HttpService.JSONDecode, HttpService, Body)

    assert(
        DecodeSuccess
        and type(Data) == "table"
        and type(Data.sha) == "string"
        and Data.sha ~= "",
        "Resposta invalida ao resolver o commit do Newz"
    )

    return Data.sha
end

local function LoadModuleFromRef(SourceRef, Path)
    local URL =
        "https://raw.githubusercontent.com/devvcampos/newz/"
        .. SourceRef
        .. "/"
        .. Path

    local Source = game:HttpGet(URL)
    local Chunk, LoadError = loadstring(Source, "@newz/" .. Path)

    assert(
        Chunk,
        "Falha ao carregar " .. Path .. ": " .. tostring(LoadError)
    )

    local Success, Result = xpcall(Chunk, Traceback)

    assert(
        Success,
        "Erro executando " .. Path .. ": " .. tostring(Result)
    )

    return Result
end

local Bundled = Environment.NEWZ_BUNDLE

local Config
local ProfilerModule
local ESPModule
local UIModule
local NeverLose
local SourceRef

if type(Bundled) == "table" then
    Config = Bundled.Config
    ProfilerModule = Bundled.ProfilerModule
    ESPModule = Bundled.ESPModule
    UIModule = Bundled.UIModule
    NeverLose = Bundled.NeverLose
    SourceRef = "bundle"
else
    SourceRef = ResolveSourceRef()

    Config = LoadModuleFromRef(SourceRef, "src/Config.lua")
    ProfilerModule = LoadModuleFromRef(SourceRef, "src/Core/Profiler.lua")
    ESPModule = LoadModuleFromRef(SourceRef, "src/Modules/ESP.lua")
    UIModule = LoadModuleFromRef(SourceRef, "src/Ui.lua")
    NeverLose = LoadModuleFromRef(SourceRef, "vendor/NeverLose.lua")
end

assert(type(Config) == "table", "Config.lua nao retornou uma tabela")
assert(
    type(ProfilerModule) == "table"
    and type(ProfilerModule.Init) == "function",
    "Profiler.lua invalido"
)
assert(
    type(ESPModule) == "table" and type(ESPModule.Init) == "function",
    "ESP.lua invalido"
)
assert(
    type(UIModule) == "table" and type(UIModule.Init) == "function",
    "Ui.lua invalido"
)
assert(
    type(NeverLose) == "table" and type(NeverLose.CreateWindow) == "function",
    "NeverLose invalida"
)

if Environment.NEWZ and type(Environment.NEWZ.Destroy) == "function" then
    pcall(Environment.NEWZ.Destroy)
end

local Profiler
local ESP
local UI

local InitSuccess, InitError = xpcall(function()
    Profiler = ProfilerModule.Init(Config)
    assert(
        type(Profiler) == "table",
        "Profiler.Init nao retornou um controller"
    )

    ESP = ESPModule.Init(Config, {
        Profiler = Profiler,
    })
    assert(type(ESP) == "table", "ESP.Init nao retornou um controller")

    UI = UIModule.Init(Config, {
        NeverLose = NeverLose,
    })
    assert(type(UI) == "table", "UI.Init nao retornou um controller")
end, Traceback)

if not InitSuccess then
    CleanupController(UI)
    CleanupController(ESP)
    CleanupController(Profiler)

    error(
        "Falha ao inicializar Newz:\n" .. tostring(InitError),
        0
    )
end

local Project = {
    Config = Config,
    Profiler = Profiler,
    ESP = ESP,
    UI = UI,
    SourceRef = SourceRef,
}

local ProjectDestroyed = false

function Project.Destroy()
    if ProjectDestroyed then
        return
    end

    ProjectDestroyed = true

    CleanupController(UI)
    CleanupController(ESP)
    CleanupController(Profiler)

    UI = nil
    ESP = nil
    Profiler = nil

    Project.UI = nil
    Project.ESP = nil
    Project.Profiler = nil

    if Environment.NEWZ == Project then
        Environment.NEWZ = nil
    end
end

Environment.NEWZ = Project
return Project
