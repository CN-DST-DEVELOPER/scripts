require "behaviours/follow"
require "behaviours/wander"
require "behaviours/standstill"
require "behaviours/faceentity"

local BRIGHTMARE_AVOID_DIST = 2
local BRIGHTMARE_AVOID_STOP = 4

local MAX_CHASE_TIME = 10
local MAX_CHASE_DIST = 20

local ATTACK_CHASE_TIME = 5

local WANDER_TIMES = { minwalktime = 2, randwalktime = 2, minwaittime = 3, randwaittime = 3 }

local RUN_AWAY_DIST = 4
local RUN_AWAY_DSQ = RUN_AWAY_DIST * RUN_AWAY_DIST
local STOP_RUN_AWAY_DIST = 8

local GETFACINGTARGET_DISTSQ = TUNING.GESTALTGUARD_WATCHING_RANGE*TUNING.GESTALTGUARD_WATCHING_RANGE

local GestaltGuardEvolvedBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GetFacingTarget(inst)
	local target = (inst.behaviour_level or 0) > 1 and inst.components.combat.target or nil
	if target ~= nil and target:IsValid() then
		local p1x, _, p1z = inst.Transform:GetWorldPosition()
		local p2x, _, p2z = target.Transform:GetWorldPosition()
		return (distsq(p1x, p1z, p2x, p2z) <= GETFACINGTARGET_DISTSQ) and target or nil
	end
end

local function KeepFacingTarget(inst, target)
	return GetFacingTarget(inst) == target
end

local AGMAXHAT_TAGS = {"_equippable", "lunarseedmaxed"}
local AGMAXHAT_RADIUS = 30
local function GetWanderHome(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	local ents = TheSim:FindEntities(x, y, z, AGMAXHAT_RADIUS, AGMAXHAT_TAGS)
	for _, e in ipairs(ents) do
		return e:GetPosition()
	end

	return inst.components.knownlocations:GetLocation("spawnpoint")
end

function GestaltGuardEvolvedBrain:OnStart()
	local function should_dodge()
		if not self.inst.components.combat:InCooldown() then
			return false
		end

		-- Relocate away from our combat target, but also players, because we're angry at them/scared of them.
		local ix, iy, iz = self.inst.Transform:GetWorldPosition()
		return (self.inst.components.combat.target
			and self.inst.components.combat.target:GetDistanceSqToPoint(ix, iy, iz) <= RUN_AWAY_DSQ)
			or IsAnyPlayerInRangeSq(ix, iy, iz, RUN_AWAY_DSQ, true)
	end

    local root = PriorityNode({
		WhileNode(function() return not self.inst.sg:HasStateTag("attack") end, "Not Attacking",
			PriorityNode({
				WhileNode( function() return not self.inst.components.combat:InCooldown() end, "Aggressive",
					ChaseAndAttack(self.inst, ATTACK_CHASE_TIME, nil, nil, nil, true)
				),

				WhileNode(should_dodge, "Relocate",
					SequenceNode{
						WaitNode(1.75),
						ActionNode(function() self.inst:PushEvent("relocate") end),
						StandStill(self.inst),
					}
				),

				FaceEntity(self.inst, GetFacingTarget, KeepFacingTarget),
				Wander(self.inst, GetWanderHome, 0.33 * AGMAXHAT_RADIUS, WANDER_TIMES),
			}, 0.1)),
		}, 0.1)

    self.bt = BT(self.inst, root)
end

function GestaltGuardEvolvedBrain:OnInitializationComplete()
    self.inst.components.knownlocations:RememberLocation("spawnpoint", self.inst:GetPosition(), true)
end

return GestaltGuardEvolvedBrain