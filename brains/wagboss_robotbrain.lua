require("behaviours/leash")
require("behaviours/standstill")
require("behaviours/wander")

local WagbossRobotBrain = Class(Brain, function(self, inst)
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

function WagbossRobotBrain:OnStart()
	local root
	if self.inst.hostile then
		--hostile brain
		root = PriorityNode({
			WhileNode(
				function()
					return self.inst.shouldreset
				end,
				"<reset>",
				PriorityNode({
					Leash(self.inst, GetHome, 0.2, 0.2),
					ActionNode(function()
						local pt = GetHome(self.inst)
						if pt then
							self.inst.Physics:Teleport(pt:Get())
						end
						self.inst:PushEvent("deactivate")
					end),
				}, 0.5)),
			WhileNode(
				function()
					return not self.inst.sg:HasStateTag("jumping")
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
					Leash(self.inst, GetHome, 6, 2),
					Wander(self.inst, GetHome, 4, {
						minwalktime = 3,
						randwalktime = 0,
						minwaittime = 2.5,
						randwaittime = 0,
					}),
				}, 0.5)),
		}, 0.5)
	else
		--friendly brain
		root = PriorityNode({
			ParallelNode{
				SequenceNode{
					ConditionWaitNode(function()
						return not self.inst.sg:HasStateTag("busy")
					end),
					ParallelNodeAny{
						ConditionWaitNode(
							function()
								return TheWorld.components.wagboss_tracker
									and TheWorld.components.wagboss_tracker:IsWagbossDefeated()
									or not TheWorld.Map:IsPointInWagPunkArenaAndBarrierIsUp(self.inst.Transform:GetWorldPosition())
								end),
						WaitNode(14),
					},
					ActionNode(function()
						self.inst:PushEvent("losecontrol")
					end),
				},
				Wander(self.inst, GetHome, 6, {
					minwalktime = 3,
					randwalktime = 0,
					minwaittime = 2.5,
					randwaittime = 0,
				}),
			},
		})
	end

	self.bt = BT(self.inst, root)
end

return WagbossRobotBrain
