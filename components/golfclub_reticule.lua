--Client handlers

local function OnTargetDirty(inst)
	local inventoryitem = inst.replica.inventoryitem
	if inventoryitem and inventoryitem:IsHeldBy(ThePlayer) and ThePlayer.components.playercontroller then
		inst.components.golfclub_reticule:OnTargetDirty(ThePlayer)
	end
end

local CHARGETICKS_OFF = 63

local function OnChargeTicksDirty(inst)
	local self = inst.components.golfclub_reticule
	if self.chargeticks:value() >= TUNING.GOLF_MAX_CHARGE_TICKS or self.chargeticks:value() == CHARGETICKS_OFF then
		inst:StopUpdatingComponent(self)
	else
		self.chargeticks:set_local(self.chargeticks:value() + 1)
		if self:OnChargeTicksDirty() and self.chargeticks:value() < TUNING.GOLF_MAX_CHARGE_TICKS then
			inst:StartUpdatingComponent(self)
		else
			inst:StopUpdatingComponent(self)
		end
	end
end

--------------------------------------------------------------------------

local GolfClubReticule = Class(function(self, inst)
	self.inst = inst
	self.ismastersim = TheWorld.ismastersim
	self.aim_range_fx = nil

	self.target = net_entity(inst.GUID, "golfclub_reticule.target", "golfclub_reticule.targetdirty")
	self.chargeticks = net_smallbyte(inst.GUID, "golfclub_reticule.chargeticks", "golfclub_reticule.chargeticksdirty")
	self.chargeticks:set(CHARGETICKS_OFF)

	if not self.ismastersim then
		inst:ListenForEvent("golfclub_reticule.targetdirty", OnTargetDirty)
		inst:ListenForEvent("golfclub_reticule.chargeticksdirty", OnChargeTicksDirty)
	end
end)

--------------------------------------------------------------------------
--Common interface

--NOTE: aiming reticule repurposed from boatcannon
local RANGE = 0.1

local function ClampReticulePos(inst, pos, newx, newz)
	if ThePlayer then
		local base_aim_angle = ThePlayer.Transform:GetRotation() * DEGREES
		local base_aim_facing = Vector3(math.cos(-base_aim_angle), 0 , math.sin(-base_aim_angle))
		local withinangle = IsWithinAngle(pos, base_aim_facing, TUNING.GOLF_AIM_ARC, pos - Vector3(newx, 0, newz))
		if not withinangle then
			-- Return the closest min/max allowable angle to the controller's facing angle
			local minangle = base_aim_angle - TUNING.GOLF_AIM_ARC * 0.5
			local minanglepos = Vector3(pos.x + math.cos(-minangle) * RANGE, 0 , pos.z + math.sin(-minangle) * RANGE)
			local maxangle = base_aim_angle + TUNING.GOLF_AIM_ARC * 0.5
			local maxanglepos = Vector3(pos.x + math.cos(-maxangle) * RANGE, 0 , pos.z + math.sin(-maxangle) * RANGE)

			local facingpos = Vector3(pos.x + newx * RANGE, 0, pos.z + newz * RANGE)
			local dist_to_min = VecUtil_Dist(facingpos.x, facingpos.z, minanglepos.x, minanglepos.z)
			local dist_to_max = VecUtil_Dist(facingpos.x, facingpos.z, maxanglepos.x, maxanglepos.z)

			facingpos = dist_to_min < dist_to_max and maxanglepos or minanglepos
			return facingpos
		end
	end

	pos.x = pos.x - (newx * RANGE)
	pos.z = pos.z - (newz * RANGE)
	return pos
end

local function reticule_mouse_target_function(inst, mousepos)
	if mousepos == nil or ThePlayer == nil then
		return nil
	end

	local self = inst.components.golfclub_reticule
	local target = self and self.target:value()
	local pos = (target or ThePlayer):GetPosition()
	local dir = pos - mousepos
	if dir.x ~= 0 or dir.z ~= 0 then
		dir = dir:GetNormalized()
		return ClampReticulePos(inst, pos, dir.x, dir.z)
	end

	local pt = Vector3(ThePlayer.entity:LocalToWorldSpace(RANGE, 0, 0))
	if target then
		pt = pt + pos - ThePlayer:GetPosition()
	end
	return pt
end

