require "behaviours/standstill"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/follow"
local BrainCommon = require("brains/braincommon")

local START_FACE_DIST = 6
local KEEP_FACE_DIST = 8
local GO_HOME_DIST = 1
local MAX_CHASE_TIME = 10
local MAX_CHASE_DIST = 20
local RUN_AWAY_DIST = 5
local STOP_RUN_AWAY_DIST = 8

local CHARGE_RANGE = 10

local CentipedeBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GoHomeAction(inst)
    if inst.components.combat.target ~= nil then
        return
    end
    local homePos = inst.components.knownlocations:GetLocation("home")
    return homePos ~= nil
        and BufferedAction(inst, nil, ACTIONS.WALKTO, nil, homePos, nil, .2)
        or nil
end

local function GetFaceTargetFn(inst)
    local target = FindClosestPlayerToInst(inst, START_FACE_DIST, true)
    return target ~= nil and not target:HasTag("notarget") and target or nil
end

local function KeepFaceTargetFn(inst, target)
    return not target:HasTag("notarget") and inst:IsNear(target, KEEP_FACE_DIST)
end

local function ShouldGoHome(inst)
    if inst.components.follower ~= nil and inst.components.follower.leader ~= nil then
        return false
    end
    local homePos = inst.components.knownlocations:GetLocation("home")
    return homePos ~= nil and inst:GetDistanceSqToPoint(homePos:Get()) > GO_HOME_DIST * GO_HOME_DIST
end

local function ShouldRoll(inst)
    if inst.components.combat and inst.components.combat.target then
        if inst:GetDistanceSqToInst(inst.components.combat.target) > CHARGE_RANGE * CHARGE_RANGE then
            inst:PushEvent("rollattack")
        end
    end
end

function CentipedeBrain:OnStart()
    local root = PriorityNode(
    {
        WhileNode(function() return not self.inst.sg:HasStateTag("charge") end, "no charging",
            PriorityNode({
				BrainCommon.PanicTrigger(self.inst),

                DoAction(self.inst, ShouldRoll, "Roll", true ),
                WhileNode(function()
                                return self.inst.components.combat.target == nil
                                    or not self.inst.components.combat:InCooldown()
                            end,
                            "AttackMomentarily",
                            ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST)),
                WhileNode(function() return self.inst.components.combat.target ~= nil and self.inst.components.combat:InCooldown() end, "Dodge",
                    RunAway(self.inst, function() return self.inst.components.combat.target end, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST)),
                WhileNode(function() return ShouldGoHome(self.inst) end, "ShouldGoHome",
                    DoAction(self.inst, GoHomeAction, "Go Home", true)),

                Follow(self.inst, function() return self.inst.components.follower ~= nil and self.inst.components.follower.leader or nil end,
                    5, 7, 12),

                FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
                StandStill(self.inst),
            }, .25)),
    }, .25)

    self.bt = BT(self.inst, root)
end

return CentipedeBrain
