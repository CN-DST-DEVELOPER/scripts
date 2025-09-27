require("behaviours/wander")

local AlterGuardian_Phase4_LunarRiftBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

local function GetHome(inst)
	local map = TheWorld.Map
	if map:IsPointInWagPunkArena(inst.Transform:GetWorldPosition()) then
		local x, z = map:GetWagPunkArenaCenterXZ()
		--NOTE: center won't be nil if IsPointInWagPunkArena succeeded
		return Vector3(x, 0, z)
	end
end

function AlterGuardian_Phase4_LunarRiftBrain:OnStart()
	local root = PriorityNode({
		WhileNode(
			function()
				return not self.inst.sg:HasAnyStateTag("jumping", "dead")
			end,
			"<busy state guard>",
			PriorityNode({
				ParallelNode{
					ConditionWaitNode(function()
						if self.inst.components.combat:HasTarget() and not self.inst.components.combat:InCooldown() then
							self.inst.components.combat.ignorehitrange = true
							self.inst.components.combat:TryAttack()
							self.inst.components.combat.ignorehitrange = false
						end
						return false --forever RUNNING status
					end, "TryRangedAttack"),
					FailIfSuccessDecorator(ChaseAndAttack(self.inst)),
				},
				Wander(self.inst, GetHome, 4),
			}, 0.5)),
	}, 0.5)

	self.bt = BT(self.inst, root)
end

return AlterGuardian_Phase4_LunarRiftBrain
