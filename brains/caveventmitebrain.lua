require "behaviours/chaseandattack"
require "behaviours/runaway"
require "behaviours/wander"
require "behaviours/doaction"
require "behaviours/avoidlight"
require "behaviours/attackwall"
require "behaviours/useshield"

local BrainCommon = require "brains/braincommon"

local MAX_CHASE_TIME = TUNING.CAVE_MITE_MAX_CHASE_TIME
local SEE_FOOD_DIST = TUNING.CAVE_MITE_SEE_FOOD_DIST
local MAX_WANDER_DIST = TUNING.CAVE_MITE_MAX_WANDER_DIST
local DAMAGE_UNTIL_SHIELD = TUNING.CAVE_MITE_DAMAGE_UNTIL_SHIELD
local SHIELD_TIME = TUNING.CAVE_MITE_SHIELD_ATTACK_TIME

local AVOID_PROJECTILE_ATTACKS = false
local HIDE_WHEN_SCARED = true

local function ShouldShield(inst)
    if not inst.components.timer:TimerExists("shield_cooldown") and not inst.components.combat:HasTarget() then
        return true, TUNING.CAVE_MITE_SHIELD_TIME + TUNING.CAVE_MITE_SHIELD_TIME_VARIANCE * math.random()
    end
end

local use_shield_data =
{
    usecustomanims = true,
    checkstategraph = true,
    shouldshieldfn = ShouldShield,
}

local CaveVentMiteBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local EATFOOD_CANT_TAGS = { "INLIMBO", "outofreach" }
local function IsFoodValid(item, inst)
    return inst.components.eater:CanEat(item)
        and item:IsOnValidGround()
        and item:GetTimeAlive() > TUNING.SPIDER_EAT_DELAY
end

local function EatFoodAction(inst)
    if inst.sg:HasStateTag("busy") then
        return nil
    end

    local target = FindEntity(inst, SEE_FOOD_DIST, IsFoodValid, nil, EATFOOD_CANT_TAGS, inst.components.eater:GetEdibleTags())
    return target ~= nil and BufferedAction(inst, target, ACTIONS.EAT) or nil
end

------------------------------------------------------------------------------------------

local function GetHome(inst)
    return inst.components.knownlocations:GetLocation("home")
end

local UPDATE_RATE = 1
function CaveVentMiteBrain:OnStart()
    local root = PriorityNode({
        BrainCommon.PanicWhenScared(self.inst, .3),
		BrainCommon.PanicTrigger(self.inst),
        BrainCommon.ElectricFencePanicTrigger(self.inst),

        UseShield(self.inst, DAMAGE_UNTIL_SHIELD, SHIELD_TIME, AVOID_PROJECTILE_ATTACKS, HIDE_WHEN_SCARED, use_shield_data),

        ChaseAndAttack(self.inst, MAX_CHASE_TIME),

        DoAction(self.inst, EatFoodAction),
        --DoAction(self.inst, PlantFumarole),

        Wander(self.inst, GetHome, MAX_WANDER_DIST),

    }, UPDATE_RATE)

    self.bt = BT(self.inst, root)
end

function CaveVentMiteBrain:OnInitializationComplete()
    self.inst.components.knownlocations:RememberLocation("home", self.inst:GetPosition())
end

return CaveVentMiteBrain