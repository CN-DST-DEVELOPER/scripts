require "behaviours/follow"
require "behaviours/wander"

local GraveGuardBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

-------------------------------------------------------------------------------
--  Play With Other Ghosts
local PLAYFUL_OFFSET = 2

-- Abigail can initiate plays, but shouldn't be initiated with by NPCs.
local PLAYMATE_NO_TAGS = {"abigail", "busy"}
local PLAYMATE_ONEOF_TAGS = {"ghost"}
local function PlayWithPlaymate(self)
    self.inst:PushEvent("start_playwithghost", {target=self.playfultarget})
    self.playfultarget = nil
end

local function FindPlaymate(self)
    local home_location = self.inst.components.knownlocations:GetLocation("home")
    local max_dsq_from_owner = 64

    local can_play = (home_location ~= nil and self.inst:GetDistanceSqToPoint(home_location) < max_dsq_from_owner)
        or true

    -- Try to keep the current playmate
    if self.playfultarget ~= nil and self.playfultarget:IsValid() and can_play
            and (home_location == nil or self.playfultarget:GetDistanceSqToPoint(home_location) < max_dsq_from_owner) then
        return true
    end

    if self.inst.components.timer:TimerExists("played_recently") then
        return false
    end

    local find_dist = 6

    -- Find a new playmate
    self.playfultarget = can_play and
        FindEntity(self.inst, find_dist,
            function(v)
                return v:GetDistanceSqToPoint(home_location) < max_dsq_from_owner
            end, nil, PLAYMATE_NO_TAGS, PLAYMATE_ONEOF_TAGS)
        or nil

    return self.playfultarget ~= nil
end

--
local function IsAlive(target)
    return target.entity:IsVisible() and
        target.components.health ~= nil and
        not target.components.health:IsDead()
end

local TARGET_CANT_TAGS = { "INLIMBO", "noauradamage" }
local TARGET_ONEOF_TAGS = { "character", "hostile", "monster", "smallcreature" }
local function GetFollowTarget(ghost)
    local incoming_followtarget = ghost.brain.followtarget
    if incoming_followtarget ~= nil
        and (not incoming_followtarget:IsValid() or
            not incoming_followtarget.entity:IsVisible() or
            incoming_followtarget:IsInLimbo() or
            incoming_followtarget.components.health == nil or
            incoming_followtarget.components.health:IsDead() or
            ghost:GetDistanceSqToInst(incoming_followtarget) > TUNING.GHOST_FOLLOW_DSQ) then

        ghost.brain.followtarget = nil
    end

    if not ghost.brain.followtarget then
        local pvp_enabled = TheNet:GetPVPEnabled()
        local gx, gy, gz = ghost.Transform:GetWorldPosition()
        local potential_followtargets = TheSim:FindEntities(gx, gy, gz, 10, nil, TARGET_CANT_TAGS, TARGET_ONEOF_TAGS)
        for _, pft in ipairs(potential_followtargets) do
            -- We should only follow living characters.
            if IsAlive(pft) then
                if ghost:_target_test(pft, pvp_enabled) then
                    ghost.brain.followtarget = pft
                    break
                end
            end
        end
    end

    return ghost.brain.followtarget
end

function GraveGuardBrain:OnStart()
    local root = PriorityNode(
    {
        WhileNode(function() return GetFollowTarget(self.inst) ~= nil end, "FollowTarget",
            Follow(
                self.inst,
                function()
                    return self.inst.brain.followtarget
                end,
                TUNING.GHOST_RADIUS*.25,
                TUNING.GHOST_RADIUS*.5,
                TUNING.GHOST_RADIUS
            )
        ),
        IfNode(function() return self.inst._despawn_queued end, "Despawn If Asked",
            ActionNode(function() self.inst.sg:GoToState("dissipate") end)
        ),
        WhileNode(function() return FindPlaymate(self) end, "Playful",
            SequenceNode{
                WaitNode(6),
                PriorityNode{
                    Leash(self.inst, function() return self.inst:GetPositionAdjacentTo(self.playfultarget, 1) end, PLAYFUL_OFFSET, PLAYFUL_OFFSET),
                    ActionNode(function() PlayWithPlaymate(self) end),
                    StandStill(self.inst),
                },
            }
        ),
        SequenceNode{
			ParallelNodeAny{
				WaitNode(TUNING.TOTAL_DAY_TIME),
				Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("home") end, 7),
			},
            ActionNode(function() self.inst.sg:GoToState("dissipate") end),
        }
    }, 1)

    self.bt = BT(self.inst, root)
end

return GraveGuardBrain