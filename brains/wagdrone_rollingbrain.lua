require("behaviours/leash")
require("behaviours/standstill")

local easing = require("easing")
local WagdroneCommon = require("prefabs/wagdrone_common")

local DEBUG_MODE = BRANCH == "dev"

local RECOIL_DURATION = 0.7
local RECOIL_DECEL_DURATION = RECOIL_DURATION * 0.7
local RECOIL_ACCEL_DURATION = RECOIL_DECEL_DURATION
local RECOIL_MAX_DECEL = -0.6
local HALFPI = math.pi / 2

local WagdroneRollingBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
	self.target = nil
	self.dest = Vector3()
	self.recoildest = Vector3()
	self.recoilangleoffset = nil
	self.recoiltime = nil
	self.recoilspeedmult = 1
	self.recoilacceltime = nil
end)

local function GetPlayerActionOnMe(inst, player)
	local target
	local act = player:GetBufferedAction()
	if act then
		target = act.target
		act = act.action
	elseif player.components.playercontroller then
		act, target = player.components.playercontroller:GetRemoteInteraction()
	end
	return target == inst and act or nil
end

local function IsPlayerTryingToPickup(inst)
	for i, v in ipairs(AllPlayers) do
		if GetPlayerActionOnMe(inst, v) == ACTIONS.PICKUP then
			return true
		end
	end
end

local function GetDeployPoint(inst)
	return inst.components.knowndynamiclocations and inst.components.knowndynamiclocations:GetDynamicLocation("deploypoint")
end

local function ValidateExistingTarget(target, platform)
	if target:IsInLimbo() or not (target:IsValid() and target.entity:IsVisible()) or
		(target.components.health and target.components.health:IsDead()) or
		target:GetCurrentPlatform() ~= platform
	then
		return false
	elseif target:HasTag("wagdrone_rolling") then
		return not target.sg:HasAnyStateTag("stationary", "broken", "off")
			and not (target.components.workable and target.components.workable:CanBeWorked())
			and not target:HasAnyTag("NOCLICK", "usesdepleted")
	elseif target.components.workable and target.components.workable:CanBeWorked() then
		local work_action = target.components.workable:GetWorkAction()
		return work_action == ACTIONS.CHOP or work_action == ACTIONS.MINE
			and not target:HasTag("NOCLICK")
	end
	return false
end

local DRONE_TAGS = { "wagdrone_rolling" }
local DRONE_NO_TAGS = { "INLIMBO", "NOCLICK", "HAMMER_workable", "usesdepleted" }
local WORK_TAGS = { "CHOP_workable", "MINE_workable" }
local WORK_NO_TAGS = { "INLIMBO", "NOCLICK", "waxedplant", "event_trigger" }

function FriendlyTargeting(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	local pos = GetDeployPoint(inst)
	if pos then
		local x0, y0, z0 = pos:GetPosition():Get()
		local platform0 = pos.walkable_platform
		local r = TUNING.WAGDRONE_ROLLING_WORK_RADIUS
		local mindsq = math.huge
		local closest = nil
		for i, v in ipairs(TheSim:FindEntities(x0, y0, z0, r, nil, WORK_NO_TAGS, WORK_TAGS)) do
			if v ~= inst and v.entity:IsVisible() and
				not (v.components.health and v.components.health:IsDead()) and
				v:GetCurrentPlatform() == platform0
			then
				local x1, y1, z1 = v.Transform:GetWorldPosition()
				if distsq(x1, z1, x0, z0) < r * r then --FindEntities is <= r
					local dsq = distsq(x1, z1, x, z)
					if dsq < mindsq then
						mindsq = dsq
						closest = v
					end
				end
			end
		end
		if closest == nil then
			for i, v in ipairs(TheSim:FindEntities(x0, y0, z0, r, DRONE_TAGS, DRONE_NO_TAGS)) do
				if v ~= inst and v.entity:IsVisible() and
					not v.components.health:IsDead() and
					not v.sg:HasAnyStateTag("stationary", "broken", "off") and
					v:GetCurrentPlatform() == platform0
				then
					local x1, y1, z1 = v.Transform:GetWorldPosition()
					if distsq(x1, z1, x0, z0) < r * r then --FindEntities is <= r
						local dsq = distsq(x1, z1, x, z)
						if dsq < mindsq then
							mindsq = dsq
							closest = v
						end
					end
				end
			end
		end
		if DEBUG_MODE and closest then
			assert(ValidateExistingTarget(closest, platform0))
		end
		return closest
	end

	local platform = inst:GetCurrentPlatform()
	for i, v in ipairs(TheSim:FindEntities(x, y, z, 16, DRONE_TAGS, DRONE_NO_TAGS)) do
		if v ~= inst and v.entity:IsVisible() and
			not (v.components.health and v.components.health:IsDead()) and
			not v.sg:HasAnyStateTag("stationary", "broken", "off") and
			v:GetCurrentPlatform() == platform
		then
			if DEBUG_MODE then
				assert(ValidateExistingTarget(v, platform))
			end
			return v
		end
	end
end

function WagdroneRollingBrain:UpdateTargetDest()
	local target
	local x, y, z = self.inst.Transform:GetWorldPosition()
	local pos = GetDeployPoint(self.inst)
	local ignorerange, validated
	if pos then
		local pt0 = pos:GetPosition()
		local platform0 = pos.walkable_platform
		local r = TUNING.WAGDRONE_ROLLING_WORK_RADIUS
		if EntityScript.is_instance(self.target) then
			if not ValidateExistingTarget(self.target, platform0) or self.target:GetDistanceSqToPoint(pt0:Get()) >= r * r then
				self:ResetTargets()
				return nil
			end
			target = self.target
		else
			target =
				FriendlyTargeting(self.inst) or
				(distsq(pt0.x, pt0.z, x, z) > 1 and pt0) or
				nil
			if target == nil then
				self:ResetTargets()
				return nil
			end
		end
		ignorerange = true
		validated = true
	else
		target = self.inst.dest or self.target
		if target == nil then
			target = FriendlyTargeting(self.inst)
			validated = true
		end
	end
	if target then
		local x1, y1, z1
		if not target:is_a(EntityScript) then
			x1, y1, z1 = target:Get()
		elseif validated or ValidateExistingTarget(target, self.inst:GetCurrentPlatform()) then
			x1, y1, z1 = target.Transform:GetWorldPosition()
		else
			self:ResetTargets()
			return nil
		end
		local dx = x1 - x
		local dz = z1 - z
		if dx ~= 0 or dz ~= 0 then
			local dsq = dx * dx + dz * dz
			local range = not ignorerange and target:is_a(EntityScript) and (target.isplayer and 8 or 16) or nil
			if range == nil or dsq < range * range then
				local isvalid
				if EntityScript.is_instance(self.target) then --existing target, check facing
					local rot = self.inst.Transform:GetRotation()
					local rot1 = math.atan2(-dz, dx) * RADIANS
					isvalid = DiffAngle(rot, rot1) < 60
				else
					isvalid = true
					self.target = target
				end
				if isvalid then
					local dist = math.sqrt(dsq)
					dist = (dist + 5) / dist
					self.dest.x = x + dx * dist
					self.dest.z = z + dz * dist
				end
			end
		end
		if self.target and self.recoiltime then
			local t = GetTime()
			local elapsed = t - self.recoiltime
			if elapsed < RECOIL_DURATION then
				local dx2 = self.dest.x - x
				local dz2 = self.dest.z - z
				if dx2 ~= 0 or dz2 ~= 0 then
					local k = elapsed / RECOIL_DURATION
					local offset = self.recoilangleoffset * (1 - k * k)
					local angle = math.atan2(-dz2, dx2) + offset
					local dist = math.sqrt(dx2 * dx2 + dz2 * dz2)

					self.recoildest.x = x + math.cos(angle) * dist
					self.recoildest.z = z - math.sin(angle) * dist

					local absoffset = math.abs(self.recoilangleoffset)
					if absoffset > HALFPI and elapsed < RECOIL_DECEL_DURATION then
						local peakdecel = 1 - math.min(1, (absoffset - HALFPI) / HALFPI)
						peakdecel = RECOIL_MAX_DECEL * (1 - peakdecel * peakdecel)
						self.recoilspeedmult = easing.outQuad(elapsed, 1, peakdecel, RECOIL_DECEL_DURATION)
						self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "recoil", self.recoilspeedmult)
						self.recoilacceltime = t
					else
						self:AccelAfterRecoil()
					end
					return self.recoildest
				end
			end
			self.recoiltime = nil
		end
	end

	self:AccelAfterRecoil()
	return self.target and self.dest or nil
