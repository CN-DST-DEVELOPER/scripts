require("behaviours/chaseandattack")
require("behaviours/wander")
local BrainCommon = require("brains/braincommon")

local MAX_WANDER_DIST = 20
local MAX_CHASE_TIME = 30
local MAX_CHASE_DIST = 30

local WANDER_TIMES =
{
	minwalktime = 4,
	randwalktime = 1,
	minwaittime = 0,
	randwaittime = 0,
}

local function HasValidHome(inst)
    local home = inst.components.homeseeker ~= nil and inst.components.homeseeker.home or nil
    return home ~= nil
        and home:IsValid()
        and not (home.components.burnable ~= nil and home.components.burnable:IsBurning())
        and not home:HasTag("burnt")
end

local function GoHomeAction(inst)
    if HasValidHome(inst) and not inst.components.combat.target then
		return BufferedAction(inst, inst.components.homeseeker.home, ACTIONS.GOHOME)
    end
end

local FrankenPigBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

function FrankenPigBrain:OnStart()
	local root = PriorityNode({
		WhileNode(function() return not self.inst.sg:HasStateTag("jumping") end, "<busy state guard>",
			PriorityNode({
				WhileNode(
					function()
						local target = self.inst.components.combat.target
						if target == nil or self.inst.sg:HasStateTag("running") then
							return false
						end
						local t = self.inst.sg.statemem.hn_walk_t0
						return t == nil or t + 3 >= GetTime()
					end, "walking",
					ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST, nil, nil, true)),
				WhileNode(
					function() return not self.inst.components.combat:InCooldown() end, "running",
					ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST)),
                WhileNode( function() return TheWorld.state.isday end, "Cave nightness",
                    DoAction(self.inst, GoHomeAction, "go home", true )),
				Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("home") end, MAX_WANDER_DIST, WANDER_TIMES),
			}, 0.5)),
	}, 0.5)

	self.bt = BT(self.inst, root)
end

function FrankenPigBrain:OnInitializationComplete()
	self.inst.components.knownlocations:RememberLocation("home", self.inst:GetPosition(), true)
end

return FrankenPigBrain
