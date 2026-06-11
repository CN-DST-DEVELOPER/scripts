require "behaviours/wander"
require "behaviours/chaseandattack"
require "behaviours/doaction"
local BrainCommon = require("brains/braincommon")

local MAX_WANDER_DIST = 20
local MAX_CHASE_TIME = 10
local MAX_CHASE_DIST = 30
local SEE_FOOD_DIST = 10

local FINDFOOD_CANT_TAGS = { "INLIMBO", "outofreach" }
local function IsFoodValid(item, inst)
    return inst.components.eater:CanEat(item)
        and item:IsOnPassablePoint()
end

local function FindFoodAction(inst)
	local target = FindEntity(inst, SEE_FOOD_DIST, IsFoodValid, nil, FINDFOOD_CANT_TAGS, inst.components.eater:GetEdibleTags())
    if target then
        return BufferedAction(inst, target, ACTIONS.EAT)
    end
end

local function TargetIsAggressive(inst)
    local target = inst.components.combat.target
    return target and
           target.components.combat and
           target.components.combat.defaultdamage > 0 and
           target.components.combat.target == inst
end

local WerePigBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function WerePigBrain:OnStart()
    --print(self.inst, "WerePigBrain:OnStart")
    local root = PriorityNode(
    {
		BrainCommon.PanicTrigger(self.inst),
        BrainCommon.ElectricFencePanicTrigger(self.inst),
        BrainCommon.IpecacsyrupPanicTrigger(self.inst),
        WhileNode(function() return not TargetIsAggressive(self.inst) end, "SafeToEat",
            DoAction(self.inst, function() return FindFoodAction(self.inst) end, "EatMeat", true)
        ),

        ChaseAndAttack(self.inst, SpringCombatMod(MAX_CHASE_TIME), SpringCombatMod(MAX_CHASE_DIST)),
        Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("home") end, MAX_WANDER_DIST),
    }, .5)

    self.bt = BT(self.inst, root)
end

function WerePigBrain:OnInitializationComplete()
    self.inst.components.knownlocations:RememberLocation("home", Point(self.inst.Transform:GetWorldPosition()), true)
end

return WerePigBrain
