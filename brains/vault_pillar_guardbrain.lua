require("behaviours/chaseandattack")
require("behaviours/faceentity")
require("behaviours/wander")

local Vault_Pillar_GuardBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

local function GetHomePos(inst)
	return inst.components.knownlocations:GetLocation("spawnpoint")
end

local function GetPointAtTargetFn(inst)
	return inst.components.combat.target
end

local function KeepPointAtTargetFn(inst, target)
	return inst.components.combat:TargetIs(target) and not inst:IsNear(target, 4)
end

local function GetFaceTargetFn(inst)
	if inst.trial then
		local x, y, z = inst.Transform:GetWorldPosition()
		local invault = TheWorld.Map:IsPointInVaultRoom(x, y, z)
		local mindsq = invault and 3600 or 256
		local closest
		for _, v in ipairs(AllPlayers) do
			if not IsEntityDeadOrGhost(v) and v.entity:IsVisible() then
				local x1, y1, z1 = v.Transform:GetWorldPosition()
				local dsq = math2d.DistSq(x, z, x1, z1)
				if dsq < mindsq and invault == TheWorld.Map:IsPointInVaultRoom(x1, y1, z1) then
					mindsq = dsq
					closest = v
				end
			end
		end
		return closest
	end
end

local function KeepFaceTargetFn(inst, target)
	if IsEntityDeadOrGhost(target) or not target.entity:IsVisible() then
		return false
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local invault = TheWorld.Map:IsPointInVaultRoom(x, y, z)

	local x1, y1, z1 = target.Transform:GetWorldPosition()
	local invault1 = TheWorld.Map:IsPointInVaultRoom(x1, y1, z1)

	if invault then
		return invault1
	end
	return not invault1 and math2d.DistSq(x, z, x1, z1) < 576
end

local function GetHomeBetweenTargetPos(inst)
	local target = inst.components.combat.target
	local home = GetHomePos(inst)
	if target and home then
		local x, y, z = inst.Transform:GetWorldPosition()
		local dx = home.x - x
		local dz = home.z - z
		if dx * dx + dz * dz >= 4 then
			local x1, y1, z1 = target.Transform:GetWorldPosition()
			local dx1 = x1 - x
			local dz1 = z1 - z
			if dx1 * dx1 + dz1 * dz1 >= 64 then
				local dir = math.atan2(-dz, dx)
				local dir1 = math.atan2(-dz1, dx1)
				if DiffAngleRad(dir, dir1) < HALFPI then
					return home
				end
			end
		end
	end
end

