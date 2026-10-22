require("behaviours/chaseandattack")
require("behaviours/faceentity")
require("behaviours/wander")

local ShroudenBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

local function GetHome(inst)
	return inst.components.knownlocations:GetLocation("spawnpoint")
end

local function GetFaceTargetFn(inst)
	local target = Ents[inst.components.combat.lasttargetGUID]
	if not (target and target.sg and target.sg:HasStateTag("devoured")) then
		target = nil
		local x, _, z = inst.Transform:GetWorldPosition()
		local mindsq = math.huge
		for k in pairs(inst.components.grouptargeter:GetTargets()) do
			if k.sg:HasStateTag("devoured") then
				local dsq = k:GetDistanceSqToPoint(x, 0, z)
				if dsq < mindsq then
					mindsq = dsq
					target = k
				end
			end
		end
	end
	return target
end

local function KeepFaceTargetFn(inst, target)
	if not (inst.components.combat:HasTarget() or inst.components.health:IsDead()) then
		if target.sg and target.sg:HasStateTag("devoured") then
			if inst.components.grouptargeter:GetNumTargets() <= 1 then
				inst.components.combat:OverrideCooldown(math.max(inst.components.combat:GetCooldown(), inst.components.combat.min_attack_period * 0.667))
			end
			return true
		elseif not IsEntityDeadOrGhost(target) then
			local inarena = inst:IsInArena()
			local x1, _, z1 = target.Transform:GetWorldPosition()
			if (inarena and TheWorld.Map:IsPointInCharlieBossArena(x1, 0, z1)) or
				(not inarena and inst:GetDistanceSqToPoint(x1, 0, z1) < TUNING.SHROUDEN_DEAGGRO_DIST * TUNING.SHROUDEN_DEAGGRO_DIST)
			then
				inst.components.combat:SetTarget(target)
			end
		end
	end
	return false
end

function ShroudenBrain:OnStart()
	local root = PriorityNode({
		ParallelNodeAny{
			ChaseAndAttack(self.inst),
			ConditionWaitNode(function()
				if not self.inst.components.combat:InCooldown() then
					local target = self.inst.components.combat.target
					if target then
						local x1, _, z1 = target.Transform:GetWorldPosition()
						local dsq = self.inst:GetDistanceSqToPoint(x1, 0, z1)
						local physrad = target:GetPhysicsRadius(0)
						local range = TUNING.SHROUDEN_ATTACK_RANGE + physrad
						if dsq >= range * range then
							if self.inst:IsInArena() then
								if TheWorld.Map:IsPointInCharlieBossArena(x1, 0, z1) then
									self.inst:PushEvent("dofarattack")
								end
							else
								range = 20 + physrad
								if dsq < range * range then
									self.inst:PushEvent("dofarattack")
								end
							end
						end
					end
				end
				return false
			end),
		},
		ParallelNode{
			FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
			ActionNode(function()
				self.inst:PushEvent("targetdevoured")
			end),
		},
		Wander(self.inst, GetHome, 8),
	}, 0.25)

	self.bt = BT(self.inst, root)
end

function ShroudenBrain:OnInitializationComplete()
	self.inst.components.knownlocations:RememberLocation("spawnpoint", self.inst:GetPosition(), true)
end

return ShroudenBrain
