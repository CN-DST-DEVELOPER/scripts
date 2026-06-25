--OMAR: This component is for extending inventoryitem
--     component, and should not be used on its own.

--note: Component doesn't update if temperature is enabled while its awake, since update task is only started in onentitywake

local UPDATE_TIME = 1.0
local SLOW_UPDATE_TIME = 3 --switch to this period when we've reached target temperature
local TARGET_DELTA_THRESHOLD = 0.25 -- we need to be above this value, or below the negative of this value to consider updating, otherwise we're considered at target temperature

local function ontemperature(self, temp)
    self._replica:SetTemperature(temp)
end

-- local function onmintemp(self, mintemp)
--     self._replica:SetMinTemperature(mintemp)
-- end

-- local function onmaxtemp(self, maxtemp)
--     self._replica:SetMaxTemperature(maxtemp)
-- end

local function DoUpdate(inst)
	local self = inst.components.inventoryitemtemperature
	local dt = self.temperatureupdatetask.period
    if self.initialtemperatureupdatedelay then
        dt = self.initialtemperatureupdatedelay
        self.initialtemperatureupdatedelay = nil
    end
	local nextdt = self:UpdateTemperature(dt) and UPDATE_TIME or SLOW_UPDATE_TIME
    -- The entity could become invalid from UpdateTemperature, if something external deleted it from the temperaturedelta event
	if dt ~= nextdt and inst:IsValid() then
		self.temperatureupdatetask:Cancel()
		self.temperatureupdatetask = inst:DoPeriodicTask(nextdt, DoUpdate)
	end
end

local InventoryItemTemperature = Class(function(self, inst)
    self.inst = inst

    self._replica = nil
    --Don't initialize .temperature, .mintemp, .maxtemp, .maxmoisturepenalty, self.save_min_and_max_temp until we have a link to inventoryitem replica

    inst:AddTag("inventoryitemtemperature")
end,
nil,
{
    temperature = ontemperature,
	-- mintemp = onmintemp,
	-- maxtemp = onmaxtemp,
})

--Used internally by inventoryitem component
function InventoryItemTemperature:AttachReplica(replica)
    self._replica = replica
    self.temperature = TUNING.STARTING_TEMP
    self.maxtemp = TUNING.MAX_ENTITY_TEMP
    self.mintemp = TUNING.MIN_ENTITY_TEMP
    self.maxmoisturepenalty = TUNING.MOISTURE_TEMP_PENALTY
    --self.save_min_and_max_temp = nil
    --Cached update values
    self.totalmodifiers = 0
end

function InventoryItemTemperature:OnRemoveFromEntity()
    self.inst:RemoveTag("inventoryitemtemperature")
    self.temperature = 0

	if self.temperatureupdatetask then
		self.temperatureupdatetask:Cancel()
		self.temperatureupdatetask = nil
	end
end

function InventoryItemTemperature:OnEntitySleep()
    local timeremaining = 0
	if self.temperatureupdatetask then
        timeremaining = GetTaskRemaining(self.temperatureupdatetask)
		self.temperatureupdatetask:Cancel()
		self.temperatureupdatetask = nil
	end

    self.initialtemperatureupdatedelay = nil
	self._entitysleeptime = GetTime() - timeremaining -- So that when we wake again, we take into account the time that was left when we slept.
end

function InventoryItemTemperature:OnEntityWake()
	local updated
	if self._entitysleeptime then
		local time_slept = GetTime() - self._entitysleeptime
		if time_slept > 0 then
			updated = self:UpdateTemperature(time_slept)
		end
		self._entitysleeptime = nil
	end
    -- We might have become invalid from UpdateTemperature
	if self.temperatureupdatetask == nil and self.inst:IsValid() then
        self.initialtemperatureupdatedelay = math.random() * UPDATE_TIME
		self.temperatureupdatetask = self.inst:DoPeriodicTask(updated and UPDATE_TIME or SLOW_UPDATE_TIME, DoUpdate, self.initialtemperatureupdatedelay)
	end
end

function InventoryItemTemperature:DiluteTemperature(item, count)
    if self.inst.components.stackable ~= nil then
        local stacksize = self.inst.components.stackable.stacksize
        self:SetTemperature((stacksize * self.temperature + count * item.components.inventoryitem:GetTemperature()) / (stacksize + count))
    end
