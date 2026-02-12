require "behaviours/standstill"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/chaseandram"
require "behaviours/faceentity"
require "behaviours/follow"
local BrainCommon = require("brains/braincommon")
local clockwork_common = require("prefabs/clockwork_common")

local START_FACE_DIST = 16
local KEEP_FACE_DIST = 18
local GO_HOME_DIST_SQ = 1 * 1
local MAX_CHASE_TIME = 5
local MAX_CHARGE_DIST = 25
local CHASE_GIVEUP_DIST = 10
local RUN_AWAY_DIST = 5
local STOP_RUN_AWAY_DIST = 8

local RookBrain = Class(Brain, function(self, inst)
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
	local homePos = clockwork_common.GetHomePosition(inst)
	if homePos and inst:GetDistanceSqToPoint(homePos) > GO_HOME_DIST_SQ then
        return nil
    end
    local target = FindClosestPlayerToInst(inst, START_FACE_DIST, true)
    return (target ~= nil and not target:HasTag("notarget") and target)
        or nil
end

local function KeepFaceTargetFn(inst, target)
	local homePos = clockwork_common.GetHomePosition(inst)
	return (homePos == nil or inst:GetDistanceSqToPoint(homePos) <= GO_HOME_DIST_SQ)
        and not target:HasTag("notarget")
        and inst:IsNear(target, KEEP_FACE_DIST)
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

local function GetRunAwayTarget(inst)
	return inst.components.combat.target
end

function RookBrain:OnStart()
    local root = PriorityNode(
    {
		BrainCommon.PanicTrigger(self.inst),
		BrainCommon.ElectricFencePanicTrigger(self.inst),
		clockwork_common.WaitForTrader(self.inst),
		WhileNode(function() return not self.inst.components.combat:HasTarget() or not self.inst.components.combat:InCooldown() end, "RamAttack",
            ChaseAndRam(self.inst, MAX_CHASE_TIME, CHASE_GIVEUP_DIST, MAX_CHARGE_DIST)),
        WhileNode(function()
				return self.inst.components.combat:HasTarget() and self.inst.components.combat:InCooldown()
					and not GetLeader(self.inst)
			end, "Dodge",
			RunAway(self.inst, { getfn = GetRunAwayTarget }, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST)),
        WhileNode(function() return ShouldGoHome(self.inst) end, "ShouldGoHome",
            DoAction(self.inst, GoHomeAction, "Go Home", false)),

        Follow(self.inst, GetLeader, 5, 7, 12, false),
        IfNode(function() return GetLeader(self.inst) end, "has leader",
            FaceEntity(self.inst, GetFaceLeaderFn, KeepFaceLeaderFn )),
        FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
        StandStill(self.inst)
    }, .25)

    self.bt = BT(self.inst, root)
end

return RookBrain
