local function onbroken(self, broken)
	self.inst:AddOrRemoveTag("broken", broken)
end

local function OnFumaroleToolTemperatureDelta(inst, data)
    if data.new <= TUNING.FUMAROLETOOL_TEMPS[1] then
		inst.components.fumaroletool:SetBroken(true)
    elseif data.new >= TUNING.FUMAROLETOOL_TEMPS[4] then
		inst.components.fumaroletool:SetBroken(false)
    end

	local fumaroletool = inst.components.fumaroletool
	if fumaroletool.onupdatetemperaturerange ~= nil and not fumaroletool.broken then
		local temprange = fumaroletool:UpdateTempRange()
		if temprange ~= fumaroletool.temperaturerange then
			fumaroletool.temperaturerange = temprange
			fumaroletool.onupdatetemperaturerange(inst, inst.components.inventoryitem.owner, temprange)
		end
	end

	if (data.new < TUNING.FUMAROLETOOL_TEMPS[3]) or fumaroletool.broken then
		fumaroletool._light.Light:SetIntensity(0)
		fumaroletool._light.Light:Enable(false)
	else
    	local relativetemp = inst.components.inventoryitem:GetTemperature()
    	local baseline = relativetemp - TUNING.FUMAROLETOOL_TEMPS[3]
    	local brightline = TUNING.FUMAROLETOOL_TEMPS[3] + 20
		fumaroletool._light.Light:Enable(true)
    	fumaroletool._light.Light:SetIntensity( math.clamp(0.5 * baseline/brightline, 0, 0.5 ) )
	end
end

local function OnFumaroleToolOnAttack(inst, data)
    inst.components.fumaroletool:OnUsed(data.attacker, data.target)
end

local FumaroleTool = Class(function(self, inst)
	self.inst = inst

	self.broken = false
	self.heatonuse = nil
	self.onbroken = nil
	self.onrepaired = nil
	self.onupdatetemperaturerange = nil
	self.temperaturerange = 1

	self._light = SpawnPrefab("heatrocklight")
	self:OnUpdateOwner()

	MakeComponentAnInventoryItemSource(self) -- for the light
    inst:ListenForEvent("temperaturedelta", OnFumaroleToolTemperatureDelta)
	inst:ListenForEvent("weapononattack", OnFumaroleToolOnAttack)

	assert(inst.components.inventoryitemtemperature and inst.components.heater, "Need item temperature and heater components for FumaroleTool component")
end,
nil,
{
	broken = onbroken,
})

function FumaroleTool:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("temperaturedelta", OnFumaroleToolTemperatureDelta)
	self.inst:RemoveEventCallback("weapononattack", OnFumaroleToolOnAttack)
    RemoveComponentInventoryItemSource(self)
end

function FumaroleTool:OnUpdateOwner()
	local owner = self.inst.components.inventoryitem:GetGrandOwner() or self.inst

	if owner:HasAnyTag("pocketdimension_container", "buried") then
		self._light.entity:SetParent(self.inst.entity)
		if not self._light:IsInLimbo() then
			self._light:RemoveFromScene()
		end
	else
		self._light.entity:SetParent(owner.entity)
		if self._light:IsInLimbo() then
			self._light:ReturnToScene()
		end
	end

end
-- MakeComponentAnInventoryItemSource functions
FumaroleTool.OnItemSourceRemoved = FumaroleTool.OnUpdateOwner
FumaroleTool.OnItemSourceNewOwner = FumaroleTool.OnUpdateOwner
--

function FumaroleTool:SetBroken(broken, isloading)
	local oldbroken = self.broken or false
	self.broken = broken or false

	if oldbroken ~= self.broken then
		if broken then
			if self.onbroken ~= nil then
				self.onbroken(self.inst, isloading)
			end
		else
			if self.onrepaired ~= nil then
				self.onrepaired(self.inst)
			end
		end
	end
end

function FumaroleTool:SetOnBroken(fn)
	self.onbroken = fn
end

function FumaroleTool:SetOnRepaired(fn)
	self.onrepaired = fn
end

function FumaroleTool:SetHeatOnUse(heat)
	self.heatonuse = heat
end

function FumaroleTool:SetOnUpdateTemperatureRange(heat)
	self.onupdatetemperaturerange = heat
end

function FumaroleTool:OnUsed(doer, target) -- from attack, or from OnUsedAsItem (automatically called from bufferedaction)
	if self.heatonuse ~= nil then
		local mult = doer.components.aoediminishingreturns and doer.components.aoediminishingreturns.mult:Get() or 1
		local heatonuse = mult * self.heatonuse
		self.inst.components.inventoryitem:AddTemperature(heatonuse)

		if doer ~= nil and doer.components.temperature ~= nil then
			doer.components.temperature:DoDelta(-heatonuse, true)
		end
	end
end

function FumaroleTool:UpdateTempRange()
	local temp = self.inst.components.inventoryitem:GetTemperature()

	for i = #TUNING.FUMAROLETOOL_TEMPS, 1, -1 do
		if temp > TUNING.FUMAROLETOOL_TEMPS[i] then
			return i
		end
	end

	return 1
end

function FumaroleTool:GetTempRange()
	return self.temperaturerange
end

function FumaroleTool:OnUsedAsItem(action, doer, target)
	if self.inst:CanDoAction(action) then
		self:OnUsed(doer, target)
	end
end

function FumaroleTool:OnBuilt(builder)
	local moisturepenalty = builder.components.moisture ~= nil and -Lerp(0, TUNING.FUMAROLETOOL_STARTING_MOISTURE_PENALTY, builder.components.moisture:GetMoisturePercent()) or 0
	self.inst.components.inventoryitem:SetTemperature(TUNING.FUMAROLETOOL_STARTING_TEMP + moisturepenalty)
end

function FumaroleTool:OnSave()
	return { broken = self.broken }
end

function FumaroleTool:OnLoad(data)
	if data ~= nil then
		if data.broken then
			self:SetBroken(data.broken, true)
		end
	end
end

return FumaroleTool