local function reticule_target_function(inst)
	local self = inst.components.golfclub_reticule
	local target = self and self.target:value()

	if ThePlayer and ThePlayer.components.playercontroller and ThePlayer.components.playercontroller.isclientcontrollerattached then
		local dir = Vector3()
		dir.y = 0
		--[[if TheInput:SupportsControllerFreeAiming() then
			dir.x = TheInput:GetAnalogControlValue(VIRTUAL_CONTROL_AIM_RIGHT) - TheInput:GetAnalogControlValue(VIRTUAL_CONTROL_AIM_LEFT)
			dir.z = TheInput:GetAnalogControlValue(VIRTUAL_CONTROL_AIM_UP) - TheInput:GetAnalogControlValue(VIRTUAL_CONTROL_AIM_DOWN)
		else]]
			dir.x = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
			dir.z = TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) - TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)
		--end
		local deadzone = TUNING.CONTROLLER_DEADZONE_RADIUS

		local reticule = inst.components.reticule.reticule
		if math.abs(dir.x) >= deadzone or math.abs(dir.z) >= deadzone then
			dir = dir:GetNormalized()
			if reticule then
				reticule._lastdir = dir
			end
		else
			dir = reticule and reticule._lastdir
		end

		if dir then
			local pos = (target or ThePlayer):GetPosition()

			local Camangle = TheCamera:GetHeading()/180
			local theta = PI * (Camangle - 0.5)
			local sintheta = math.sin(theta)
			local costheta = math.cos(theta)

			local newx = dir.x * costheta - dir.z * sintheta
			local newz = dir.x * sintheta + dir.z * costheta

			return ClampReticulePos(inst, pos, newx, newz)
		end
	end

	local pt = Vector3((ThePlayer or inst).entity:LocalToWorldSpace(RANGE, 0, 0))
	if target then
		pt = pt + target:GetPosition() - (ThePlayer or inst):GetPosition()
	end
	return pt
end

local function reticule_update_position_function(inst, pos, reticule, ease, smoothing, dt)
	local self = inst.components.golfclub_reticule
	reticule.Transform:SetPosition(pos:Get())
	reticule.Transform:SetRotation((self and self.target:value() or ThePlayer or inst):GetAngleToPoint(pos))
end

function GolfClubReticule:OnTargetDirty(owner)
	self._chargingpt = nil

	local target = self.target:value()
	if target == nil then
		if self.aim_range_fx then
			self.aim_range_fx:Remove()
			self.aim_range_fx = nil
		end

		if self.inst.components.reticule then
			--ping if we successfully started a hit after charging
			local reticule = self.inst.components.reticule.reticule
			if reticule and self.chargeticks:value() ~= CHARGETICKS_OFF and owner:HasTag("golf_charging") then
				local ping = SpawnPrefab("golfclub_reticuleping")
				ping.Transform:SetPosition(reticule.Transform:GetWorldPosition())
				ping.Transform:SetRotation(reticule.Transform:GetRotation())
				ping.AnimState:SetMultColour(204 / 255, 131 / 255, 57 / 255, 1)
				ping.AnimState:SetAddColour(0.2, 0.2, 0.2, 0)
				ping:SetChargeScale(self:CalculateChargingScale())
			end

			self.inst:RemoveComponent("reticule")
			owner.components.playercontroller:RefreshReticule()
		end

		if self.chargeticks:value() ~= CHARGETICKS_OFF then
			self.chargeticks:set_local(CHARGETICKS_OFF)
			self.inst:StopUpdatingComponent(self)
		end
	elseif owner.HUD then
		if self.aim_range_fx == nil then
			self.aim_range_fx = SpawnPrefab("cannon_aoe_range_fx")
			self.aim_range_fx.Transform:SetPosition(target.Transform:GetWorldPosition())
			self.aim_range_fx.Transform:SetRotation(owner.Transform:GetRotation())
			self.aim_range_fx.AnimState:SetScale(.4, .4)
			local platform = target.entity:GetPlatform()
			if platform then
				platform:AddPlatformFollower(self.aim_range_fx)
			end
		end

		if self.inst.components.reticule then
			self.inst.components.reticule:DestroyReticule()
		else
			self.inst:AddComponent("reticule")
			self.inst.components.reticule.mouseenabled = true
			self.inst.components.reticule.ispassableatallpoints = true
		end
		self.inst.components.reticule.reticuleprefab = "golfclub_reticule_fx"
		self.inst.components.reticule.mousetargetfn = reticule_mouse_target_function
		self.inst.components.reticule.targetfn = reticule_target_function
		self.inst.components.reticule.updatepositionfn = reticule_update_position_function

		owner.components.playercontroller:RefreshReticule(self.inst)
	end
end

