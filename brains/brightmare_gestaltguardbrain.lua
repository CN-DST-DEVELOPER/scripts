require "behaviours/follow"
require "behaviours/wander"
require "behaviours/standstill"
require "behaviours/faceentity"

local BrainCommon = require("brains/braincommon")

local ATTACK_CHASE_TIME = 5

local WANDER_TIMES = { minwalktime = 2, randwalktime = 2, minwaittime = 3, randwaittime = 3 }

local RELOCATED_DISTSQ = 3*3

local GETFACINGTARGET_DISTSQ = TUNING.GESTALTGUARD_WATCHING_RANGE*TUNING.GESTALTGUARD_WATCHING_RANGE

local AVOID_STALKER_DIST = 10 -- keep in sync with gestalt_guard.lua::AVOID_STALKER_DIST
local AVOID_STALKER_STOP = 12
local STALKER_TAGS = {tags = {"stalker"}}

local GestaltGuardBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function IsPlayerTooClose(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    return IsAnyPlayerInRangeSq(x, y, z, RELOCATED_DISTSQ, true)
end

local function Relocate(inst)
	inst.sg:GoToState("relocate")
end

local function GetFacingTarget(inst)
	local target = inst.behaviour_level == 2 and inst.components.combat.target or nil
	if target ~= nil and target:IsValid() then
		local p1x, _, p1z = inst.Transform:GetWorldPosition()
		local p2x, _, p2z = target.Transform:GetWorldPosition()
		return (distsq(p1x, p1z, p2x, p2z) <= GETFACINGTARGET_DISTSQ) and target or nil
	end
end

local function KeepFacingTarget(inst, target)
	return GetFacingTarget(inst) == target
end

local function onrunaway(target, inst)
	inst.components.combat:DropTarget()
	return true
end

local UPDATE_RATE = 0.1
function GestaltGuardBrain:OnStart()
    local root = PriorityNode({
		WhileNode(function() return not self.inst.sg:HasStateTag("jumping") end, "",
			PriorityNode({
				RunAway(self.inst, STALKER_TAGS, AVOID_STALKER_DIST, AVOID_STALKER_STOP, onrunaway),

				WhileNode( function() return self.inst.behaviour_level == 3 end, "Aggressive",
					ChaseAndAttack(self.inst, ATTACK_CHASE_TIME, nil, nil, nil, true)
				),

				WhileNode( function() return IsPlayerTooClose(self.inst) end, "Relocate",
					SequenceNode{
						ActionNode(function() Relocate(self.inst) end),
						StandStill(self.inst),
					}
				),

				BrainCommon.PossessChassisNode(self, UPDATE_RATE),

				FaceEntity(self.inst, GetFacingTarget, KeepFacingTarget),
				Wander(self.inst, nil, nil, WANDER_TIMES),
			}, UPDATE_RATE)),
		}, UPDATE_RATE)

    self.bt = BT(self.inst, root)
end

function GestaltGuardBrain:OnInitializationComplete()
    self.inst.components.knownlocations:RememberLocation("spawnpoint", self.inst:GetPosition(), true)
end

return GestaltGuardBrain