local function ShouldChase(self)
	local inst = self.inst
	local home = GetHomePos(inst)
	if home and inst.trial then
		local target = inst.components.combat.target
		if target then
			local t = GetTime()

			--prevent going in and out of alert too quickly
			if self.nextalert then
				if self.nextalert > t then
					return true
				end
				self.nextalert = nil
			end

			local alerttime = inst.sg.currentstate.name == "alert" and inst.sg:GetTimeInState() or 0

			local x, y, z = inst.Transform:GetWorldPosition()
			local x1, y1, z1 = target.Transform:GetWorldPosition()
			local mindsq = math2d.DistSq(x, z, x1, z1)

			--attack within melee range (extends the longer we've been on alert)
			if not inst.components.combat:InCooldown() then
				local range = 2 + TUNING.VAULT_PILLAR_GUARD_ATTACK_RANGE + target:GetPhysicsRadius(0)
				if self.atkrangetime == nil then
					self.atkrangetime = math.random() * 4
				end
				range = range + math.clamp((alerttime - self.atkrangetime) / 4, 0, 4)
				if mindsq < range * range then
					if alerttime > 0 then
						self.nextalert = t + 3 + math.random() * 2
						self.atkrangetime = nil
					end
					return true
				end
			end

			local alertdsq = math2d.DistSq(x1, z1, home.x, home.z) / 4
			if alerttime <= 0 and inst.sg:HasStateTag("moving") then
				--keep chasing until reached alert distance
				if alertdsq < mindsq then
					return true
				end
			else
				--cancel alert if target moves too far
				local dist = math.sqrt(mindsq)
				local alertdist = math.sqrt(alertdsq)
				if self.minalerttime == nil then
					self.minalerttime = 5 + math.random() * 4
				end
				alertdist = alertdist + (alerttime < self.minalerttime and 3 or -4)
				if alertdist < dist then
					self.nextalert = t + 2 + math.random()
					self.minalerttime = nil
					return true
				end
			end

			--attack if we're closest, otherwise move on to alert nodes
			local closest = inst
			for i = 1, 4 do
				local guard = inst.trial.components.entitytracker:GetEntity("guard"..tostring(i))
				if guard and guard ~= inst and guard.components.combat:TargetIs(target) then
					local dsq = guard:GetDistanceSqToPoint(x1, y1, z1)
					if dsq < mindsq then
						mindsq = dsq
						closest = guard
					end
				end
			end
			return closest == inst
		end
	end
	return true
end

--------------------------------------------------------------------------
--crafted (non-trial) versions

local function crafted_ShouldChase(inst)
	local home = GetHomePos(inst)
	if home == nil then
		return true
	end

	local target = inst.components.combat.target
	return target ~= nil and target:GetDistanceSqToPoint(home) < TUNING.VAULT_PILLAR_GUARD_COMBAT_RANGE * TUNING.VAULT_PILLAR_GUARD_COMBAT_RANGE
end

local function crafted_ShouldPointAtTarget(inst)
	local target = inst.components.combat.target
	if target == nil then
		return false
	end

	local home = GetHomePos(inst)
	if home == nil then
		return false
	end

	local x1, y1, z1 = target.Transform:GetWorldPosition()
	local dsq = math2d.DistSq(x1, z1, home.x, home.z)
	local range = TUNING.VAULT_PILLAR_GUARD_COMBAT_RANGE
	if dsq >= range * range then
		return true --still outside our max combat range (from home)
	end
	range = range - 4
	if dsq < range * range then
		return false --within aggro range (from home)
	elseif inst:GetDistanceSqToPoint(x1, y1, z1) < 16 then
		return false --within melee range (from me)
	end
	return true
end

local function crafted_KeepPointAtTargetFn(inst, target)
	return inst.components.combat:TargetIs(target)
end

local function crafted_GetPointAtTargetPos(inst)
	local target = inst.components.combat.target
	if target then
		local home = GetHomePos(inst)
		if home then
			local x1, y1, z1 = target.Transform:GetWorldPosition()
			local dx = x1 - home.x
			local dz = z1 - home.z
			local len = (TUNING.VAULT_PILLAR_GUARD_COMBAT_RANGE - 10) / math.sqrt(dx * dx + dz * dz)
			return Vector3(home.x + dx * len, 0, home.z + dz * len)
		end
	end
end

--------------------------------------------------------------------------

function Vault_Pillar_GuardBrain:OnStart()
	local _ChaseAndAttackOrJump =
		ParallelNodeAny{
			ChaseAndAttack(self.inst),
			SequenceNode{
				WaitNode(4),
				ConditionWaitNode(function()
					local target = self.inst.components.combat.target
					if target and self.inst.canquickjump and self.inst:IsNear(target, 8) then
						self.inst:PushEvent("ms_pillarguard_quickjump", { target = target })
						return true
					end
					return false
				end, "quickjump"),
			},
		}

	local _Wander =
		Wander(self.inst, GetHomePos, 4, {
			minwalktime = 2.5,
			randwalktime = 1.5,
			minwaittime = 4,
			randwaittime = 2,
		})

	local root
	if self.inst.trial then
		root = PriorityNode({
			WhileNode(
				function() return not self.inst.sg:HasStateTag("jumping") end,
				"<busy state guard>",
				PriorityNode({
					Leash(self.inst, GetHomeBetweenTargetPos, 1, 1),
					WhileNode(function() return ShouldChase(self) end, "chase and attack",
						_ChaseAndAttackOrJump),
					FaceEntity(self.inst, GetPointAtTargetFn, KeepPointAtTargetFn),
					FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn, 3), -- 3s refresh timer to pick new target (or same one again).
					_Wander,
				}, 0.25)),
			}, 0.25)
	else --crafted
		root = PriorityNode({
			WhileNode(
				function() return not self.inst.sg:HasStateTag("jumping") end,
				"<busy state guard>",
				PriorityNode({
					WhileNode(function() return crafted_ShouldChase(self.inst) end, "chase and attack", _ChaseAndAttackOrJump),
					WhileNode(function() return crafted_ShouldPointAtTarget(self.inst) end, "point at target",
						PriorityNode({
							Leash(self.inst, crafted_GetPointAtTargetPos, 6, 0.5),
							FaceEntity(self.inst, GetPointAtTargetFn, crafted_KeepPointAtTargetFn),
						}, 0.25)),
					_Wander,
				}, 0.25)),
			}, 0.25)
	end

	self.bt = BT(self.inst, root)
end

function Vault_Pillar_GuardBrain:OnInitializationComplete()
	self.inst.components.knownlocations:RememberLocation("spawnpoint", self.inst:GetPosition(), true)
end

return Vault_Pillar_GuardBrain