end

function WagdroneRollingBrain:AccelAfterRecoil()
	if self.recoilacceltime then
		local elapsed = GetTime() - self.recoilacceltime
		if elapsed < RECOIL_ACCEL_DURATION then
			local speedmult = easing.inQuad(elapsed, self.recoilspeedmult, 1 - self.recoilspeedmult, RECOIL_ACCEL_DURATION)
			self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "recoil", speedmult)
		else
			self.inst.components.locomotor:RemoveExternalSpeedMultiplier(self.inst, "recoil")
			self.recoilacceltime = nil
		end
	end
end

function WagdroneRollingBrain:SetRecoilAngle(recoilangle)
	if self.target then
		local x, y, z = self.inst.Transform:GetWorldPosition()
		local dx = self.dest.x - x
		local dz = self.dest.z - z
		if dx ~= 0 or dz ~= 0 then
			local destangle = math.atan2(-dz, dx)
			self.recoilangleoffset = ReduceAngleRad(recoilangle - destangle)
			self.recoiltime = GetTime()
			self.recoilacceltime = nil
			self.inst.components.locomotor:RemoveExternalSpeedMultiplier(self.inst, "recoil")
			self:ForceUpdate()
		end
	end
end

function WagdroneRollingBrain:ResetTargets()
	self.target = nil
	self.recoiltime = nil
	self:AccelAfterRecoil()
end

function WagdroneRollingBrain:OnStart()
	local root = PriorityNode({
		WhileNode(
			function()
				return self.inst.persists--not self.inst.sg.mem.todespawn
					and not self.inst.sg:HasStateTag("off")
			end,
			"<busy state guard",
			PriorityNode({
				WhileNode(function() return IsPlayerTryingToPickup(self.inst) end, "Wait for Pickup",
					StandStill(self.inst)),
				FailIfSuccessDecorator(Leash(self.inst, function(inst) return self:UpdateTargetDest() end, 1, 0.6, true)),
				FailIfSuccessDecorator(ActionNode(function() self:ResetTargets() end, "Target Cancelled")),
				StandStill(self.inst),
			}, 0.25)),
	}, 0.25)

	self.bt = BT(self.inst, root)

	if self._onrecoil == nil then
		self._onrecoil = function(inst, angle) self:SetRecoilAngle(angle) end
		self.inst:ListenForEvent("spinning_recoil", self._onrecoil)
	end
end

function WagdroneRollingBrain:OnStop()
	if self._onrecoil then
		self.inst:RemoveEventCallback("spinning_recoil", self._onrecoil)
		self._onrecoil = nil
	end
	self.target = nil
	self.recoiltime = nil
	if self.recoilacceltime then
		self.recoilacceltime = nil
		self.inst.components.locomotor:RemoveExternalSpeedMultiplier(self.inst, "recoil")
	end
end

return WagdroneRollingBrain
