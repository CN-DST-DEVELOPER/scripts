require("behaviours/chaseandattack")
require("behaviours/chattynode")
require("behaviours/faceentity")
require("behaviours/leash")
require("behaviours/wander")

local FAR_TRADE_DIST_SQ = 20 * 20
local NEAR_TRADE_DIST_SQ = 4 * 4

local SharkboiBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

local function GetTarget(inst)
	return inst.components.combat.target
end

local function IsTarget(inst, target)
	return inst.components.combat:TargetIs(target)
end

local function GetTargetPos(inst)
	local target = GetTarget(inst)
	return target and target:GetPosition() or nil
end

local function GetNearbyPlayerFn(inst)
	local player, distsq = FindClosestPlayerToInst(inst, 6, true)
	return player
end

local function KeepNearbyPlayerFn(inst, target)
	return not (target.components.health and target.components.health:IsDead() or
				target:HasTag("playerghost"))
end

local function _GetTraderFn(inst, minrangesq, maxrangesq)
	if inst.components.trader then
		local x, y, z = inst.Transform:GetWorldPosition()
		for i, v in ipairs(AllPlayers) do
			if not (v.components.health:IsDead() or v:HasTag("playerghost")) and v.entity:IsVisible() then
				local distsq = v:GetDistanceSqToPoint(x, y, z)
				if distsq < maxrangesq and distsq >= minrangesq and inst.components.trader:IsTryingToTradeWithMe(v) then
					inst:SetIsTradingFlag(true, 0.5 + FRAMES)
					return v
				end
			end
		end
	end
end

local function GetFarTraderFn(inst)
	return _GetTraderFn(inst, NEAR_TRADE_DIST_SQ, FAR_TRADE_DIST_SQ)
end

local function GetNearTraderFn(inst)
	return _GetTraderFn(inst, 0, NEAR_TRADE_DIST_SQ)
end

local function GetTraderFn(inst)
	return _GetTraderFn(inst, 0, FAR_TRADE_DIST_SQ)
end

local function KeepTraderFn(inst, target)
	if inst.components.trader and inst.components.trader:IsTryingToTradeWithMe(target) then
		inst:SetIsTradingFlag(true, 0.5 + FRAMES)
		return true
	end
	inst:SetIsTradingFlag(false)
end

function SharkboiBrain:OnStart()
	local root = PriorityNode({
		WhileNode(
			function()
				return not self.inst.sg:HasAnyStateTag("jumping", "defeated", "sleeping")
			end,
			"<busy state guard>",
			PriorityNode({
				WhileNode(function() return self.inst.components.combat:InCooldown() end, "Chase",
					PriorityNode({
						FailIfSuccessDecorator(
							Leash(self.inst, GetTargetPos, TUNING.SHARKBOI_MELEE_RANGE, 3, true)),
						FaceEntity(self.inst, GetTarget, IsTarget),
					}, 0.5)),
				ChattyNode(self.inst, "SHARKBOI_TALK_FIGHT",
					ParallelNode{
						ConditionWaitNode(function()
							local target = self.inst.components.combat.target
							if target and not self.inst.components.combat:InCooldown() and
								self.inst:IsNear(target, TUNING.SHARKBOI_ATTACK_RANGE + target:GetPhysicsRadius(0))
							then
								self.inst.components.combat.ignorehitrange = true
								self.inst.components.combat:TryAttack(target)
								self.inst.components.combat.ignorehitrange = false
							end
							return false
						end),
						ChaseAndAttack(self.inst),
					}),
				--Sharkboi won the battle? (or all targets deaggroed?)
				IfNode(function() return self.inst:HasTag("hostile") end, "Gloating",
					ChattyNode(self.inst, "SHARKBOI_TALK_GLOAT",
						Wander(self.inst))),
				--Out of stock (after defeated)
				IfNode(function() return self.inst.components.trader and self.inst.stock <= 0 end, "Out of stock",
					PriorityNode({
						FaceEntity(self.inst, GetTraderFn, KeepTraderFn),
						Wander(self.inst),
					}, 0.5)),
				--Trader (after defeated)
				WhileNode(function() return self.inst.components.trader and self.inst.stock > 0 end, "Friendly",
					PriorityNode({
						ChattyNode(self.inst, "SHARKBOI_TALK_ATTEMPT_TRADE",
							FaceEntity(self.inst, GetFarTraderFn, KeepTraderFn)),
						FaceEntity(self.inst, GetNearTraderFn, KeepTraderFn),
						SequenceNode{
							ChattyNode(self.inst, "SHARKBOI_TALK_FRIENDLY",
								FaceEntity(self.inst, GetNearbyPlayerFn, KeepNearbyPlayerFn, 6)),
							ParallelNodeAny{
								Wander(self.inst),
								WaitNode(7),
							},
						},
						Wander(self.inst),
					}, 0.5)),
				--When first spawned; alternate between wandering and looking at you
				SequenceNode{
					ChattyNode(self.inst, "SHARKBOI_TALK_IDLE",
						FaceEntity(self.inst, GetNearbyPlayerFn, KeepNearbyPlayerFn, 4)),
					ParallelNodeAny{
						Wander(self.inst),
						WaitNode(10),
					},
				},
				Wander(self.inst),
			}, 0.5)),
	}, 0.5)

	self.bt = BT(self.inst, root)
end

return SharkboiBrain
