local LootESP = {}

function LootESP.New(Config, Dependencies)
    local Settings =
        Config.Corpses
        or {}

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

    local ContainerName =
        tostring(
            Settings.LootContainerName
            or "Loot_Corpse"
        )

    local MarkerName =
        tostring(
            Settings.LootMarkerName
            or "Corpse"
        )

    local function DisconnectConnection(Connection)
        if Connection then
            pcall(
                Connection.Disconnect,
                Connection
            )
        end
    end

    local function IsLootContainer(Object)
        return
            Object
            and Object.Name == ContainerName
            and (
                Object:IsA("Folder")
                or Object:IsA("Model")
            )
    end

    local function IsLootEntry(Object)
        if
            not Object
            or Object.Name == MarkerName
        then
            return false
        end

        return
            Object:IsA("Folder")
            or Object:IsA("Model")
            or Object:IsA("Tool")
            or Object:IsA("Configuration")
    end

    local function GetMaxItems()
        return
            math.clamp(
                math.floor(
                    tonumber(
                        Settings.LootMaxItems
                    )
                    or 4
                ),
                1,
                10
            )
    end

    local function ClearContainerConnections(Data)
        local Loot =
            Data.Loot

        if not Loot then
            return
        end

        for _, Connection
            in pairs(
                Loot.ContainerConnections
            )
        do
            DisconnectConnection(
                Connection
            )
        end

        table.clear(
            Loot.ContainerConnections
        )

        Loot.Container = nil
    end

    local function Refresh(Data)
        local Loot =
            Data.Loot

        if not Loot then
            return
        end

        local RefreshStart =
            ProfileBegin(
                "Corpses.LootRefresh"
            )

        local Container =
            Loot.Container

        local MaxItems =
            GetMaxItems()

        Loot.LastMaxItems =
            MaxItems

        if
            not Container
            or not Container.Parent
        then
            Loot.Text = ""
            Loot.LineCount = 0
            Loot.TotalItems = 0

            ProfileFinish(
                "Corpses.LootRefresh",
                RefreshStart
            )

            return
        end

        local Counts = {}
        local TotalItems = 0

        for _, Object
            in ipairs(
                Container:GetChildren()
            )
        do
            if IsLootEntry(Object) then
                local Name =
                    Object.Name

                Counts[Name] =
                    (
                        Counts[Name]
                        or 0
                    )
                    + 1

                TotalItems += 1
            end
        end

        local Names = {}

        for Name in pairs(Counts) do
            Names[
                #Names + 1
            ] =
                Name
        end

        table.sort(
            Names,
            function(A, B)
                return
                    string.lower(A)
                    < string.lower(B)
            end
        )

        local Lines = {}
        local DisplayedItems = 0

        local VisibleEntries =
            math.min(
                #Names,
                MaxItems
            )

        for Index = 1, VisibleEntries do
            local Name =
                Names[Index]

            local Count =
                Counts[Name]

            DisplayedItems +=
                Count

            if Count > 1 then
                Lines[
                    #Lines + 1
                ] =
                    tostring(Count)
                    .. "x "
                    .. Name
            else
                Lines[
                    #Lines + 1
                ] =
                    Name
            end
        end

        local Remaining =
            TotalItems
            - DisplayedItems

        if Remaining > 0 then
            Lines[
                #Lines + 1
            ] =
                "+"
                .. tostring(Remaining)
                .. (
                    Remaining == 1
                    and " item"
                    or " items"
                )
        end

        Loot.Text =
            table.concat(
                Lines,
                "\n"
            )

        Loot.LineCount =
            #Lines

        Loot.TotalItems =
            TotalItems

        ProfileFinish(
            "Corpses.LootRefresh",
            RefreshStart
        )
    end

    local function BindContainer(
        Data,
        Container
    )
        local Loot =
            Data.Loot

        if
            not Loot
            or not IsLootContainer(
                Container
            )
        then
            return
        end

        if Loot.Container == Container then
            return
        end

        ClearContainerConnections(
            Data
        )

        Loot.Container =
            Container

        Loot.ContainerConnections.ChildAdded =
            Container.ChildAdded:
                Connect(function()
                    Refresh(
                        Data
                    )
                end)

        Loot.ContainerConnections.ChildRemoved =
            Container.ChildRemoved:
                Connect(function()
                    Refresh(
                        Data
                    )
                end)

        Refresh(
            Data
        )
    end

    local function Activate(Data)
        local Loot =
            Data.Loot

        if
            not Loot
            or Loot.Active
        then
            return
        end

        local Corpse =
            Loot.Corpse

        if
            not Corpse
            or not Corpse.Parent
        then
            return
        end

        Loot.Active = true

        Loot.CorpseConnections.ChildAdded =
            Corpse.ChildAdded:
                Connect(function(Object)
                    if
                        IsLootContainer(
                            Object
                        )
                    then
                        BindContainer(
                            Data,
                            Object
                        )
                    end
                end)

        Loot.CorpseConnections.ChildRemoved =
            Corpse.ChildRemoved:
                Connect(function(Object)
                    if
                        Object
                        == Loot.Container
                    then
                        ClearContainerConnections(
                            Data
                        )

                        Loot.Text = ""
                        Loot.LineCount = 0
                        Loot.TotalItems = 0
                    end
                end)

        local Existing =
            Corpse:
                FindFirstChild(
                    ContainerName
                )

        if IsLootContainer(Existing) then
            BindContainer(
                Data,
                Existing
            )
        else
            Refresh(
                Data
            )
        end
    end

    local Controller = {}

    function Controller.Prepare(
        Data,
        Corpse
    )
        Data.Loot = {
            Corpse = Corpse,

            Active = false,

            Container = nil,
            ContainerConnections = {},
            CorpseConnections = {},

            Text = "",
            LineCount = 0,
            TotalItems = 0,

            LastMaxItems = nil,
        }
    end

    function Controller.Suspend(
        Data
    )
        local Loot =
            Data
            and Data.Loot

        if
            not Loot
            or not Loot.Active
        then
            return
        end

        ClearContainerConnections(
            Data
        )

        for _, Connection
            in pairs(
                Loot.CorpseConnections
            )
        do
            DisconnectConnection(
                Connection
            )
        end

        table.clear(
            Loot.CorpseConnections
        )

        Loot.Active = false
        Loot.Text = ""
        Loot.LineCount = 0
        Loot.TotalItems = 0
        Loot.LastMaxItems = nil
    end

    function Controller.Sync(
        Data
    )
        local Loot =
            Data
            and Data.Loot

        if not Loot then
            return "", 0, 0
        end

        if Settings.Loot ~= true then
            if Loot.Active then
                Controller.Suspend(
                    Data
                )
            end

            return "", 0, 0
        end

        if not Loot.Active then
            Activate(
                Data
            )
        end

        local MaxItems =
            GetMaxItems()

        if
            Loot.LastMaxItems
            ~= MaxItems
        then
            Refresh(
                Data
            )
        end

        return
            Loot.Text,
            Loot.LineCount,
            Loot.TotalItems
    end

    function Controller.DestroyData(
        Data
    )
        if not Data then
            return
        end

        Controller.Suspend(
            Data
        )

        Data.Loot = nil
    end

    return Controller
end

return LootESP
