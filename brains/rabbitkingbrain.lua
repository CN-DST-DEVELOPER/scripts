require("behaviours/wander")
require("behaviours/runaway")
require("behaviours/doaction")
require("behaviours/faceentity")
require("behaviours/leash")
local BrainCommon = require("brains/braincommon")

local STOP_RUN_DIST = 10
local SEE_PLAYER_DIST = 5

local AVOID_PLAYER_DIST = 3
local AVOID_PLAYER_STOP = 6

local SEE_BAIT_DIST = 20
local MAX_WANDER_DIST = 20
local FINDFOOD_CANT_TAGS = { "INLIMBO", "outofreach" }

local RabbitKingBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GoHomeAction(inst)
    if inst.components.homeseeker and
       inst.components.homeseeker.home and
       inst.components.homeseeker.home:IsValid() and
       inst.sg:HasStateTag("trapped") == false then
        return BufferedAction(inst, inst.components.homeseeker.home, ACTIONS.GOHOME)
    end
end

local function EatFoodAction(inst)
    local target = FindEntity(inst, SEE_BAIT_DIST, function(item, i)
            return i.components.eater:CanEat(item) and
                item.components.bait and
                not item:HasTag("planted") and
                item:IsOnPassablePoint() and
                item:GetCurrentPlatform() == i:GetCurrentPlatform()
		end,
		nil,
		FINDFOOD_CANT_TAGS)
    if target then
        local act = BufferedAction(inst, target, ACTIONS.EAT)
        act.validfn = function() return not (target.components.inventoryitem and target.components.inventoryitem:IsHeld()) end
        return act
    end
end

-----------------------------------------------------------------
-- PASSIVE
-----------------------------------------------------------------
local FACE_DIST = TUNING.RESEARCH_MACHINE_DIST
local function GetFaceTargetFn_Passive(inst)
    return FindClosestPlayerToInst(inst, FACE_DIST, true)
end
local function KeepFaceTargetFn_Passive(inst, target)
    return inst:IsNear(target, FACE_DIST)
end
function RabbitKingBrain:Create_Passive()
    -- Placated, does not give any care for running.
    -- Offers a selection of tradables.
    return PriorityNode({
        BrainCommon.PanicTrigger(self.inst),
        WhileNode(function() return self.inst.rabbitking_trading end, "Trading",
            FaceEntity(self.inst, GetFaceTargetFn_Passive, KeepFaceTargetFn_Passive)),

        DoAction(self.inst, EatFoodAction),
        Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("home") end, MAX_WANDER_DIST)
    }, .25)
end

-----------------------------------------------------------------
-- AGGRESSIVE
-----------------------------------------------------------------
local IDEAL_TARGET_DISTANCE = 8
local IDEAL_TARGET_DISTANCESQ = IDEAL_TARGET_DISTANCE * IDEAL_TARGET_DISTANCE
local function GetTargetPlayer(inst)
    return inst.components.combat.target
end
local function GetAvoidTargetPos_Aggressive(inst)
    local current_target = GetTargetPlayer(inst)
    if current_target then
        local px, py, pz = current_target.Transform:GetWorldPosition()
        local rx, ry, rz = inst.Transform:GetWorldPosition()
        local dx, dz = rx - px, rz - pz
        local distsq = dx * dx + dz * dz
        if distsq == 0 then
            dx = 1
            distsq = 1
        end
        local dist = math.sqrt(distsq)
        local targetpos = Vector3(px + dx * IDEAL_TARGET_DISTANCE / dist, 0, pz + dz * IDEAL_TARGET_DISTANCE / dist)
        return targetpos
    end

    return nil
end
local function GetTargetPos_Aggressive(inst)
    local current_target = GetTargetPlayer(inst)
    if current_target then
        return current_target:GetPosition()
    end

    return nil
end
local function GetFaceTargetFn_Aggressive(inst)
    return GetTargetPlayer(inst)
end
local function KeepFaceTargetFn_Aggressive(inst, target)
    return GetTargetPlayer(inst) == target
end

