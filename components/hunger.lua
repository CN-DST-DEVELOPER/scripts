
local SourceModifierList = require("util/sourcemodifierlist")

local UPDATE_PERIOD = 1

----------------------------------------------------------------------------------------------------

local function onmax(self, max)
    self.inst.replica.hunger:SetMax(max)
end

local function oncurrent(self, current)
    self.inst.replica.hunger:SetCurrent(current)
end

----------------------------------------------------------------------------------------------------

local function OnTaskTick(inst, self)
    self:DoDec(UPDATE_PERIOD)
end

----------------------------------------------------------------------------------------------------

local Hunger = Class(function(self, inst)
    self.inst = inst
    self.max = 100
    self.current = self.max

    self.hungerrate = 1
    self.hurtrate = 1
    self.overridestarvefn = nil

    self.burning = true

    self.burnrate = 1 -- DEPRECATED, please use burnratemodifiers instead.
    self.burnratemodifiers = SourceModifierList(self.inst)

    self.updatetask = self.inst:DoPeriodicTask(UPDATE_PERIOD, OnTaskTick, nil, self)
end,
nil,
{
    max = onmax,
    current = oncurrent,
})

----------------------------------------------------------------------------------------------------

function Hunger:SetMax(amount)
    self.max = amount
    self.current = amount
end

function Hunger:SetRate(rate)
    self.hungerrate = rate
end

function Hunger:SetKillRate(rate)
    self.hurtrate = rate
end

function Hunger:SetOverrideStarveFn(fn)
    self.overridestarvefn = fn
end

function Hunger:IsPaused()
    return not self.burning
end

function Hunger:IsStarving()
    return self.current <= 0
end

----------------------------------------------------------------------------------------------------

function Hunger:Pause()
    self.burning = false

    if self.updatetask ~= nil then
        self.updatetask:Cancel()
        self.updatetask = nil
    end
end

function Hunger:Resume()
    self.burning = true

    if self.updatetask == nil then
        self.updatetask = self.inst:DoPeriodicTask(UPDATE_PERIOD, OnTaskTick, nil, self)
    end
end

----------------------------------------------------------------------------------------------------

function Hunger:GetPercent()
    return self.current / self.max
end

function Hunger:SetPercent(p, overtime)
    self:SetCurrent(p * self.max, overtime)
end

----------------------------------------------------------------------------------------------------

function Hunger:SetCurrent(current, overtime)
    local old = self.current

    self.current = math.clamp(current, 0, self.max)

    self.inst:PushEvent("hungerdelta", {
        oldpercent = old / self.max,
        newpercent = self.current / self.max,
        overtime = overtime,
        delta = self.current-old
    })

    if old > 0 then
        if self.current <= 0 then
            self.inst:PushEvent("startstarving")
            ProfileStatsSet("started_starving", true)
        end

    elseif self.current > 0 then
        self.inst:PushEvent("stopstarving")
        ProfileStatsSet("stopped_starving", true)
    end
end

function Hunger:DoDelta(delta, overtime, ignore_invincible)
    if self.redirect ~= nil then
        self.redirect(self.inst, delta, overtime)

        return
    end

    if not ignore_invincible and
        self.inst.components.health and
        self.inst.components.health:IsInvincible() or
        self.inst.is_teleporting
    then
        return
    end

    self:SetCurrent(self.current + delta, overtime)
end

function Hunger:DoDec(dt, ignore_damage)
    if self:IsPaused() then
        return
    end

    local old = self.current

    if self.current > 0 then
        self:DoDelta(-self.hungerrate * dt * self.burnrate * self.burnratemodifiers:Get(), true)

    elseif not ignore_damage then
        if self.overridestarvefn ~= nil then
            self.overridestarvefn(self.inst, dt)
        else
            self.inst.components.health:DoDelta(-self.hurtrate * dt, true, "hunger")
        end
    end
end

----------------------------------------------------------------------------------------------------

function Hunger:LongUpdate(dt)
    self:DoDec(dt, true)
end

function Hunger:TransferComponent(newinst)
    newinst.components.hunger:SetPercent(self:GetPercent())
end

----------------------------------------------------------------------------------------------------

function Hunger:OnSave()
    return self.current ~= self.max and { hunger = self.current } or nil
end

function Hunger:OnLoad(data)
    if data.hunger ~= nil and self.current ~= data.hunger then
        self.current = data.hunger
        self:DoDelta(0)
    end
end

----------------------------------------------------------------------------------------------------

function Hunger:OnRemoveFromEntity()
    if self.updatetask ~= nil then
        self.updatetask:Cancel()
        self.updatetask = nil
    end
end

function Hunger:GetDebugString()
    local burntrate = self.burnrate * self.burnratemodifiers:Get()

    return string.format(
        "%2.1f/%2.1f | Rate: %2.2f (%2.1f*%2.1f) | Paused: %s",
        self.current, self.max,
        self.hungerrate * burntrate, self.hungerrate, burntrate,
        tostring(self:IsPaused())
    )
end

----------------------------------------------------------------------------------------------------

return Hunger
