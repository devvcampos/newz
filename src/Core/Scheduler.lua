local Scheduler = {}

function Scheduler.New(UpdateFrequency)
    local Frequency =
        math.clamp(
            tonumber(UpdateFrequency) or 30,
            1,
            240
        )

    local Items = {}
    local Cursor = 1
    local Accumulator = 0
    local Destroyed = false

    local Controller = {}

    function Controller.Add(Data)
        if Destroyed or not Data or Data._SchedulerIndex then
            return
        end

        local Index = #Items + 1
        Items[Index] = Data
        Data._SchedulerIndex = Index
    end

    function Controller.Remove(Data)
        if Destroyed or not Data then
            return
        end

        local Index = Data._SchedulerIndex
        if not Index then
            return
        end

        local LastIndex = #Items
        local LastData = Items[LastIndex]

        Items[LastIndex] = nil

        if Index < LastIndex then
            Items[Index] = LastData
            LastData._SchedulerIndex = Index
        end

        Data._SchedulerIndex = nil

        local Count = #Items

        if Count == 0 then
            Cursor = 1
            Accumulator = 0
        elseif Cursor > Count then
            Cursor = 1
        end
    end

    function Controller.Step(DeltaTime, Callback)
        if Destroyed or type(Callback) ~= "function" then
            return 0
        end

        local Count = #Items

        if Count == 0 then
            Cursor = 1
            Accumulator = 0
            return 0
        end

        local DT =
            math.max(
                tonumber(DeltaTime) or 0,
                0
            )

        Accumulator =
            math.min(
                Count,
                Accumulator
                + DT
                * Frequency
                * Count
            )

        local Budget =
            math.floor(Accumulator)

        if Budget < 1 then
            return 0
        end

        Accumulator -= Budget

        for _ = 1, Budget do
            if Cursor > Count then
                Cursor = 1
            end

            local Data = Items[Cursor]
            Cursor += 1

            if Data then
                Callback(Data)
            end
        end

        return Budget
    end

    function Controller.ResetTiming()
        Cursor = 1
        Accumulator = 0
    end

    function Controller.GetCount()
        return #Items
    end

    function Controller.GetItems()
        return Items
    end

    function Controller.Destroy()
        if Destroyed then
            return
        end

        Destroyed = true

        for _, Data in ipairs(Items) do
            if Data then
                Data._SchedulerIndex = nil
            end
        end

        table.clear(Items)

        Cursor = 1
        Accumulator = 0
    end

    return Controller
end

return Scheduler
