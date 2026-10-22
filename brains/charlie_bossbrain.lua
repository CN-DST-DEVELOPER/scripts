require("behaviours/chaseandattack")
require("behaviours/wander")

local CharlieBossBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

local function GetHome(inst)
	return inst.components.knownlocations:GetLocation("spawnpoint")
end

function CharlieBossBrain:OnStart()
	local root = PriorityNode({
		ChaseAndAttack(self.inst),
		Wander(self.inst, GetHome, 8),
	}, 0.25)

	self.bt = BT(self.inst, root)
end

function CharlieBossBrain:OnInitializationComplete()
	self.inst.components.knownlocations:RememberLocation("spawnpoint", self.inst:GetPosition(), true)
end

return CharlieBossBrain
