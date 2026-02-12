require "behaviours/standstill"
require "behaviours/doaction"
require "behaviours/follow"
require "behaviours/chaseandattack"
local BrainCommon = require("brains/braincommon")
local clockwork_common = require("prefabs/clockwork_common")

local START_FACE_DIST = 14
local KEEP_FACE_DIST = 16
local GO_HOME_DIST_SQ = 1
local MAX_CHASE_TIME = 60
local MAX_CHASE_DIST = 40
local RUN_AWAY_DIST = 5
local STOP_RUN_AWAY_DIST = 8

local BishopBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GoHomeAction(inst)
	if inst.components.combat:HasTarget() then
        return
    end
	local homePos = clockwork_common.GetHomePosition(inst)
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

local function GetLeader(inst)
	return inst.components.follower and inst.components.follower:GetLeader()
end

local function GetFaceLeaderFn(inst)
    return GetLeader(inst)
end

local function KeepFaceLeaderFn(inst, target)
    return GetLeader(inst) == target
end

local function ShouldGoHome(inst)
	local homePos = clockwork_common.GetHomePosition(inst)
	return homePos ~= nil and inst:GetDistanceSqToPoint(homePos) > GO_HOME_DIST_SQ
end

function BishopBrain:OnStart()
    local root = PriorityNode(
    {
		BrainCommon.PanicTrigger(self.inst),
        BrainCommon.ElectricFencePanicTrigger(self.inst),
		clockwork_common.WaitForTrader(self.inst),
		ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST, nil, nil, true), --true to walk instead of run
        WhileNode(function() return ShouldGoHome(self.inst) end, "ShouldGoHome",
			DoAction(self.inst, GoHomeAction, "Go Home", true)),
		Follow(self.inst, GetLeader, 5, 7, 12),
        IfNode(function() return GetLeader(self.inst) end, "has leader",
            FaceEntity(self.inst, GetFaceLeaderFn, KeepFaceLeaderFn )),
        FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
        StandStill(self.inst),
    }, .25)

    self.bt = BT(self.inst, root)
end

return BishopBrain
