local function onison(self, ison)
	self.inst:AddOrRemoveTag("turnedon", ison)
end

local function onenabled(self, enabled)
	self.inst:AddOrRemoveTag("enabled", enabled)
end

local function ononcooldown(self, oncooldown)
	self.inst:AddOrRemoveTag("cooldown", oncooldown)
end

local function ongroundonly(self, groundonly)
	self.inst:AddOrRemoveTag("groundonlymachine", groundonly)
end

local Machine = Class(function(self, inst)
	self.inst = inst
	self.turnonfn = nil
	self.turnofffn = nil
    self.ison = false
	self.cooldowntime = 3
    self.oncooldown = false
    self.enabled = true
	--self.groundonly = false
end,
nil,
{
    ison = onison,
    oncooldown = ononcooldown,
	groundonly = ongroundonly,
	enabled = onenabled,
})

function Machine:OnRemoveFromEntity()
    self.inst:RemoveTag("turnedon")
    self.inst:RemoveTag("cooldown")
	self.inst:RemoveTag("groundonlymachine")
end

function Machine:SetGroundOnlyMachine(groundonly)
	self.groundonly = groundonly
end

function Machine:OnSave()
	local data = {}
	data.ison = self.ison
	return data
end

function Machine:OnLoad(data)
	if data then
		self.ison = data.ison
		if self:IsOn() then self:TurnOn() else self:TurnOff() end
	end
end

function Machine:TurnOn()
	if self.cooldowntime > 0 then
		self.oncooldown = true
		self.inst:DoTaskInTime(self.cooldowntime, function() self.oncooldown = false end)
	end

	if self.turnonfn then
		self.turnonfn(self.inst)
	end
	self.ison = true
	self.inst:PushEvent("machineturnedon")
end

function Machine:CanInteract()
	return
		not self.inst:HasTag("fueldepleted") and
		not (self.inst.replica.equippable ~= nil and
			not self.inst.replica.equippable:IsEquipped() and
			self.inst.replica.inventoryitem ~= nil and
			self.inst.replica.inventoryitem:IsHeld()) and
			self.enabled == true
end

function Machine:TurnOff()
	if self.cooldowntime > 0 then
		self.oncooldown = true
		self.inst:DoTaskInTime(self.cooldowntime, function() self.oncooldown = false end)
	end

	if self.turnofffn then
		self.turnofffn(self.inst)
	end
	self.ison = false
	self.inst:PushEvent("machineturnedoff")
end

function Machine:IsOn()
	return self.ison
end

function Machine:GetDebugString()
    return string.format(
		"on=%s, cooldowntime=%2.2f, oncooldown=%s",
		tostring(self.ison), self.cooldowntime, tostring(self.oncooldown)
	)
end

return Machine