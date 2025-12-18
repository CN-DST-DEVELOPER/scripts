--[[

    Buzzards will only eat food laying on the ground already. They will not harvest food.

    Buzzard spawner looks for food nearby and spawns buzzards on top of it.
    Buzzard spawners also randomly spawn/ call back buzzards so they have a presence in the world.

    When buzzards have food on the ground they'll land on it and consume it, then hang around as a normal creature.
    If the buzzard notices food while wandering the world, it will hop towards the food and eat it.


    If attacked while eating, the buzzard will remain near it's food and defend it.
    If attacked while wandering the world, the buzzard will fly away.

--]]

--[[

    Mutated Buzzard behaviours

        No panicking (possessed by gestalt now)
--]]

require("stategraphs/commonstates")
require("behaviours/standandattack")
require("behaviours/wander")

local BuzzardBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local FLY_AWAY_AFTER_NO_CORPSE_TIME = 20

local SEE_FOOD_DIST = 15

local SEE_THREAT_DIST = 7.5
local MUTATED_SEE_THREAT_DIST = 3

local NO_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO", "outofreach" }
local FOOD_TAGS = {}
for i, v in ipairs(FOODGROUP.OMNI.types) do
    table.insert(FOOD_TAGS, "edible_"..v)
end

local FINDTHREAT_MUST_TAGS = { "notarget", "playerghost" } -- This is actually CANT_TAGS
local FINDTHREAT_CANT_TAGS = { "player", "monster", "scarytoprey" } -- This is actually ONE_OF_TAGS

local FINDTHREAT_MUTATED_CANT_TAGS = { "notarget", "lunar_aligned", "playerghost" } -- This really is CANT_TAGS!
local FINDTHREAT_MUTATED_ONE_OF_TAGS = { "player", "monster", "scarytoprey", } -- This really is ONE_OF_TAGS!

-- Regular buzzards care about protecting their food from other buzzards, but mutated, they are united!
local function Normal_IsValidThreat(guy, inst)
    return not guy:HasTag("buzzard") or inst:IsNear(guy, inst.components.combat:GetAttackRange() + guy:GetPhysicsRadius(0))
end

local function Mutated_IsValidThreat(guy)
    return guy.components.combat ~= nil -- Some things have scarytoprey but no combat component, so we get stuck.
end

local function FindThreat(inst, radius)
    local ismutated = inst:HasTag("lunar_aligned")
    if ismutated then
        return FindEntity(inst, radius, Mutated_IsValidThreat, nil, FINDTHREAT_MUTATED_CANT_TAGS, FINDTHREAT_MUTATED_ONE_OF_TAGS)
    else
        return FindEntity(inst, radius, Normal_IsValidThreat, nil, FINDTHREAT_MUST_TAGS, FINDTHREAT_CANT_TAGS)
    end
end

local function IsSgBusy(inst)
    return inst.sg:HasAnyStateTag("sleeping", "busy", "flight")
end

local function CanEat(food)
    return food:IsOnValidGround()
end

local function FindFood(inst, radius)
    -- Mutated buzzard isn't interested in actual food.
    if inst:HasTag("lunar_aligned") then
        return nil
    end
    --
    return FindEntity(inst, radius, CanEat, nil, NO_TAGS, FOOD_TAGS)
end

local function EatFoodAction(inst)  --Look for food to eat
    if inst.sg:HasStateTag("busy") then
        return
    end

    local food = FindFood(inst, SEE_FOOD_DIST)
    return food ~= nil and BufferedAction(inst, food, ACTIONS.EAT) or nil
end

local function GoHome(inst)
    return inst.shouldGoAway and BufferedAction(inst, nil, ACTIONS.GOHOME) or nil
end

local function ShouldFlyAwayFromFire(inst)
    if not IsSgBusy(inst)
        and (inst.components.health ~= nil and inst.components.health.takingfiredamage and not (inst.components.burnable and inst.components.burnable:IsBurning())) then
        inst.shouldGoAway = true
        return true
    end
end

local function Mutated_ShouldFlyAway(inst)
    if not IsSgBusy(inst)
        and not inst.brain.corpse
        and GetTime() - inst.brain.corpse_time > FLY_AWAY_AFTER_NO_CORPSE_TIME
        and not (inst.components.burnable and inst.components.burnable:IsBurning()) then
        inst.shouldGoAway = true
        return true
    end
end

local function GetHomePos(inst)
    return inst:GetPosition()
end

--------------------------------------------------------------------------

