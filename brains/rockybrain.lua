require "behaviours/standstill"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/wander"
require "behaviours/chaseandattack"
require "behaviours/useshield"
local BrainCommon = require("brains/braincommon")

local START_FACE_DIST = 4
local KEEP_FACE_DIST = 6
local MAX_CHASE_TIME = 20
local MAX_CHASE_DIST = 16
local WANDER_DIST = 16

local MIN_FOLLOW_DIST = 4
local TARGET_FOLLOW_DIST = 6
local MAX_FOLLOW_DIST = 10

local MIN_FOLLOW_CONTENDER_DIST = 8
local TARGET_FOLLOW_CONTENDER_DIST = 12
local MAX_FOLLOW_CONTENDER_DIST = 16

local DAMAGE_UNTIL_SHIELD = 200
local AVOID_PROJECTILE_ATTACKS = true
local HIDE_WHEN_SCARED = true
local SHIELD_TIME = 5

local function GetLeader(inst)
    return inst.components.follower:GetLeader()
end

local function ShouldShield(inst)
    if TheWorld.net.components.quaker and TheWorld.net.components.quaker:IsQuaking() then
        return true, 15 + 5 * math.random()
    end
    if not inst.components.timer:TimerExists("bouldercd") and not inst.components.combat:HasTarget() and not GetLeader(inst) then
        return true, TUNING.ROCKY_SHIELD_TIME + TUNING.ROCKY_SHIELD_TIME_VARIANCE * math.random()
    end
end

local function ShouldEmerge(inst)
    if TheWorld.net.components.quaker and TheWorld.net.components.quaker:IsQuaking() then
        return false -- never emerge when quaking, not even for combat! too scary!
    end
    return nil -- to continue with remaining usual emerge checks
end

local function ShouldEmergeFromShieldEnd(inst) -- this applies if we shielded for a custom time, not the default shield on attacked behaviour
    return GetLeader(inst) ~= nil or inst.components.combat:HasTarget()
end

local use_shield_data =
{
    shouldshieldfn = ShouldShield,
    shouldemergefn = ShouldEmerge,
    shouldemergefromshieldendfn = ShouldEmergeFromShieldEnd,
}

local function GetFaceTargetFn(inst)
    local target = FindClosestPlayerToInst(inst, START_FACE_DIST, true)
    return (target ~= nil and not target:HasTag("notarget") and target)
        or nil
end

local function KeepFaceTargetFn(inst, target)
    return not target:HasTag("notarget") and inst:IsNear(target, KEEP_FACE_DIST)
end

local function GetFaceCombatTargetFn(inst)
	return inst.components.combat.target
end

local function KeepFaceCombatTargetFn(inst, target)
	return inst.components.combat:TargetIs(target)
end

local function CanPickup(item)
    return item.components.inventoryitem.canbepickedup
        and item:GetTimeAlive() >= 8
        and item:IsOnValidGround()
end

local EATFOOD_MUST_TAGS = { "edible_ELEMENTAL", "_inventoryitem" }
local EATFOOD_CANT_TAGS = { "INLIMBO", "fire", "catchable", "outofreach" }

local function EatFoodAction(inst)
    if inst.sg:HasStateTag("busy") then
        return
    elseif inst.components.inventory ~= nil and inst.components.eater ~= nil then
        inst._can_eat_food_test = inst._can_eat_food_test or function(item)
            return inst.components.eater:CanEat(item)
        end
        local target = inst.components.inventory:FindItem(inst._can_eat_food_test)
        if target then
            return BufferedAction(inst, target, ACTIONS.EAT)
        end
    end

	if inst.sg:HasStateTag("doing") then
		return
	end

    local target = FindEntity(inst, 15, CanPickup, EATFOOD_MUST_TAGS, EATFOOD_CANT_TAGS)
    if target then
        local ba = BufferedAction(inst, target, ACTIONS.PICKUP)
        ba.distance = 1.5
        return ba
    end
end

local LOSE_LOYALTY_CHANCE = 0.2
local function ScaredLoseLoyalty(self)
    local t = GetTime()
    if t >= self.scareendtime then
        self.scaredelay = nil
    elseif not self.scaredelay then
        self.scaredelay = t + 3
    elseif t >= self.scaredelay then
        self.scaredelay = t + 3
        local leader = self.inst.components.follower ~= nil and self.inst.components.follower:GetLeader() or nil
        if leader ~= nil and
            self.inst.components.follower:GetLoyaltyPercent() > 0 and
            TryLuckRoll(leader, LOSE_LOYALTY_CHANCE, LuckFormulas.LoseFollowerOnPanic) then
            self.inst.components.follower:SetLeader(nil)
            if self.inst.components.combat then
                self.inst.components.combat:SetTarget(nil)
            end
        end
    end
end

local function GetFollowContenderTarget(inst)
    return inst.components.combat.target
end

local function GetFollowTarget(inst)
    return GetLeader(inst)
end

local function GetWanderLocation(inst)
    return inst.components.knownlocations:GetLocation("herd")
end

local RockyBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function RockyBrain:OnStop()
    if self.onepicscarefn then
        self.inst:RemoveEventCallback("epicscare", self.onepicscarefn)
        self.onepicscarefn = nil
        self.scareendtime = nil
    end
end

function RockyBrain:OnStart()
    if not self.scareendtime then
        self.scareendtime = 0
        self.onepicscarefn = function(inst, data)
            self.scareendtime = math.max(self.scareendtime, data.duration + GetTime() + math.random())
        end
        self.inst:ListenForEvent("epicscare", self.onepicscarefn)
    end

    local root = PriorityNode(
    {
        ParallelNode{
            LoopNode{
                ActionNode(function() ScaredLoseLoyalty(self) end),
            },
			PriorityNode({
				EventNode(self.inst, "breakshield", ActionNode(function() end)),
				UseShield(self.inst, DAMAGE_UNTIL_SHIELD, SHIELD_TIME, AVOID_PROJECTILE_ATTACKS, HIDE_WHEN_SCARED, use_shield_data),
			}, 0.25),
        },
		BrainCommon.PanicTrigger(self.inst),

        WhileNode(function() return self.inst:IsTargetFightingBoss() end, "is rocky boss fighting target",
            PriorityNode({
                FailIfSuccessDecorator(Follow(self.inst, GetFollowContenderTarget, MIN_FOLLOW_CONTENDER_DIST, TARGET_FOLLOW_CONTENDER_DIST, MAX_FOLLOW_CONTENDER_DIST, false)),
                FaceEntity(self.inst, GetFaceCombatTargetFn, KeepFaceCombatTargetFn)
            }, .25)),

        ChaseAndAttack(self.inst, SpringCombatMod(MAX_CHASE_TIME), SpringCombatMod(MAX_CHASE_DIST), nil, nil, true),
        DoAction(self.inst, EatFoodAction),
        Follow(self.inst, GetFollowTarget, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST, false),
        FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
        Wander(self.inst, GetWanderLocation, WANDER_DIST),
    }, .25)

    self.bt = BT(self.inst, root)
end

return RockyBrain
