local BirdBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local SHOULDFLYAWAY_MUST_TAGS = { "notarget", "INLIMBO" } -- NOTE: SHOULDFLYAWAY_MUST_TAGS is actually used as canttags in FindEntity. Not renaming for mod compatibility
local SHOULDFLYAWAY_CANT_TAGS = { "player", "monster", "scarytoprey" } -- NOTE: SHOULDFLYAWAY_CANT_TAGS is actually used as oneoftags in FindEntity. Not renaming for mod compatibility

local function ShouldFlyAway(inst)
    return
        not inst.sg:HasAnyStateTag("sleeping", "busy", "flight")
        and (TheWorld.state.isnight or TheWorld.state.islunarhailing or
            (inst.components.health ~= nil and inst.components.health.takingfiredamage and not (inst.components.burnable and inst.components.burnable:IsBurning())) or
            FindEntity(inst, inst.flyawaydistance, nil, nil, SHOULDFLYAWAY_MUST_TAGS, SHOULDFLYAWAY_CANT_TAGS) ~= nil)
end

local function FlyAway(inst)
    inst:PushEvent("flyaway")
end

function BirdBrain:OnStart()
    local ismutated = self.inst:HasTag("lunar_aligned")
    local fly_away_fn = function() return FlyAway(self.inst) end
    local root = PriorityNode(
    {
        WhileNode( function() return self.inst.components.hauntable ~= nil and self.inst.components.hauntable.panic end, "PanicHaunted",
			ActionNode(fly_away_fn)),
        IfNode(function() return ShouldFlyAway(self.inst) end, "Threat Near",
            ActionNode(fly_away_fn)),
        EventNode(self.inst, "threatnear",
            ActionNode(fly_away_fn)),
        EventNode(self.inst, "gohome",
            ActionNode(fly_away_fn)),
    }, .25)

    self.bt = BT(self.inst, root)
end

return BirdBrain
