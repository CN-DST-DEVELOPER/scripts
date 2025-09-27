require "behaviours/follow"
require "behaviours/wander"
require "behaviours/faceentity"
require "behaviours/panic"
require "behaviours/leash"

local BrainCommon = require "brains/braincommon"
local WobyBrainCommon = require "brains/wobycommon"

local TARGET_FOLLOW_DIST = 4
local MAX_FOLLOW_DIST = 4.5

local COMBAT_TOO_CLOSE_DIST = 5                 -- distance for find enitities check
local COMBAT_TOO_CLOSE_DIST_SQ = COMBAT_TOO_CLOSE_DIST * COMBAT_TOO_CLOSE_DIST
local COMBAT_SAFE_TO_WATCH_FROM_DIST = 8        -- will run to this distance and watch if was too close
local COMBAT_SAFE_TO_WATCH_FROM_MAX_DIST = 12   -- combat is quite far away now, better catch up
local COMBAT_SAFE_TO_WATCH_FROM_MAX_DIST_SQ = COMBAT_SAFE_TO_WATCH_FROM_MAX_DIST * COMBAT_SAFE_TO_WATCH_FROM_MAX_DIST
local COMBAT_TIMEOUT = 6

local MAX_PLAYFUL_FIND_DIST = 4
local MAX_PLAYFUL_KEEP_DIST_FROM_OWNER = 6
local MAX_DOMINANTTRAIT_PLAYFUL_FIND_DIST = 6
local MAX_DOMINANTTRAIT_PLAYFUL_KEEP_DIST_FROM_OWNER = 9
local PLAYFUL_OFFSET = 2

local function GetOwner(inst)
    return inst.components.follower.leader
end

local function KeepFaceTargetFn(inst, target)
    return inst.components.follower.leader == target
end

local function OwnerIsClose(inst, distance)
    local owner = GetOwner(inst)

    return owner ~= nil and owner:IsNear(inst, distance or MAX_FOLLOW_DIST)
end

local function LoveOwner(inst)
    if inst.sg:HasStateTag("busy") then
        return nil
    end

    local owner = GetOwner(inst)
    return owner ~= nil
        and not owner:HasTag("playerghost")
        and (GetTime() - (inst.sg.mem.prevnuzzletime or 0) > TUNING.CRITTER_NUZZLE_DELAY)
        and math.random() < 0.05
        and BufferedAction(inst, owner, ACTIONS.NUZZLE)
        or nil
end

-------------------------------------------------------------------------------
--  Play With Other Critters
local PLAYMATE_NO_TAGS = {"busy"}
local function PlayWithPlaymate(self)
    self.inst:PushEvent("start_playwithplaymate", {target=self.playfultarget})
end

local function TargetCanPlay(self, target, owner, max_dist_from_owner, is_flier)
	return (target.IsPlayful == nil or target:IsPlayful()) 
			and target:IsNear(owner, max_dist_from_owner) 
			and (is_flier or target:IsOnPassablePoint())
			and (target.components.sleeper == nil or not target.components.sleeper:IsAsleep())
end

local function FindPlaymate(self)
    local owner = GetOwner(self.inst)

    local is_playful = self.inst.components.crittertraits:IsDominantTrait("playful")
    local max_dist_from_owner = is_playful and MAX_DOMINANTTRAIT_PLAYFUL_KEEP_DIST_FROM_OWNER or MAX_PLAYFUL_KEEP_DIST_FROM_OWNER
    local is_flier = self.inst:HasTag("flying")

    local can_play = self.inst:IsPlayful() and self.inst:IsNear(owner, max_dist_from_owner)

    -- Try to keep the current playmate
    if self.playfultarget ~= nil and self.playfultarget:IsValid() and can_play and TargetCanPlay(self, self.playfultarget, owner, max_dist_from_owner, is_flier) then
        return true
    end

    local find_dist = is_playful and MAX_DOMINANTTRAIT_PLAYFUL_FIND_DIST or MAX_PLAYFUL_FIND_DIST

    -- Find a new playmate
    self.playfultarget = can_play and
        not owner.components.locomotor:WantsToMoveForward() and
        FindEntity(self.inst, find_dist,
            function(v)
                return TargetCanPlay(self, v, owner, max_dist_from_owner, is_flier)
            end, nil, PLAYMATE_NO_TAGS, self.inst.playmatetags)
        or nil

    return self.playfultarget ~= nil
end

-------------------------------------------------------------------------------
--  Combat Avoidance

