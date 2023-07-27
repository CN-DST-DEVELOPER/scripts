local function DoAcidRainDamageOnEquipped(item, damage)
    if item.components.waterproofer then
        if item:HasTag("acidrainimmune") then
            return
        end

        if item.components.armor then
            item.components.armor:TakeDamage(damage)
        end

        if item.components.fueled and item.components.fueled.fueltype == FUELTYPE.USAGE and item.components.fueled.consuming then
            item.components.fueled:DoDelta(-damage * TUNING.ACIDRAIN_DAMAGE_FUELED_SCALER)
        end
    end
end

local function DoAcidRainRotOnAllItems(item, percent)
    if item.components.perishable then
        if item:HasTag("acidrainimmune") then
            return
        end

        item.components.perishable:ReducePercent(percent)
    end
end

local AcidLevel = Class(function(self, inst)
    self.inst = inst

    self.max = 100
    self.current = 0

    --self.overrideacidraintick = nil

    self.DoAcidRainDamageOnEquipped = DoAcidRainDamageOnEquipped -- Mods.
    self.DoAcidRainRotOnAllItems = DoAcidRainRotOnAllItems -- Mods.

    self:WatchWorldState("isacidraining", self.OnIsAcidRaining)
    self:OnIsAcidRaining(TheWorld.state.isacidraining)
    self:WatchWorldState("israining", self.OnIsRaining)
    self:OnIsRaining(TheWorld.state.israining)
end)

local function DoAcidRainTick(inst, self)
	if inst.components.rainimmunity ~= nil then
		return
	end

    local damage = TUNING.ACIDRAIN_DAMAGE_TIME * TUNING.ACIDRAIN_DAMAGE_PER_SECOND -- Do not apply rate here.
    local rate = (inst.components.moisture and inst.components.moisture:_GetMoistureRateAssumingRain() or TheWorld.state.precipitationrate)

    if inst.components.inventory then
        if inst.components.inventory:EquipHasTag("acidrainimmune") then
            damage = 0
        else
            -- Melt worn waterproofer equipment.
            inst.components.inventory:ForEachEquipment(self.DoAcidRainDamageOnEquipped, damage)
            -- Spoil perishables, using rate.
            inst.components.inventory:ForEachItem(self.DoAcidRainRotOnAllItems, rate * TUNING.ACIDRAIN_PERISHABLE_ROT_PERCENT)
        end
    end

    -- Apply rate counter.
    self:DoDelta(rate * TUNING.ACIDRAIN_DAMAGE_TIME)

    -- Adjust damage dealt to health with rate now.
    damage = damage * rate

    local fn = self:GetOverrideAcidRainTickFn()
    if fn then
        damage = fn(inst, damage) or damage
    end

    if damage ~= 0 then
        if inst.components.health then
            inst.components.health:DoDelta(-damage, false, "acidrain")
        end
    end
end

local function DoRainTick(inst, self)
	if inst.components.rainimmunity ~= nil then
		return
	end
    local rate = (inst.components.moisture and inst.components.moisture:_GetMoistureRateAssumingRain() or TheWorld.state.precipitationrate) * TUNING.ACIDRAIN_DAMAGE_TIME
    self:DoDelta(-rate)
end

function AcidLevel:SetOverrideAcidRainTickFn(fn)
    -- Return 0 in overrideacidraintick to skip default behaviour on the inst.
    self.overrideacidraintick = fn
end
function AcidLevel:GetOverrideAcidRainTickFn()
    return self.overrideacidraintick
end

function AcidLevel:OnIsAcidRaining(isacidraining)
    if isacidraining then
        if self.inst.acidlevel_acid_task == nil then
            self.inst.acidlevel_acid_task = self.inst:DoPeriodicTask(TUNING.ACIDRAIN_DAMAGE_TIME, DoAcidRainTick, math.random() * TUNING.ACIDRAIN_DAMAGE_TIME, self)
        end
        if self.onstartisacidrainingfn then
            self.onstartisacidrainingfn(self.inst)
        end
    elseif self.inst.acidlevel_acid_task ~= nil then
        self.inst.acidlevel_acid_task:Cancel()
        self.inst.acidlevel_acid_task = nil
        if self.onstopisacidrainingfn then
            self.onstopisacidrainingfn(self.inst)
        end
    end
end

function AcidLevel:OnIsRaining(israining)
    if israining then
        if self.inst.acidlevel_rain_task == nil then
            self.inst.acidlevel_rain_task = self.inst:DoPeriodicTask(TUNING.ACIDRAIN_DAMAGE_TIME, DoRainTick, math.random() * TUNING.ACIDRAIN_DAMAGE_TIME, self)
        end
        if self.onstartisrainingfn then
            self.onstartisrainingfn(self.inst)
        end
    elseif self.inst.acidlevel_rain_task ~= nil then
        self.inst.acidlevel_rain_task:Cancel()
        self.inst.acidlevel_rain_task = nil
        if self.onstopisrainingfn then
            self.onstopisrainingfn(self.inst)
        end
    end
end


function AcidLevel:SetOnStartIsAcidRainingFn(fn)
    self.onstartisacidrainingfn = fn
end

function AcidLevel:SetOnStopIsAcidRainingFn(fn)
    self.onstopisacidrainingfn = fn
end

function AcidLevel:SetOnStartIsRainingFn(fn)
    self.onstartisrainingfn = fn
end

function AcidLevel:SetOnStopIsRainingFn(fn)
    self.onstopisrainingfn = fn
end


function AcidLevel:DoDelta(delta)
    local old = self.current
    self.current = math.clamp(self.current + delta, 0, self.max)

    self.inst:PushEvent("acidleveldelta", { oldpercent = old / self.max, newpercent = self.current / self.max, })
end

function AcidLevel:GetPercent()
    return self.current / self.max
end

function AcidLevel:SetPercent(percent)
    self:DoDelta(self.max * percent - self.current)
end

function AcidLevel:OnSave()
    return
    {
        current = self.current,
    }
end

function AcidLevel:OnLoad(data)
    if data ~= nil and data.current ~= nil and data.current ~= self.current then
        self:DoDelta(data.current - self.current)
    end
end

function AcidLevel:GetDebugString()
    return string.format("%2.2f / %2.2f", self.current, self.max)
end

return AcidLevel
