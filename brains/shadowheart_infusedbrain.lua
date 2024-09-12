require "behaviours/runaway"
require "behaviours/standstill"

local AVOID_PLAYER_DIST = 4.0
local AVOID_PLAYER_STOP = 6.0

local ShadowheartInfusedBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local UPDATE_RATE = 0.25
function ShadowheartInfusedBrain:OnStart()
    local root = PriorityNode({
        RunAway(self.inst, "player", AVOID_PLAYER_DIST, AVOID_PLAYER_STOP),
        StandStill(self.inst),
    }, UPDATE_RATE)

    self.bt = BT(self.inst, root)
end

return ShadowheartInfusedBrain