local ignorethese = { --[[ [corpse] = { [buzzard] = true ]] }

local SIZE_TO_NUM_OWNERS = { -- How many buzzards can eat this corpse?
    ["tiny"] = 1, -- e.g. rabbits
    ["small"] = 2, -- e.g. hounds
    ["med"] = 5, -- e.g. beefalo
    ["large"] = 10, -- e.g. bosses, like bearger or deerclops
}
-- Corpses can have multiple buzzards eating them depending on size
-- TODO buzzards shouldnt ignore a corpse even if its maxxed out, just encourage splitting up slightly, but if there's only one, go for it!
function BuzzardBrain:OwnCorpse(corpse)
    self:LoseCorpseOwnership()

    self.corpse = corpse

    if not ignorethese[corpse] then
        ignorethese[corpse] = {}
    end
    ignorethese[corpse][self.inst] = true

    self._on_corpse_ignite = self._on_corpse_ignite or function(ent, data)
        -- doer could actually be source, yuck!
        local doer = data ~= nil and (data.doer or data.source) or nil
        if doer and self.inst.components.combat:CanTarget(doer) then
            self.inst.components.combat:SuggestTarget(doer)
        end
    end

    local ismutated = self.inst:HasTag("lunar_aligned")
    self._on_corpse_chomped = self._on_corpse_chomped or function(ent, data)
        local eater = data ~= nil and data.eater or nil
        if eater and self.inst.components.combat:CanTarget(eater) then
            -- If we're mutated, and the eater isn't a fellow mutant, we're getting ya!
            -- If we're not mutated, we don't like sharing at all!
            if (ismutated and not eater:HasTag("gestaltmutant")) or not ismutated then
                self.inst.components.combat:SetTarget(eater)
            end
        end
    end

    self.inst:ListenForEvent("onignite", self._on_corpse_ignite, self.corpse)
    self.inst:ListenForEvent("chomped", self._on_corpse_chomped, self.corpse)
end

function BuzzardBrain:LoseCorpseOwnership()
    if self.corpse then
        ignorethese[self.corpse][self.inst] = nil
        if GetTableSize(ignorethese[self.corpse]) == 0 then
            ignorethese[self.corpse] = nil
        end

        self.inst:RemoveEventCallback("onignite", self._on_corpse_ignite, self.corpse)
        self.inst:RemoveEventCallback("chomped", self._on_corpse_chomped, self.corpse)
        self.corpse = nil

        self.corpse_time = GetTime()
    end
end

function BuzzardBrain:ShouldIgnoreCorpse(corpse)
    local owners = ignorethese[corpse]
    if not owners then
        return false
    end

    -- Enough space in the list for us.
    local _, sz, _ = GetCombatFxSize(corpse)
    if GetTableSize(owners) < SIZE_TO_NUM_OWNERS[sz] then
        return false
    end

    -- No more space, check if we're one of the owners
    for buzzard in pairs(owners) do
        if buzzard == self.inst then
            return false
        end
    end

    -- Don't eat this corpse.
    return true
end

-- For non-brain logic to use in manager component
function Buzzard_ShouldIgnoreCorpse(corpse)
    local owners = ignorethese[corpse]
    if not owners then
        return false
    end

    -- Enough space in the list for us.
    local _, sz, _ = GetCombatFxSize(corpse)
    if GetTableSize(owners) < SIZE_TO_NUM_OWNERS[sz] then
        return false
    end

    -- Don't eat this corpse.
    return true
end

------------

local function IsNotBurning(inst)
    return inst.components.burnable == nil or not inst.components.burnable:IsBurning()
end

local CORPSE_MUST_TAGS = { "creaturecorpse" }
local CORPSE_NO_TAGS = { "NOCLICK" }
local function IsCorpseValid(guy, inst)
    local ismutated = inst:HasTag("lunar_aligned")
    return guy ~= nil
        and guy:IsValid()
        and (ismutated or IsNotBurning(guy))
        and not guy:IsMutating()
        and (not ismutated or not guy:HasGestaltArriving())
        and not inst.brain:ShouldIgnoreCorpse(guy)
        and guy:HasTag("creaturecorpse") -- for non-entity scans
end

function BuzzardBrain:FindCorpse()
	local corpse = FindEntity(self.inst, SEE_FOOD_DIST, IsCorpseValid, CORPSE_MUST_TAGS, CORPSE_NO_TAGS)
    if corpse ~= nil then
        self:OwnCorpse(corpse)
        return true
    else
        self:LoseCorpseOwnership()
    end
end

function BuzzardBrain:IsCorpseValid()
	return IsCorpseValid(self.corpse, self.inst)
end

function BuzzardBrain:GetCorpsePosition()
	return self:IsCorpseValid() and self.corpse:GetPosition() or nil
end

--------------------------------------------------------------------------

-- Mutated buzzards are a bit more confident and detect a threat at a shorter distance
local function GetSeeThreatDist(inst)
    return inst:HasTag("lunar_aligned") and MUTATED_SEE_THREAT_DIST
        or SEE_THREAT_DIST
end

function BuzzardBrain:FindThreat()
    if self.threat == nil then -- nil means we tried finding a threat and there's none
        return nil
    elseif self.threat ~= false then -- false means we haven't tried a cache yet
        return self.threat
    end

    self.threat = FindThreat(self.inst, GetSeeThreatDist(self.inst)) or nil
    return self.threat
end

function BuzzardBrain:IsThreatened()
    return not IsSgBusy(self.inst) and self:FindThreat() or nil
end

function BuzzardBrain:DealWithThreat()
    --If you have some food then defend it! Otherwise... cheese it!
    local ismutated = self.inst:HasTag("lunar_aligned")

    if FindFood(self.inst, 1.5) ~= nil or (ismutated and self:FindCorpse()) then
        local threat = self:FindThreat()
        if threat ~= nil then
            if not threat:IsOnValidGround() then
                -- If our threat is out on the ocean, or otherwise somewhere we can't reach,
                -- we should just go away. Sorry, "cheese it".
                self.inst.shouldGoAway = true
            elseif not self.inst.components.combat:TargetIs(threat) then
                -- For mutated we suggest the target, to see if there's already other buzzards on it or not
                if ismutated then
                    if self.inst.components.combat:SuggestTarget(threat) then
                        self.inst.components.locomotor:Stop()
                        self.inst:ClearBufferedAction()
                    else
                        return false -- To the next node
                    end
                else
                    self.inst.components.locomotor:Stop()
                    self.inst:ClearBufferedAction()
                    self.inst.components.combat:SetTarget(threat)
                end
            end
        end
    else
        self.inst.shouldGoAway = true
    end

    return true
end

function BuzzardBrain:DoUpdate()
    -- Reset our caches.
    self.threat = false
end

--------------------------------------------------------------------------

-- Some creatures physics radii are obscenely small (see Deerclops) so calculate combat fx size and get the larger of the two.
local function GetCorpseRadius(corpse)
    local r, sz, ht = GetCombatFxSize(corpse)
    return math.max(r, corpse:GetPhysicsRadius(0))
end

local UPDATE_RATE = .5
function BuzzardBrain:OnStart()
    local ismutated = self.inst:HasTag("lunar_aligned")

    self.corpse_time = GetTime()

    local root = PriorityNode(
    {
        WhileNode(function() return not self.inst.sg:HasAnyStateTag("flight", "flamethrowering") end, "Not Flying or Flamethrowering",
        PriorityNode({
            IfNode(function() return not ismutated end, "NormalPanic",
                WhileNode(function() return ShouldFlyAwayFromFire(self.inst) end, "Go Away From Fire",
                    DoAction(self.inst, GoHome))),

            IfNode(function() return ismutated end, "NoMoreCorpses",
                WhileNode(function() return Mutated_ShouldFlyAway(self.inst) end, "Fly away",
                    DoAction(self.inst, GoHome))),

            WhileNode(function() return self.inst.shouldGoAway end, "Go Away",
                DoAction(self.inst, GoHome)),

            StandAndAttack(self.inst, nil, nil, true),

            IfNode(function() return self:IsThreatened() end, "Threat Near",
                ConditionNode(function() return self:DealWithThreat() end)),

            -- Eating a corpse, for mutated buzzards only (for now?)
			WhileNode(
				function()
					return ismutated and
                        not IsSgBusy(self.inst) and (
						not self.inst.components.combat:HasTarget() or
						self.inst.components.combat:GetLastAttackedTime() + TUNING.MUTATEDBUZZARD_FIND_CORPSE_DELAY < GetTime()
					)
				end,
				"WeCanEatACorpse!",
				IfNode(function() return self:FindCorpse() end, "Eat Corpse",
					PriorityNode({
						FailIfSuccessDecorator(
							Leash(self.inst,
								function() return self:GetCorpsePosition() end,
								function() return self.inst.components.combat:GetHitRange() + GetCorpseRadius(self.corpse) - 1 end,
								function() return self.inst.components.combat:GetHitRange() + GetCorpseRadius(self.corpse) - 1.5 end,
								true)),
						IfNode(function() return self:IsCorpseValid() and not self.inst.components.combat:InCooldown() end, "chomp",
							ActionNode(function()
                                self.inst:FacePoint(self.corpse.Transform:GetWorldPosition()) -- In case the corpse was right on top of us and so we couldn't get to FaceEntity node first.
                                self.inst:PushEventImmediate("corpse_eat", { corpse = self.corpse })
                            end)),
						FaceEntity(self.inst,
							function() return self.corpse end,
							function() return self:IsCorpseValid() end),
					}, .25))),
			--

            DoAction(self.inst, EatFoodAction),
            Wander(self.inst, GetHomePos, 5)
        }, UPDATE_RATE))
    }, UPDATE_RATE)

    self.bt = BT(self.inst, root)
end

function BuzzardBrain:OnStop()
	self:LoseCorpseOwnership()
end

return BuzzardBrain
