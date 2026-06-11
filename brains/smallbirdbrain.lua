require "behaviours/chaseandattack"
require "behaviours/wander"
require "behaviours/faceentity"
require "behaviours/follow"
require "behaviours/standstill"
local BrainCommon = require("brains/braincommon")

local MIN_FOLLOW_DIST = 2
local MAX_FOLLOW_DIST = 9
local TARGET_FOLLOW_DIST = (MAX_FOLLOW_DIST+MIN_FOLLOW_DIST)/2

local MAX_CHASE_TIME = 10

local TRADE_DIST = 20

local SEE_FOOD_DIST = 15
local FIND_FOOD_HUNGER_PERCENT = 0.75 -- if hunger below this, forage for nearby food

--local MAX_WANDER_DIST = 20
--local MAX_CHASE_DIST = 30

local START_RUN_DIST = 4
local STOP_RUN_DIST = 6

local function GetLeader(inst)
    return inst.components.follower and inst.components.follower:GetLeader()
end

local function IsHungry(inst)
    return inst.components.hunger and inst.components.hunger:GetPercent() < FIND_FOOD_HUNGER_PERCENT
end

local function IsStarving(inst)
    return inst.components.hunger and inst.components.hunger:IsStarving()
end

local function ShouldStandStill(inst)
    local leader = GetLeader(inst)
    return (inst.components.hunger and inst.components.hunger:IsStarving() and not inst:HasTag("teenbird")
    	and (not leader or not leader:HasTag("tallbird")))
end

local EATFOOD_CANT_TAGS = { "INLIMBO", "outofreach" }

local function CanSeeFood(inst)
	local target = FindEntity(inst, SEE_FOOD_DIST,
		function(item)
			return inst.components.eater:CanEat(item) and item:IsOnValidGround()
		end,
		nil,
		EATFOOD_CANT_TAGS)
    --[[if target then
        print("CanSeeFood", inst.name, target.name)
    end]]
    return target
end

local function FindFoodAction(inst)
    local target = CanSeeFood(inst)
    if target then
        return BufferedAction(inst, target, ACTIONS.EAT)
    end
end

local function GetTraderFn(inst)
    local leader = GetLeader(inst)
    return leader ~= nil
        and inst.components.trader:IsTryingToTradeWithMe(leader)
        and inst:HasTag("companion")
        and leader
        or nil
end

local function KeepTraderFn(inst, target)
    return inst.components.trader:IsTryingToTradeWithMe(target)
end

local function ShouldRunAwayFromPlayer(inst, player)
    return GetLeader(inst) == nil and not inst:HasTag("companion")
end

local SmallBirdBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function SmallBirdBrain:OnStart()
    local root =
    PriorityNode({
		BrainCommon.PanicTrigger(self.inst),
        BrainCommon.ElectricFencePanicTrigger(self.inst),
        FaceEntity(self.inst, GetTraderFn, KeepTraderFn),
        -- when starving prefer finding food over fighting
        SequenceNode{
            ConditionNode(function() return IsStarving(self.inst) and CanSeeFood(self.inst) end, "SeesFoodToEat"),
            ParallelNodeAny {
                WaitNode(math.random()*.5),
                PriorityNode {
                    StandStill(self.inst, ShouldStandStill),
                    Follow(self.inst, function() return GetLeader(self.inst) end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
                },
            },
            DoAction(self.inst, function() return FindFoodAction(self.inst) end),
        },
        SequenceNode{
            ConditionNode(function() return self.inst.components.combat.target ~= nil end, "HasTarget"),
            WaitNode(math.random()*.9),
            ChaseAndAttack(self.inst, SpringCombatMod(MAX_CHASE_TIME)),
        },
        RunAway(self.inst, "player", START_RUN_DIST, STOP_RUN_DIST, function(target) return ShouldRunAwayFromPlayer(self.inst, target) end ),
        SequenceNode{
            ConditionNode(function() return IsHungry(self.inst) and CanSeeFood(self.inst) end, "SeesFoodToEat"),
            ParallelNodeAny {
                WaitNode(1 + math.random()*2),
                PriorityNode {
                    StandStill(self.inst, ShouldStandStill),
                    Follow(self.inst, function() return GetLeader(self.inst) end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
                },
            },
            DoAction(self.inst, function() return FindFoodAction(self.inst) end),
        },
        PriorityNode {
            StandStill(self.inst, ShouldStandStill),
            Follow(self.inst, function() return GetLeader(self.inst) end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
        },
        Wander(self.inst, function()
            local leader = GetLeader(self.inst)
            if leader then
                return Vector3(leader.Transform:GetWorldPosition())
            end
        end, MAX_FOLLOW_DIST- 1, {minwalktime=.5, randwalktime=.5, minwaittime=6, randwaittime=3}),
    },.25)
    self.bt = BT(self.inst, root)
 end

return SmallBirdBrain