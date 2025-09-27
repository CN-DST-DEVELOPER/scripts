require "behaviours/wander"

local MAX_WANDER_DIST = 8

local WanderTimes = {
    minwalktime = 3,
    randwalktime = 1,
    minwaittime = 0.5,
    randwaittime = 1,
}

local MoonstormStaticBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function CheckPointFn(pt)
    local x, y, z = pt:Get()
    if not TheWorld.Map:IsLandTileAtPoint(x, y, z) then
        return false
    end

    local moonstorms = TheWorld.net and TheWorld.net.components.moonstorms or nil
    if not moonstorms then
        return true
    end

    return moonstorms:IsXZInMoonstorm(x, z)
end

function MoonstormStaticBrain:OnStart()
    local root = PriorityNode({
        Wander(self.inst, function() return self.inst:GetPosition() end, MAX_WANDER_DIST, WanderTimes, nil, nil, CheckPointFn),
    }, 1)

    self.bt = BT(self.inst, root)
end

return MoonstormStaticBrain