end

function InventoryItemTemperature:DoDelta(delta)
    self:SetTemperature(self.temperature + delta)
end

function InventoryItemTemperature:SetTemperature(temperature)
	-- TODO hasrate
	local last = self.temperature
	self.temperature = math.clamp(temperature, self.mintemp, self.maxtemp)
    self.inst:PushEvent("temperaturedelta", { last = last, new = self.temperature, mintemp = self.mintemp, maxtemp = self.maxtemp })
end

function InventoryItemTemperature:SetMinTemperature(mintemp)
	self.mintemp = mintemp
    self.inst:PushEvent("temperaturedelta", { last = self.temperature, new = self.temperature, mintemp = self.mintemp, maxtemp = self.maxtemp })
end

function InventoryItemTemperature:SetMaxTemperature(maxtemp)
	self.maxtemp = maxtemp
    self.inst:PushEvent("temperaturedelta", { last = self.temperature, new = self.temperature, mintemp = self.mintemp, maxtemp = self.maxtemp })
end

function InventoryItemTemperature:SetMaxMoisturePenalty(moisturepenalty)
    self.maxmoisturepenalty = moisturepenalty
end

function InventoryItemTemperature:SetPercentAtMost(percent)
    local temperature = Remap(percent, 0, 1, self.mintemp, self.maxtemp)
    if self.temperature > temperature then
        self:SetTemperature(temperature)
    end
end

function InventoryItemTemperature:GetPercent() -- percent here means the percent between mintemp and maxtemp. make sure you know what this means
    return Remap(self.temperature, self.mintemp, self.maxtemp, 0, 1)
end

function InventoryItemTemperature:SetModifier(name, value)
    if value == nil or value == 0 then
        return self:RemoveModifier(name)
    elseif self.temperature_modifiers == nil then
        self.temperature_modifiers = { [name] = value }
        self.totalmodifiers = value
        return
    end
    local m = self.temperature_modifiers[name]
    if m == value then
        return
    end
    self.temperature_modifiers[name] = value
    self.totalmodifiers = self.totalmodifiers + value - (m or 0)
end

function InventoryItemTemperature:RemoveModifier(name)
    if self.temperature_modifiers == nil then
        return
    end
    local m = self.temperature_modifiers[name]
    if m == nil then
        return
    end
    self.temperature_modifiers[name] = nil
    if next(self.temperature_modifiers) == nil then
        self.temperature_modifiers = nil
        self.totalmodifiers = 0
    else
        self.totalmodifiers = self.totalmodifiers - m
    end
end

function InventoryItemTemperature:GetMoisturePenalty()
    return -Lerp(0, self.maxmoisturepenalty, self.inst.components.inventoryitem:GetMoisturePercent())
end

local ZERO_DISTANCE = 10
local ZERO_DISTSQ = ZERO_DISTANCE * ZERO_DISTANCE
local HEATER_MUST_TAGS = { "HASHEATER" }
local HEATER_NO_TAGS = { "heatrock", "INLIMBO" }