local DROPKICKDIST = TUNING.RABBITKING_ABILITY_DROPKICK_SPEED * TUNING.RABBITKING_ABILITY_DROPKICK_MAXAIRTIME
local DROPKICKDISTSQ = DROPKICKDIST * DROPKICKDIST
local SUMMONDISTSQ = 225 -- 15 * 15
local function ShouldUseAbility_Aggressive(self)
    if self.inst.components.health:IsDead() then
        return false
    end

    if self.inst.components.timer:TimerExists("ability_cd") then
        return false
    end

    local target = GetTargetPlayer(self.inst)
    if target == nil or not target:IsValid() then
        return false
    end

    local dsq = self.inst:GetDistanceSqToInst(target)

    if self.inst:CanSummonMinions() and dsq < SUMMONDISTSQ then
        self.abilityname = "ability_summon"
        return true
    end

    if self.inst:CanDropkick() and dsq < DROPKICKDISTSQ then
        self.abilityname = "ability_dropkick"
        self.abilitydata = target
        return true
    end

    return self.inst.sg:HasStateTag("ability")
end
function RabbitKingBrain:Create_Aggressive()
    -- Angry, chases after target leash but tries to maintain distance from other nearby players.
    -- Spawn big manrabbit allies.
    -- Direct big manrabbit allies.
    -- Dropkick target leash.
    return PriorityNode({
        BrainCommon.PanicTrigger(self.inst),
        WhileNode(function() return ShouldUseAbility_Aggressive(self) end, "Ability",
            ActionNode(function()
                if self.abilityname then
                    self.inst:PushEvent(self.abilityname, self.abilitydata)
                    self.abilityname = nil
                    self.abilitydata = nil
                end
            end)),
        -- Chase after target but maintain distance.
        FailIfSuccessDecorator(Leash(self.inst, GetAvoidTargetPos_Aggressive, 2, 0.5, true)),
        FailIfSuccessDecorator(Leash(self.inst, GetTargetPos_Aggressive, IDEAL_TARGET_DISTANCE + 2, IDEAL_TARGET_DISTANCE - 2, true)),
        FaceEntity(self.inst, GetFaceTargetFn_Aggressive, KeepFaceTargetFn_Aggressive),
        -- Idle where target is missing and the rabbit king is still around.
        Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("home") end, MAX_WANDER_DIST)
    }, .25)
end

-----------------------------------------------------------------
-- LUCKY
-----------------------------------------------------------------
local LUCKY_AVOID_PLAYER_DIST = 6
local LUCKY_AVOID_PLAYER_STOP = 9
local LUCKY_STOP_RUN_DIST = 13
local LUCKY_PLAYER_DIST = 8
function RabbitKingBrain:Create_Lucky()
    -- Super scared, run away from scary things more aggressively.
    -- Is large and slow.
    return PriorityNode({
        BrainCommon.PanicTrigger(self.inst),
        RunAway(self.inst, "scarytoprey", LUCKY_AVOID_PLAYER_DIST, LUCKY_AVOID_PLAYER_STOP),
        RunAway(self.inst, "scarytoprey", LUCKY_PLAYER_DIST, LUCKY_STOP_RUN_DIST, nil, true),
        EventNode(self.inst, "gohome",
            DoAction(self.inst, GoHomeAction, "go home", true )),
        WhileNode(function() return not TheWorld.state.isday end, "IsNight",
            DoAction(self.inst, GoHomeAction, "go home", true )),
        WhileNode(function() return TheWorld.state.isspring end, "IsSpring",
            DoAction(self.inst, GoHomeAction, "go home", true )),
        DoAction(self.inst, EatFoodAction),
        Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("home") end, MAX_WANDER_DIST)
    }, .25)
end

function RabbitKingBrain:OnStart()
    local rabbitking_kind = self.inst.rabbitking_kind
    local root
    if rabbitking_kind == "passive" then
        root = self:Create_Passive()
    elseif rabbitking_kind == "aggressive" then
        root = self:Create_Aggressive()
    elseif rabbitking_kind == "lucky" then
        root = self:Create_Lucky()
    end

    if root then
        self.bt = BT(self.inst, root)
    elseif BRANCH == "dev" then -- NOTES(JBK): This setup is done for mods to easily add more states if desired for our code we must ensure root exists.
        assert(false, "Missing rabbitking_kind type in rabbitkingbrain for what type it should be!")
    end
end

return RabbitKingBrain
