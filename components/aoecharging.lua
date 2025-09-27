local function OnEnabledDirty(inst)
	local self = inst.components.aoecharging
	if not self.enabled:value() then
		local owner = self.owner
		if owner then
			self:SetChargingOwner(nil)
			if owner.sg then
				owner.sg:HandleEvent("chargingreticulecancelled")
			end
		end
	end
end

local function OnIsCharging(inst)
	local self = inst.components.aoecharging
	local inventoryitem = inst.replica.inventoryitem
	if inventoryitem and inventoryitem:IsGrandOwner(ThePlayer) then
		local equippable = inst.replica.equippable
		if equippable and equippable:IsEquipped() then
			self:SetChargingOwner(self.ischarging:value() and ThePlayer or nil)
		end
	end
end

local function OnChargeTicksDirty(inst)
	local self = inst.components.aoecharging
	local inventoryitem = inst.replica.inventoryitem
	if inventoryitem and inventoryitem:IsGrandOwner(ThePlayer) then
		local equippable = inst.replica.equippable
		if equippable and equippable:IsEquipped() and self.reticule then
			self:OnRefreshChargeTicks(self.reticule)
		end
	end
end

local SYNC_DELAY = 15

local AOECharging = Class(function(self, inst)
	self.inst = inst
	self.ismastersim = TheWorld.ismastersim
	self.reticuleprefab = nil
	self.pingprefab = nil
	self.reticule = nil
	self.owner = nil
	self.allowriding = true
	--self.refreshchargeticksfn = nil

	self.enabled = net_bool(inst.GUID, "aoecharging.enabled", "enableddirty")
	self.enabled:set(true)
	self.ischarging = net_bool(inst.GUID, "aoecharging.ischarging", "ischargingdirty")
	self.chargeticks = net_byte(inst.GUID, "aoecharging.chargeticks", "chargeticksdirty")

	if self.ismastersim then
		--self.onchargedattackfn = nil
		self.syncdelay = 0
	else
		inst:ListenForEvent("enableddirty", OnEnabledDirty)
		inst:ListenForEvent("ischargingdirty", OnIsCharging)
		inst:ListenForEvent("chargeticksdirty", OnChargeTicksDirty)
	end
end)

--------------------------------------------------------------------------
--Common interface

function AOECharging:OnRemoveEntity()
	self:SetChargingOwner(nil)
end

function AOECharging:SetAllowRiding(val)
	self.allowriding = val ~= false
end

function AOECharging:IsEnabled()
	return self.enabled:value()
end

function AOECharging:GetChargeTicks()
	return self.chargeticks:value()
end

function AOECharging:SetRefreshChargeTicksFn(fn)
	self.refreshchargeticksfn = fn
end

function AOECharging:OnRefreshChargeTicks(reticule)
	if self.refreshchargeticksfn then
		self.refreshchargeticksfn(self.inst, reticule, self.chargeticks:value())
	end
end

function AOECharging:SetChargingOwner(owner)
	if self.reticule then
		self.reticule:Remove()
		self.reticule = nil
	end
	if self.owner then
		self.inst:StopUpdatingComponent(self)
		self.owner = nil
		if self.ismastersim then
			self.ischarging:set(false)
			self.chargeticks:set(0)
			self.syncdelay = SYNC_DELAY
		end
	end
	if owner then
		if owner.HUD and self.reticuleprefab then
			self.reticule = SpawnPrefab(self.reticuleprefab)
			self.reticule.components.chargingreticule:LinkToEntity(owner)
		end
		self.owner = owner
		if self.ismastersim then
			self.ischarging:set(true)
			self.chargeticks:set(0)
			self.syncdelay = SYNC_DELAY
		end
		self.inst:StartUpdatingComponent(self)
		if self.reticule then
			self:OnRefreshChargeTicks(self.reticule)
		end
	end
end

function AOECharging:OnUpdate(dt)
	local inventoryitem = self.inst.replica.inventoryitem
	if not (inventoryitem and inventoryitem:IsGrandOwner(self.owner)) then
		self:SetChargingOwner(nil)
		return
	end

	local equippable = self.inst.replica.equippable
	if not (equippable and equippable:IsEquipped()) then
		self:SetChargingOwner(nil)
		return
	end

	if not (self.owner.sg and self.owner.sg:HasStateTag("aoecharging") or self.ischarging:value()) then
		self:SetChargingOwner(nil)
		return
	end

	if self.ismastersim then
		if self.syncdelay > 1 then
			self.syncdelay = self.syncdelay - 1
			self.chargeticks:set_local(self.chargeticks:value() + 1)
		else
			self.syncdelay = SYNC_DELAY
			self.chargeticks:set(self.chargeticks:value() + 1)
		end
	else
		self.chargeticks:set_local(self.chargeticks:value() + 1)
	end
	if self.reticule then
		self:OnRefreshChargeTicks(self.reticule)
	end

	if not (self.owner.components.playercontroller and self.owner.components.playercontroller:IsAnyOfControlsPressed(CONTROL_SECONDARY, CONTROL_CONTROLLER_ALTACTION)) then
		if self.reticule then
			self.reticule.components.chargingreticule:Snap()
		end
		self:UpdateRotation()

		if self.owner.HUD and self.pingprefab then
			local ping = SpawnPrefab("reticulelongping")
			local x, y, z = (self.reticule or self.owner).Transform:GetWorldPosition()
			ping.Transform:SetPosition(x, 0, z)
			ping.Transform:SetRotation((self.reticule or self.owner).Transform:GetRotation())
			ping.AnimState:SetMultColour(204 / 255, 131 / 255, 57 / 255, 1)
			ping.AnimState:SetAddColour(0.2, 0.2, 0.2, 0)
			self:OnRefreshChargeTicks(ping)
		end

		local owner = self.owner
		local chargeticks = self.chargeticks:value()
		self:SetChargingOwner(nil)
		if owner.sg then
			owner.sg:HandleEvent("chargingreticulereleased", { chargeticks = chargeticks })
		end
	else
		self:UpdateRotation()
	end
end

function AOECharging:UpdateRotation()
	if self.reticule then
		local rot = self.reticule.Transform:GetRotation()
		if self.owner.sg then
			self.owner.Transform:SetRotation(rot)
		end
		if not self.ismastersim and self.owner.components.playercontroller then
			self.owner.components.playercontroller:RemoteAOEChargingDir(rot)
		end
	end
end

--------------------------------------------------------------------------
--Server interface

function AOECharging:SetEnabled(enabled)
	if not self.ismastersim then
		return
	end
	self.enabled:set(enabled)
	OnEnabledDirty(self.inst)
end

--Can be used to override the starting ticks to speed it up
function AOECharging:SetChargeTicks(ticks)
	if not self.ismastersim then
		return
	elseif self.owner then
		self.chargeticks:set(ticks)
		if self.reticule then
			self:OnRefreshChargeTicks(self.reticule)
		end
	end
end

function AOECharging:SetOnChargedAttackFn(fn)
	if not self.ismastersim then
		return
	end
	self.onchargedattackfn = fn
end

function AOECharging:ReleaseChargedAttack(doer, chargeticks)
	if not self.ismastersim then
		return
	elseif self.onchargedattackfn then
		self.onchargedattackfn(self.inst, doer, chargeticks)
	end
	--can push event here as well if needed
end

return AOECharging