local function reticule_charging_target_function(inst)
	local self = inst.components.golfclub_reticule
	if self and self._chargingpt then
		return self._chargingpt
	end

	local pt = Vector3((ThePlayer or inst).entity:LocalToWorldSpace(RANGE, 0, 0))
	local target = self and self.target:value()
	if target then
		pt = pt + target:GetPosition() - (ThePlayer or inst):GetPosition()
	end
	return pt
end

local function reticule_charging_update_position_function(inst, pos, reticule, ease, smoothing, dt)
	local self = inst.components.golfclub_reticule
	local root = self and self.target:value() or ThePlayer or inst
	reticule.Transform:SetPosition(root.Transform:GetWorldPosition())
	reticule.Transform:SetRotation(root:GetAngleToPoint(pos))
end

function GolfClubReticule:StartCharging(owner, pt)
	if self.target:value() then
		if self.aim_range_fx then
			self.aim_range_fx:Remove()
			self.aim_range_fx = nil
		end

		if self.inst.components.reticule then
			self.inst.components.reticule:DestroyReticule()
		elseif owner.HUD then
			self.inst:AddComponent("reticule")
			self.inst.components.reticule.mouseenabled = true
			self.inst.components.reticule.ispassableatallpoints = true
		end
		if self.inst.components.reticule then
			self.inst.components.reticule.reticuleprefab = "golfclub_reticulecharging"
			self.inst.components.reticule.mousetargetfn = reticule_charging_target_function
			self.inst.components.reticule.targetfn = reticule_charging_target_function
			self.inst.components.reticule.updatepositionfn = reticule_charging_update_position_function

			--predict fixed charging dir since player rotation might be interpolated
			self._chargingpt = pt

			owner.components.playercontroller:RefreshReticule()
		end

		if self.chargeticks:value() == CHARGETICKS_OFF then
			if self.ismastersim then
				self.chargeticks:set(0)
				self:OnChargeTicksDirty()
				self.inst:StartUpdatingComponent(self)
			elseif owner.HUD then
				self.chargeticks:set_local(0)
				if self:OnChargeTicksDirty() then
					self.inst:StartUpdatingComponent(self)
				end
			end
		end
	end
end

function GolfClubReticule:GetTarget()
	return self.target:value()
end

function GolfClubReticule:CalculateChargingScale()
	return math.min(1, self.chargeticks:value() / TUNING.GOLF_MAX_CHARGE_TICKS)
end

function GolfClubReticule:OnChargeTicksDirty()
	local reticule = self.inst.components.reticule and self.inst.components.reticule.reticule
	if reticule then
		reticule:SetChargeScale(self:CalculateChargingScale())
		return true
	end
	return false
end

function GolfClubReticule:OnUpdate(dt)
	if dt <= 0 then
		return
	end

	if self.ismastersim then
		--periodic force sync, otherwise no need since client predicts
		local t = self.chargeticks:value() + 1
		if t % 15 == 0 then
			self.chargeticks:set(t)
		else
			self.chargeticks:set_local(t)
		end
		if t >= TUNING.GOLF_MAX_CHARGE_TICKS then
			self.chargeticks:set(TUNING.GOLF_MAX_CHARGE_TICKS)
			self.inst:StopUpdatingComponent(self)
		end
		local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem.owner
		if owner and owner.HUD and owner.components.playercontroller then
			self:OnChargeTicksDirty(owner)
		end
	else
		--limit how far ahead client can predict
		if self.chargeticks:value() % 15 ~= 0 then
			self.chargeticks:set_local(self.chargeticks:value() + 1)

			local inventoryitem = self.inst.replica.inventoryitem
			if inventoryitem and inventoryitem:IsHeldBy(ThePlayer) and ThePlayer.components.playercontroller then
				self:OnChargeTicksDirty(ThePlayer)
			end
		end
	end
end

function GolfClubReticule:CancelTarget_Client()
	if self.target:value() then
		local inventoryitem = self.inst.replica.inventoryitem
		if inventoryitem and inventoryitem:IsHeldBy(ThePlayer) and ThePlayer.components.playercontroller then
			self.target:set_local(nil)
			self:OnTargetDirty(ThePlayer)
		end
	end
end

--------------------------------------------------------------------------
--Server interface

function GolfClubReticule:IsMaxCharge()
	return self.chargeticks:value() == TUNING.GOLF_MAX_CHARGE_TICKS
end

function GolfClubReticule:SetTarget(target)
	if self.target:value() ~= target then
		self.target:set(target)

		local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem.owner
		if owner and owner.components.playercontroller then
			self:OnTargetDirty(owner)
		end
	end
end

return GolfClubReticule
