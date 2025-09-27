require "behaviours/follow"
require "behaviours/wander"
local BrainCommon = require("brains/braincommon")

local MIN_FOLLOW_DIST = 2
local TARGET_FOLLOW_DIST = 3
local MAX_FOLLOW_DIST = 8

local function GetLeader(inst)
    return inst.components.follower ~= nil and inst.components.follower.leader or nil
end

local function KeepFaceTargetFn(inst, target)
    return inst.components.follower ~= nil and inst.components.follower.leader == target
end

local MandrakeBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function MandrakeBrain:OnStart()
    local root = PriorityNode(
    {
		BrainCommon.PanicTrigger(self.inst),
        BrainCommon.ElectricFencePanicTrigger(self.inst),
        Follow(self.inst, GetLeader, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
        FaceEntity(self.inst, GetLeader, KeepFaceTargetFn),
        Wander(self.inst),
    }, .25)

    self.bt = BT(self.inst, root)
end

return MandrakeBrain
