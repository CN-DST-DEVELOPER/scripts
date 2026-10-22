local BrainCommon = require("brains/braincommon")
require("behaviours/chaseandattack")
require("behaviours/doaction")
require("behaviours/useshield")
require("behaviours/wander")

local WANDER_DIST = 16

local MAX_CHASE_TIME = 20
local MAX_CHASE_DIST = 20

local DAMAGE_UNTIL_SHIELD = 400
local AVOID_PROJECTILE_ATTACKS = false
local HIDE_WHEN_SCARED = false
local SHIELD_TIME = 5

-- We don't hide from quakes, we're big and strong!
local function ShouldShield(inst)
	if not (inst.components.timer:TimerExists("bouldercd") or inst.components.combat:HasTarget()) then
        return true, TUNING.ROCKY_SHIELD_TIME + TUNING.ROCKY_SHIELD_TIME_VARIANCE * math.random()
    end
end

local function ShouldEmergeFromShieldEnd(inst) -- this applies if we shielded for a custom time, not the default shield on attacked behaviour
    return inst.components.combat:HasTarget()
end

local use_shield_data =
{
    shouldshieldfn = ShouldShield,
    shouldemergefromshieldendfn = ShouldEmergeFromShieldEnd,
}

local function IsValidFood(item, inst)
	return item:GetTimeAlive() >= 8
		and item:IsOnValidGround()
		and inst.components.eater:CanEat(item)
end

local EATFOOD_CANT_TAGS = { "INLIMBO", "fire", "catchable", "outofreach" }
local function EatFoodAction(inst)
	if inst.sg:HasAnyStateTag("busy", "doing") then
		return
	end

	local target = FindEntity(inst, 15, IsValidFood, nil, EATFOOD_CANT_TAGS, inst.components.eater:GetEdibleTags())
	if target then
		local ba = BufferedAction(inst, target, ACTIONS.EAT)
		ba.distance = 1
		return ba
	end
end

local function GetWanderLocation(inst)
    return inst.components.knownlocations:GetLocation("herd")
end

local RockyBossBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

function RockyBossBrain:OnStart()
	local root = self.inst:HasTag("shadowthrall") and
		--rocky_boss_shadow brain
		PriorityNode({
			ParallelNodeAny{
				ChaseAndAttack(self.inst, SpringCombatMod(MAX_CHASE_TIME, true), SpringCombatMod(MAX_CHASE_DIST, true), nil, nil, true),
				ConditionWaitNode(function()
					if not (self.inst.components.combat:InCooldown() or self.inst.sg:HasStateTag("busy") or self.inst.components.timer:TimerExists("dashcd")) then
						local target = self.inst.components.combat.target
						if target and self.inst:IsNear(target, self.inst:GetDashRange() * TUNING.ROCKY_BOSS_SCALE + target:GetPhysicsRadius(0)) then
							self.inst:PushEvent("doattack", { target = target })
						end
					end
					return false --never finish
				end),
			},
			Wander(self.inst, GetWanderLocation, WANDER_DIST),
		}, 0.25) or
		--rocky_boss brain
		PriorityNode({
			EventNode(self.inst, "breakshield", ActionNode(function() end)),
			UseShield(self.inst, DAMAGE_UNTIL_SHIELD, SHIELD_TIME, AVOID_PROJECTILE_ATTACKS, HIDE_WHEN_SCARED, use_shield_data),
			BrainCommon.PanicTrigger(self.inst),
			ParallelNodeAny{
				ChaseAndAttack(self.inst, SpringCombatMod(MAX_CHASE_TIME), SpringCombatMod(MAX_CHASE_DIST), nil, nil, true),
				ConditionWaitNode(function()
					if not (self.inst.components.combat:InCooldown() or self.inst.sg:HasStateTag("busy") or self.inst.components.timer:TimerExists("dashcd")) then
						local target = self.inst.components.combat.target
						if target and self.inst:IsNear(target, self.inst:GetDashRange() * TUNING.ROCKY_BOSS_SCALE + target:GetPhysicsRadius(0)) then
							self.inst:PushEvent("doattack", { target = target })
						end
					end
					return false --never finish
				end),
			},
			DoAction(self.inst, EatFoodAction),
			Wander(self.inst, GetWanderLocation, WANDER_DIST),
		}, 0.25)

	self.bt = BT(self.inst, root)
end

return RockyBossBrain