local function _avoidtargetfn(self, target)
    if target == nil or not target:IsValid() then
        return false
    end

    local owner = self.inst.components.follower.leader
    local owner_combat = owner ~= nil and owner.components.combat or nil
    local target_combat = target.components.combat
    if owner_combat == nil or target_combat == nil then
        return false
    elseif target_combat:TargetIs(owner)
        or (target.components.grouptargeter ~= nil and target.components.grouptargeter:IsTargeting(owner)) then
        return true
    end

    local distsq = owner:GetDistanceSqToInst(target)
    if distsq >= COMBAT_SAFE_TO_WATCH_FROM_MAX_DIST_SQ then
        -- Too far
        return false
    elseif distsq < COMBAT_TOO_CLOSE_DIST_SQ and target_combat:HasTarget() then
        -- Too close to any combat
        return true
    end

    -- Is owner in combat with target?
    -- Are owner and target both in any combat?
    local t = GetTime()
    return  (   (owner_combat:IsRecentTarget(target) or target_combat:HasTarget()) and
                math.max(owner_combat.laststartattacktime or 0, owner_combat.lastdoattacktime or 0) + COMBAT_TIMEOUT > t
            ) or
            (   owner_combat.lastattacker == target and
                owner_combat:GetLastAttackedTime() + COMBAT_TIMEOUT > t
            )
end

local function CombatAvoidanceFindEntityCheck(self)
    return function(ent)
            if _avoidtargetfn(self, ent) then
                self.inst:PushEvent("critter_avoidcombat", {avoid=true})
                self.runawayfrom = ent
                return true
            end
            return false
        end
end

local function ValidateCombatAvoidance(self)
    if self.runawayfrom == nil then
        return false
    end

    if not self.runawayfrom:IsValid() then
        self.inst:PushEvent("critter_avoidcombat", {avoid=false})
        self.runawayfrom = nil
        return false
    end

    if not self.inst:IsNear(self.runawayfrom, COMBAT_SAFE_TO_WATCH_FROM_MAX_DIST) then
        return false
    end

    if not _avoidtargetfn(self, self.runawayfrom) then
        self.inst:PushEvent("critter_avoidcombat", {avoid=false})
        self.runawayfrom = nil
        return false
    end

    return true
end

-------------------------------------------------------------------------------

--  Brain

local WobySmallBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function WobySmallBrain:OnStart()
    local main_nodes = PriorityNode{
        WobyBrainCommon.CourierNode(self.inst),
        WobyBrainCommon.SitStillNode(self.inst),
        WobyBrainCommon.WatchingMinigameNode(self.inst),

        -- Combat Avoidance
		WhileNode(function() return not WobyBrainCommon.IsWheelOpen(self.inst) end, "combat avoidance",
			PriorityNode({
				RunAway(self.inst, {tags={"_combat", "_health"}, notags={"wall", "INLIMBO"}, fn=CombatAvoidanceFindEntityCheck(self)}, COMBAT_TOO_CLOSE_DIST, COMBAT_SAFE_TO_WATCH_FROM_DIST),

				WhileNode(function() return ValidateCombatAvoidance(self) end, "Is Near Combat",
					PriorityNode({
						WobyBrainCommon.PickUpAmmoNode(self.inst),
						FaceEntity(self.inst, GetOwner, KeepFaceTargetFn)
					}, 0.25)),
			}, 0.25)),

		WhileNode(function() return WobyBrainCommon.IsWheelOpen(self.inst) and ValidateCombatAvoidance(self) end, "wheel open near combat",
			FaceEntity(self.inst, GetOwner, KeepFaceTargetFn)),

        FaceEntity(self.inst, WobyBrainCommon.GetWalterInteractionFn, WobyBrainCommon.KeepGenericInteractionFn),
		WhileNode(function() return WobyBrainCommon.IsWheelOpen(self.inst) end, "wheel open",
			FaceEntity(self.inst, GetOwner, KeepFaceTargetFn)),

		--When recalling Woby, temporarily block helper actions until she's fully returned to you.
		WobyBrainCommon.RecallNode(self.inst,
			Follow(self.inst, function() return self.inst.components.follower:GetLeader() end, 0, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST)),

        WobyBrainCommon.ForagerNode(self.inst),
        WobyBrainCommon.RetrieveAmmoNode(self.inst),
        WobyBrainCommon.FetchingActionNode(self.inst),

        WhileNode(function() return FindPlaymate(self) end, "Playful",
            SequenceNode{
                WaitNode(6),
                PriorityNode{
                    Leash(self.inst, function() return self.playfultarget:GetPosition() end, PLAYFUL_OFFSET, PLAYFUL_OFFSET),
                    ActionNode(function() PlayWithPlaymate(self) end),
                    StandStill(self.inst),
                },
            }),
        Follow(self.inst, function() return self.inst.components.follower.leader end, 0, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
        FailIfRunningDecorator(FaceEntity(self.inst, GetOwner, KeepFaceTargetFn)),
        WhileNode(function() return OwnerIsClose(self.inst) and self.inst:IsAffectionate() end, "Affection",
            SequenceNode{
                WaitNode(4),
                DoAction(self.inst, LoveOwner),
            }),
        StandStill(self.inst),
    }

    local root = PriorityNode({
        WhileNode(
            function()
                return not self.inst.sg:HasStateTag("jumping") and (self.inst.sg.currentstate == nil or self.inst.sg.currentstate.name ~= "transform")
            end,
            "<busy state guard>",
            PriorityNode({
                WhileNode(function() return GetOwner(self.inst) ~= nil end, "Has Owner", main_nodes),
                StandStill(self.inst),
            }, .25)
        ),
    }, .25)

    self.bt = BT(self.inst, root)
end

return WobySmallBrain