-- TODO
function InventoryItemTemperature:GetTargetTemperature() -- returns target temp and rate
    local owner = self.inst.components.inventoryitem ~= nil and self.inst.components.inventoryitem.owner or nil
    local inside_pocket_container = owner ~= nil and owner:HasTag("pocketdimension_container")
    local ambient_temperature = inside_pocket_container and TheWorld.state.temperature or GetLocalTemperature(self.inst)

	if owner ~= nil and owner:HasTag("fridge") and not owner:HasTag("nocool") then
		return math.min(0, ambient_temperature), owner:HasTag("lowcool") and -.5 * TUNING.WARM_DEGREES_PER_SEC or TUNING.WARM_DEGREES_PER_SEC
	end

	local target_temp = ambient_temperature + self.totalmodifiers + self:GetMoisturePenalty()

    if self.inst.components.floater ~= nil and self.inst.components.floater:IsFloating() then
        target_temp = target_temp + TUNING.OCEAN_AMBIENT_TEMPERATURE_PENALTY
    end

	local heat_factor_penalty = TUNING.WET_HEAT_FACTOR_PENALTY -- Cache.
	if not inside_pocket_container then
		local x, y, z = self.inst.Transform:GetWorldPosition()
		for i, v in ipairs(TheSim:FindEntities(x, y, z, ZERO_DISTANCE, HEATER_MUST_TAGS, HEATER_NO_TAGS)) do
			if v ~= self.inst and not v:IsInLimbo() and v.components.heater then
				local heat = v.components.heater:GetHeat(self.inst)
				--V2C: GetHeat first. Some heaters update thermics in their heatfn.
				if heat and (v.components.heater:IsExothermic() or v.components.heater:IsEndothermic()) then
                    local heatfactor, dsqtoinst
                    if v.components.heater:ShouldFalloff() then
                        -- This produces a gentle falloff from 1 to zero.
                        dsqtoinst = self.inst:GetDistanceSqToInst(v)
                        heatfactor = 1 - dsqtoinst / ZERO_DISTSQ
                    else
                        heatfactor = 1
                    end
                    local radius_cutoff = v.components.heater:GetHeatRadiusCutoff()
                    if radius_cutoff then
                        dsqtoinst = dsqtoinst or self.inst:GetDistanceSqToInst(v)
                        if dsqtoinst > radius_cutoff * radius_cutoff then
                            heatfactor = 0
                        end
                    end

                    if heatfactor > 0 then
                        if self.inst:GetIsWet() then -- NOTES(JBK): Leave this in the loop because the entity could go out of IsWet status in this loop.
                            if heat > 0 then
                                heatfactor = heatfactor * heat_factor_penalty
                            elseif heat_factor_penalty ~= 0 then -- In case of mods setting the tuning to 0.
                                heatfactor = heatfactor / heat_factor_penalty
                            end
                        end

                        if v.components.heater:IsExothermic() then
                            -- heating heatfactor is relative to 0 (freezing)
                            local warmingtemp = heat * heatfactor
                            if warmingtemp > self.temperature then
                                target_temp = target_temp + warmingtemp
                            end
                            -- self.externalheaterpower = self.externalheaterpower + heatfactor
                        else--if v.components.heater:IsEndothermic() then
                            -- cooling heatfactor is relative to overheattemp
							local overheattemp = 90 -- TODO
                            local coolingtemp = (heat - overheattemp) * heatfactor + overheattemp
                            if coolingtemp < self.temperature then
                                target_temp = target_temp + coolingtemp
                            end
                        end
                    end
                end
			end
		end
	end

	return target_temp
end

function InventoryItemTemperature:UpdateTemperature(dt)
    local target_temp, temperature_rate = self:GetTargetTemperature()
	local target_delta = target_temp - self.temperature
    -- TODO custom rates
    -- only update if we have enough of a difference,
    -- otherwise, also update if reaching a whole number (e.g. if current temp is 0.06, and target temp is 0, we want to get to 0 anyways for stuff that listens for 0)
    -- in that case, make sure when using inventoryitemtemperature to always set things like mintemp, maxtemp, or certain behaviours to check for whole number of temperature
    if (target_delta > TARGET_DELTA_THRESHOLD)
        or (target_delta > 0 and (target_temp % 1 == 0)) then
        self:SetTemperature(math.min(target_temp, self.temperature + dt))
    elseif (target_delta < -TARGET_DELTA_THRESHOLD)
        or (target_delta < 0 and (target_temp % 1 == 0)) then
        self:SetTemperature(math.max(target_temp, self.temperature - 0.5 * dt))
	else
		return false --not enough change
    end
	return true --changed enough
end

function InventoryItemTemperature:OnSave()
    local data = { temperature = self.temperature }
    if self.save_min_and_max_temp then
        data.mintemp = self.mintemp
        data.maxtemp = self.maxtemp
    end
	return data
end

function InventoryItemTemperature:OnLoad(data)
    if data ~= nil then
        if data.mintemp ~= nil then
            self:SetMinTemperature(data.mintemp)
        end
        if data.maxtemp ~= nil then
            self:SetMaxTemperature(data.maxtemp)
        end
		self:SetTemperature(data.temperature)
    end
end

function InventoryItemTemperature:GetDebugString()
    return string.format("temperature: %2.2f target: %2.2f", self.temperature, self:GetTargetTemperature())
end

return InventoryItemTemperature