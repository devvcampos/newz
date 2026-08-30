local BASE_URL =
    "https://raw.githubusercontent.com/devvcampos/newz/main/src/"


local CacheBust =
    tostring(
        DateTime.now().
            UnixTimestampMillis
    )


---------------------------------------------------------
-- MODULE LOADER
---------------------------------------------------------

local function LoadModule(
    Path
)

    local URL =
        BASE_URL
        .. Path
        .. "?cb="
        .. CacheBust


    local Source =
        game:HttpGet(
            URL
        )


    local Chunk,
        Error =
            loadstring(
                Source
            )


    assert(
        Chunk,
        "Falha ao carregar "
        .. Path
        .. ": "
        .. tostring(Error)
    )


    local Success,
        Result =
            pcall(
                Chunk
            )


    assert(
        Success,
        "Erro executando "
        .. Path
        .. ": "
        .. tostring(Result)
    )


    return Result

end


---------------------------------------------------------
-- GLOBAL ENV
---------------------------------------------------------

local Environment =
    (
        getgenv
        and getgenv()
    )
    or _G


---------------------------------------------------------
-- REMOVE INSTÂNCIA ANTERIOR
---------------------------------------------------------

if
    Environment.NEWZ
    and type(
        Environment.NEWZ.Destroy
    )
        == "function"
then

    pcall(
        Environment.NEWZ.Destroy
    )

end


---------------------------------------------------------
-- LOAD
---------------------------------------------------------

local Config =
    LoadModule(
        "Config.lua"
    )


local ESPModule =
    LoadModule(
        "Modules/ESP.lua"
    )


local UIModule =
    LoadModule(
        "Ui.lua"
    )


---------------------------------------------------------
-- INIT
---------------------------------------------------------

local ESP =
    ESPModule:
        Init(
            Config
        )


local UI =
    UIModule:
        Init(
            Config
        )


---------------------------------------------------------
-- PROJECT API
---------------------------------------------------------

local Project =
    {}


Project.Config =
    Config


Project.ESP =
    ESP


Project.UI =
    UI


function Project.Destroy()

    if UI then

        pcall(
            UI.Destroy
        )

    end


    if ESP then

        pcall(
            ESP.Destroy
        )

    end


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