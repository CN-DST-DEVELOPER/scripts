require("behaviours/chaseandattack")
require("behaviours/wander")
local BrainCommon = require("brains/braincommon")

local WANDER_DIST = 4

local CharlieBossRunnerBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

local WANDER_TIMES =
{
    minwalktime = 4,
    randwalktime = 1,
    minwaittime = 0,
    randwaittime = 0,
}

local WANDER_DATA =
{
	wander_dist = WANDER_DIST,
	ignore_walls = true,
}

local function GetWanderDirection(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	local rot = inst.Transform:GetRotation()
	local theta = rot * DEGREES

	if TheWorld.Map:IsAboveGroundAtPoint(x + math.cos(theta) * WANDER_DIST, y, z - math.sin(theta) * WANDER_DIST) then
		theta = GetRandomWithVariance(theta, HALFPI / 45) -- 2 degrees variance
	else
		theta = GetRandomWithVariance(theta - PI, HALFPI / 8) -- 11.25 degrees variance
	end

	return ReduceAngleRad(theta)
end

function CharlieBossRunnerBrain:OnStart()
	local root = PriorityNode({
		WhileNode(
			function() return not self.inst.sg:HasStateTag("jumping") end, "<busy state guard>",
			PriorityNode({
				BrainCommon.RunAwayFromQueenTorch(self.inst),
				ChaseAndAttack(self.inst),
				Wander(self.inst, nil, nil, WANDER_TIMES, GetWanderDirection, nil, nil, WANDER_DATA),
			}, 0.25)
		)
	}, 0.25)

	self.bt = BT(self.inst, root)
end

return CharlieBossRunnerBrain
