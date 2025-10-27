local MutatedBirdBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local SHOULDFLYAWAY_CANT_TAGS = { "notarget", "INLIMBO", "lunar_aligned" }
local SHOULDFLYAWAY_ONEOF_TAGS = { "player", "monster", "scarytoprey" }

local SEE_FOOD_DIST = TUNING.RIFT_BIRD_FOOD_RANGE
local FOOD_CANT_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO", "outofreach" }

local SEE_HAIL_BUILDUP_DIST = TUNING.RIFT_BIRD_FOOD_RANGE
local LUNARHAIL_BUILDUP_MUST_TAGS = {"LunarBuildup"}

local function IsSgBusy(inst)
    return inst.sg:HasAnyStateTag("sleeping", "busy", "flight")
end

local DISLIKES_MOON_PHASES = {
    ["new"] = true,
    ["quarter"] = true,
}
local function ShouldFlyAway(inst)
    return not IsSgBusy(inst)
        and ((TheWorld.state.isnight and DISLIKES_MOON_PHASES[TheWorld.state.moonphase]) or
            (inst.components.health ~= nil and inst.components.health.takingfiredamage and not (inst.components.burnable and inst.components.burnable:IsBurning())))
end

local function ShouldFlyAwayFromThreat(inst)
    if not IsSgBusy(inst) then
        if inst.brain.threat == nil then
            inst.brain.threat = FindEntity(inst, inst.flyawaydistance, nil, nil, SHOULDFLYAWAY_CANT_TAGS, SHOULDFLYAWAY_ONEOF_TAGS)
        end

        return inst.brain.threat ~= nil
    end
end

local function FlyAway(inst)
    inst:PushEvent("flyaway")
end

local function IsFood(item, inst)
    return inst.components.eater:CanEat(item) and item:IsOnPassablePoint()
end

local function FindFoodAction(inst)
    local target = FindEntity(inst, SEE_FOOD_DIST, IsFood, nil, FOOD_CANT_TAGS, inst.components.eater:GetEdibleTags())
    if target then
       -- inst.bufferedaction = BufferedAction(inst, target, ACTIONS.EAT)
        return BufferedAction(inst, target, ACTIONS.EAT) --inst.bufferedaction
    end
end

local function FindAndMineLunarHailBuildup(inst)
    local target = FindEntity(inst, SEE_HAIL_BUILDUP_DIST, nil, LUNARHAIL_BUILDUP_MUST_TAGS, FOOD_CANT_TAGS)
    if target then
       -- inst.bufferedaction = BufferedAction(inst, target, ACTIONS.EAT)
        return BufferedAction(inst, target, ACTIONS.REMOVELUNARBUILDUP) --inst.bufferedaction
    end
end

function MutatedBirdBrain:OnStart()
    local function fly_away_fn()
        FlyAway(self.inst)
    end

    local function flee_threat_fn()
        -- dude, you pissed us off.
        local mutatedbirdmanager = TheWorld.components.mutatedbirdmanager
        if mutatedbirdmanager then
            mutatedbirdmanager:SetEnemyOfBirds(self.threat)
        end
        FlyAway(self.inst)
    end
    
    local root = PriorityNode(
    {
        WhileNode( function() return self.inst.components.hauntable ~= nil and self.inst.components.hauntable.panic end, "PanicHaunted",
			ActionNode(fly_away_fn)),
        IfNode(function() return ShouldFlyAway(self.inst) end, "Threat Near",
            ActionNode(fly_away_fn)),
        IfNode(function() return ShouldFlyAwayFromThreat(self.inst) end, "Living threat Near",
            ActionNode(flee_threat_fn)),
        EventNode(self.inst, "threatnear",
            ActionNode(fly_away_fn)),

        IfNode( function() return not IsSgBusy(self.inst) and self.inst:GetBufferedAction() == nil end, "NotFlying",
            DoAction(self.inst, FindFoodAction, "EatGlass")),
        IfNode( function() return not IsSgBusy(self.inst) and self.inst:GetBufferedAction() == nil  end, "NotFlying",
            DoAction(self.inst, FindAndMineLunarHailBuildup, "MineGlass")),

        EventNode(self.inst, "gohome",
            ActionNode(fly_away_fn)),
    }, .25)

    self.bt = BT(self.inst, root)
end

return MutatedBirdBrain