local MELTING_CHECK_TIME = 30
local MELTING_CHECK_TIME_VARIANCE = 5
local SnowballMelting = Class(function(self, inst)
    self.inst = inst

    --self.temperaturechecktask = nil
    --self.ondomeltaction = nil
    --self.onstopmelting = nil
    self.state = "solid"
    self.CheckTemperature_Bridge = function(inst)
        self.temperaturechecktask = nil
        self:CheckTemperature()
    end
    self.CheckStartMelting_Bridge = function(inst)
        self.temperaturecheckinittask = nil
        self:CheckStartMelting()
    end
end)

function SnowballMelting:OnRemoveEntity()
    self:StopMelting()
end

function SnowballMelting:ShouldMelt()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local ambient_temperature = GetTemperatureAtXZ(x, z)
    return ambient_temperature > 0
end

function SnowballMelting:CheckTemperature()
    if TheWorld.state.issnowcovered then
        if not self.watchingissnowcovered then
            self.watchingissnowcovered = true
            self.inst:WatchWorldState("issnowcovered", self.CheckTemperature_Bridge)
        end
        if self.state ~= "solid" then
            self.state = "solid"
            if self.onstopmelting then
                self.onstopmelting(self.inst)
            end
        end
    else
        if self.watchingissnowcovered then
            self.watchingissnowcovered = nil
            self.inst:StopWatchingWorldState("issnowcovered", self.CheckTemperature_Bridge)
            self:CheckStartMelting()
        else
            if self:ShouldMelt() then -- Not like CheckStartMelting.
                if self.state ~= "melting" then
                    self.state = "melting"
                    if self.onstartmelting then
                        self.onstartmelting(self.inst)
                    end
                elseif self.state == "melting" then
                    if self.ondomeltaction then
                        self.ondomeltaction(self.inst)
                    end
                end
            else
                if self.state ~= "solid" then
                    self.state = "solid"
                    if self.onstopmelting then
                        self.onstopmelting(self.inst)
                    end
                end
            end
        end
        if self.inst:IsValid() then
            self.temperaturechecktask = self.inst:DoTaskInTime(MELTING_CHECK_TIME + (math.random() * 2 - 1) * MELTING_CHECK_TIME_VARIANCE, self.CheckTemperature_Bridge)
        end
    end
end

function SnowballMelting:SetOnDoMeltAction(fn)
    self.ondomeltaction = fn
end

function SnowballMelting:CheckStartMelting()
    if self.state ~= "melting" and self:ShouldMelt() then
        self.state = "melting"
        if self.onstartmelting then
            self.onstartmelting(self.inst)
        end
    end
end

function SnowballMelting:AllowMelting()
    if self.temperaturechecktask then
        self.temperaturechecktask:Cancel()
        self.temperaturechecktask = nil
    end
    if self.temperaturecheckinittask then
        self.temperaturecheckinittask:Cancel()
        self.temperaturecheckinittask = nil
    end
    self.temperaturechecktask = self.inst:DoTaskInTime(MELTING_CHECK_TIME + math.random() * MELTING_CHECK_TIME_VARIANCE, self.CheckTemperature_Bridge)
    self.temperaturecheckinittask = self.inst:DoTaskInTime(0, self.CheckStartMelting_Bridge)
end

function SnowballMelting:SetOnStartMelting(fn)
    self.onstartmelting = fn
end

function SnowballMelting:StopMelting()
    if self.temperaturechecktask then
        self.temperaturechecktask:Cancel()
        self.temperaturechecktask = nil
    end
    if self.temperaturecheckinittask then
        self.temperaturecheckinittask:Cancel()
        self.temperaturecheckinittask = nil
    end
    if self.watchingissnowcovered then
        self.watchingissnowcovered = nil
        self.inst:StopWatchingWorldState("issnowcovered", self.CheckTemperature_Bridge)
    end
    if self.state ~= "solid" then
        self.state = "solid"
        if self.onstopmelting then
            self.onstopmelting(self.inst)
        end
    end
end

function SnowballMelting:SetOnStopMelting(fn)
    self.onstopmelting = fn
end

function SnowballMelting:GetDebugString()
    return string.format("Melt timer: %.1f, watching snow: %d, state: %s", GetTaskRemaining(self.temperaturechecktask), self.watchingissnowcovered and 1 or 0, self.state)
end

return SnowballMelting