local ChargingReticule = Class(function(self, inst)
	self.inst = inst
	self.ease = false
	self.smoothing = 6.66
	self.targetpos = nil
	self.followhandler = nil
	self.owner = nil

	inst.AnimState:SetMultColour(204 / 255, 131 / 255, 57 / 255, 1)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

	self._oncameraupdate = function(dt) self:OnCameraUpdate(dt) end
end)

function ChargingReticule:OnRemoveEntity()
	if self.followhandler then
		self.followhandler:Remove()
		self.followhandler = nil
	end
	TheCamera:RemoveListener(self, self._oncameraupdate)
end

function ChargingReticule:GetMouseTargetXZ(x, y)
	local z
	x, y, z = TheSim:ProjectScreenPos(x, y)
	return x, z --can be nil
end

function ChargingReticule:GetControllerTargetXZ()
	local xdir = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
	local ydir = TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) - TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)
	local deadzone = TUNING.CONTROLLER_DEADZONE_RADIUS
	if math.abs(xdir) >= deadzone or math.abs(ydir) >= deadzone then
		local dir = TheCamera:GetRightVec() * xdir - TheCamera:GetDownVec() * ydir
		dir:Normalize()
		local x, y, z = self.inst.Transform:GetWorldPosition()
		return x + dir.x, z + dir.z
	end
end

function ChargingReticule:LinkToEntity(target)
	self.owner = target

	self:UpdatePosition_Internal()

	if not TheInput:ControllerAttached() then
		self.followhandler = TheInput:AddMoveHandler(function(x, y)
			self:UpdatePosition_Internal()
			self.targetpos.x, self.targetpos.z = self:GetMouseTargetXZ(x, y)
			self:UpdateRotation_Internal(nil)
		end)
		local x, z = self:GetMouseTargetXZ(TheSim:GetPosition())
		if x and z then
			self.targetpos = Vector3(x, 0, z)
		end
	else
		local x, z = self:GetControllerTargetXZ()
		if x and z then
			self.targetpos = Vector3(x, 0, z)
		end
	end

	if self.targetpos == nil then
		local theta = target.Transform:GetRotation() * DEGREES
		local x, y, z = target.Transform:GetWorldPosition()
		self.targetpos = Vector3(x + math.cos(theta), 0, z - math.sin(theta))
	end

	self:UpdateRotation_Internal()

	TheCamera:AddListener(self, self._oncameraupdate)
end

function ChargingReticule:UpdatePosition_Internal()
	local x, y, z = self.owner.Transform:GetWorldPosition()
	self.inst.Transform:SetPosition(x, 0, z)
end

function ChargingReticule:UpdateRotation_Internal(dt)
	local rot1 = self.inst:GetAngleToPoint(self.targetpos)
	if self.ease and dt then
		local rot = self.inst.Transform:GetRotation()
		local drot = ReduceAngle(rot1 - rot)
		rot1 = rot + drot * math.clamp(dt * self.smoothing, 0, 1)
	end
	self.inst.Transform:SetRotation(rot1)
end

function ChargingReticule:OnCameraUpdate(dt)
	self:UpdatePosition_Internal()

	if self.followhandler then
		local x, z = self:GetMouseTargetXZ(TheSim:GetPosition())
		if x and z then
			self.targetpos.x, self.targetpos.z = x, z
			self:UpdateRotation_Internal(nil)
		end
	else
		local x, z = self:GetControllerTargetXZ()
		if x and z then
			self.targetpos.x, self.targetpos.z = x, z
		end
		self:UpdateRotation_Internal(dt) --always update for dt easing
	end
end

function ChargingReticule:Snap()
	if self.owner then
		self:UpdatePosition_Internal()
		self.inst:ForceFacePoint(self.targetpos)
	end
end

return ChargingReticule
