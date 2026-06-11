local function OnGrow(inst, self)
    self.task = nil
    self:DoGrowth()
end

local FALLBACK_GROWTH_TIME = 10

---------------------------------------------------------------------------------------------------------------------------------

local Growable = Class(function(self, inst)
    self.inst = inst

    self.stages = nil
    self.stage = 1
    self.pausereasons = {}

    --self.loopstages = false
    --self.loopstages_start = 1
    --self.growonly = false
    --self.springgrowth = false
    --self.growoffscreen = false
    --self.magicgrowable = false
    --self.usetimemultiplier = false
end)

---------------------------------------------------------------------------------------------------------------------------------

function Growable:StartGrowingTask(time)
    time = math.max(0, time)

    self.targettime = GetTime() + time

    if self.growoffscreen or not self.inst:IsAsleep() then
        if self.task ~= nil then
            self.task:Cancel()
        end

        self.task = self.inst:DoTaskInTime(time, OnGrow, self)
    end
end

function Growable:StartGrowing(time)
    self.usetimemultiplier = false

    if #self.stages == 0 then
        print("Growable component: Trying to grow without setting the stages table...")

        return
    end

    if self.stage > #self.stages then
        return
    end

    self:StopGrowing()

    if time == nil then
        local stagedata = self:GetCurrentStageData()
        local timefn = stagedata ~= nil and stagedata.time or nil

        if timefn ~= nil then
            time = timefn(self.inst, self.stage, stagedata) -- This may return nil.
        else
            time = FALLBACK_GROWTH_TIME
        end

        self.usetimemultiplier = stagedata ~= nil and stagedata.multiplier
    end

    if time == nil then
        return
    end

    if self.springgrowth then
        time = SpringGrowthMod(math.max(0, time))
    end

    self:StartGrowingTask(time)
end

function Growable:StopGrowing()
    self.targettime = nil
    self.pausedremaining = nil

    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end
end

---------------------------------------------------------------------------------------------------------------------------------

function Growable:GetNextStage()
    local stage = self.stage + 1

    if stage <= #self.stages then
        return stage
    end

    return self.loopstages and (self.loopstages_start or 1) or #self.stages
end

function Growable:GetStage()
    return self.stage
end

function Growable:GetCurrentStageData()
    return self.stages[self.stage]
end

function Growable:IsGrowing()
    return self.targettime ~= nil
end

---------------------------------------------------------------------------------------------------------------------------------

function Growable:DoMagicGrowth(doer)
    return self.domagicgrowthfn ~= nil and self.domagicgrowthfn(self.inst, doer)
end

function Growable:DoGrowth(skipgrownfn)
    if self.targettime == nil and self.pausedremaining == nil then
        -- Neither started nor paused, which means we're fully stopped.
        return false
    end

    local stage = self:GetNextStage()
    local stagedata = self.stages[stage]

    if stagedata ~= nil and stagedata.pregrowfn ~= nil then
        stagedata.pregrowfn(self.inst, stage, stagedata)
    end

    if not self.growonly then
        self:SetStage(stage)
    end

    if self.inst:IsValid() then
        if not skipgrownfn and stagedata ~= nil and stagedata.growfn ~= nil then
            stagedata.growfn(self.inst, stage, stagedata)
        end

        if (self.stage < #self.stages) or self.loopstages then
            self:StartGrowing()
        else
            self:StopGrowing()
        end
    end

    return true
end

---------------------------------------------------------------------------------------------------------------------------------

function Growable:Pause(reason)
    if self.pausedremaining == nil then
        local time = GetTime()

        -- Catch up time before pausing.
        if self.sleeptime ~= nil then
            local dt = GetTime() - self.sleeptime
            self.sleeptime = nil

            self:LongUpdate(dt)
        end
    
        local targettime = self.targettime
        self:StopGrowing()
        self.pausedremaining = targettime ~= nil and math.floor(targettime - time) or nil
    end

    if reason then
        self.pausereasons[reason] = true
    end
end

function Growable:Resume(reason)
    if reason then
        self.pausereasons[reason] = nil
    end

    local paused = next(self.pausereasons) ~= nil

    if not paused and self.pausedremaining ~= nil then
        self:StartGrowingTask(self.pausedremaining)
        self.pausedremaining = nil

        return true
    end
end

function Growable:IsPaused()
    return self.pausedremaining ~= nil
end

---------------------------------------------------------------------------------------------------------------------------------

function Growable:ExtendGrowTime(extra_time)
    if self.pausedremaining ~= nil then
        self.pausedremaining = self.pausedremaining + extra_time

    elseif self:IsGrowing() then
        self:StartGrowingTask(self.targettime - GetTime() + extra_time)
    end
end

function Growable:SetStage(stage)
    if stage > #self.stages then
        stage = #self.stages
    end

    self.stage = stage

    local stagedata = self.stages[stage]

    if stagedata ~= nil and stagedata.fn ~= nil then
        stagedata.fn(self.inst, stage, stagedata)
    end
end

---------------------------------------------------------------------------------------------------------------------------------

local function GetStageTimeMultiplier(self)
    return self.stages and self.stages[self.stage] and self.stages[self.stage].multiplier or 1
end

function Growable:OnSave()
    local time = (self.pausedremaining ~= nil and math.floor(self.pausedremaining)) or (self.targettime ~= nil and math.floor(self.targettime - GetTime())) or nil
    local sleeptime = self.sleeptime ~= nil and  math.floor(GetTime() - self.sleeptime) or nil

    if time ~= nil then
        time = math.max(0, time)

        if self.usetimemultiplier then
            time = time / GetStageTimeMultiplier(self)
        end
    end

    local data = {
        stage = self.stage,
        time = time,
        sleeptime = self.sleeptime ~= nil and math.max(0, sleeptime) or nil,
        usetimemultiplier = self.usetimemultiplier,
    }

    return next(data) ~= nil and data or nil
end

function Growable:OnLoad(data)
    if data == nil then
        return
    end

    self:SetStage(data.stage or 1) -- 1 is kind of by default.

    if data.sleeptime ~= nil then
        self.sleeptime = GetTime() - data.sleeptime -- It's safe to have negative values for sleeptime.
    end

    if data.time ~= nil then
        if data.usetimemultiplier then
            self.usetimemultiplier = true

            data.time = data.time * GetStageTimeMultiplier(self)
        end

        self:StartGrowing(data.time)
    end
end

---------------------------------------------------------------------------------------------------------------------------------

function Growable:LongUpdate(dt)
    if not self:IsGrowing() then
        return
    end

    if self.sleeptime ~= nil then
        self.sleeptime = self.sleeptime - dt -- It's safe to have negative values for sleeptime.

        return
    end

    local currentstage = self.stage

    while dt > 0 and self.inst:IsValid() and self:IsGrowing() do
        local timeleft = self.targettime - GetTime()

        if (timeleft - dt) > 0 then
            self:StartGrowingTask(timeleft - dt)

            dt = 0
        else
            dt = dt - timeleft

            local grew = self:DoGrowth(true)

            if grew and self.growonly then
                currentstage = math.min(currentstage + 1, #self.stages) -- Increase this for the sake of running growfn below for growonly things.
            end
        end
    end

    if self.inst:IsValid() and currentstage ~= self.stage then
        local stagedata = self.stages[self.growonly and currentstage or self.stage]

        if stagedata ~= nil and stagedata.growfn ~= nil then
            stagedata.growfn(self.inst)
        end
    end
end

function Growable:OnEntitySleep()
    if self.task == nil or self.growoffscreen then
        return
    end

    self.task:Cancel()
    self.task = nil

    self.sleeptime = GetTime()
end

function Growable:OnEntityWake()
    if self.targettime == nil or self.growoffscreen then
        return
    end

    local time = GetTime()
    local dt = self.sleeptime ~= nil and (time - self.sleeptime) or 0

    if dt > 0 then
        self.sleeptime = nil

        self:LongUpdate(dt)
    else
        self:StartGrowingTask(self.targettime - time)
    end
end

---------------------------------------------------------------------------------------------------------------------------------

function Growable:GetDebugString()
    local sleeptime = self.sleeptime ~= nil and (GetTime() - self.sleeptime) or 0

    return
        (
            self:IsGrowing() and self.stage ~= self:GetNextStage() and
            string.format(
                "Growing! Stage: %d  |  Timeleft: %2.2fs%s",
                self.stage,
                math.max(0, self.targettime - GetTime() - sleeptime),
                sleeptime ~= 0 and string.format("  |  Sleep Time: %2.2fs", sleeptime) or "")
        )
        or
        (
            self:IsPaused() and
            string.format("Paused! Stage: %d,  |  Timeleft: %2.2fs", self.stage, self.pausedremaining))
        or
            "Not Growing"
end

---------------------------------------------------------------------------------------------------------------------------------

Growable.OnRemoveFromEntity = Growable.StopGrowing

---------------------------------------------------------------------------------------------------------------------------------

return Growable
