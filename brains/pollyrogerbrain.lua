require "behaviours/follow"
require "behaviours/wander"
require "behaviours/faceentity"
require "behaviours/panic"
require "behaviours/standstill"


local MIN_FOLLOW_DIST = 0
local MAX_FOLLOW_DIST = 8
local TARGET_FOLLOW_DIST = 6

local MAX_WANDER_DIST = 3

local STOP_RUN_DIST = 10
local SEE_MONSTER_DIST = 5
local AVOID_MONSTER_DIST = 3
local AVOID_MONSTER_STOP = 6

local MATCH_MIN_FOLLOW_DIST = 2
local MATCH_TARGET_FOLLOW_DIST = 2
local MATCH_MAX_FOLLOW_DIST = 7

local function PickUpAction(inst)
    if not inst.readytogather or inst.components.inventory:IsFull() then
        return nil
    end

    local leader = inst.components.follower and inst.components.follower.leader or nil
    if leader == nil or leader.components.trader == nil then -- Trader component is needed for ACTIONS.GIVEALLTOPLAYER
        return nil
    end

    if not leader:HasTag("player") then -- Stop Polly Rogers from trying to help non-players due to trader mechanics.
        return nil
    end

    local item = FindPickupableItem(leader, TUNING.POLLY_ROGERS_RANGE, true)
    if item == nil then
        return nil
    end

    return BufferedAction(inst, item, item.components.trap ~= nil and ACTIONS.CHECKTRAP or ACTIONS.PICKUP)
end

local function GiveAction(inst)
    local leader = inst.components.follower and inst.components.follower.leader or nil
    local leaderinv = leader and leader.components.inventory or nil
    local item = inst.components.inventory:GetFirstItemInAnySlot()
    if leader == nil or leaderinv == nil or item == nil then
        return nil
    end

    return leaderinv:CanAcceptCount(item, 1) > 0 and BufferedAction(inst, leader, ACTIONS.GIVEALLTOPLAYER, item) or nil
end

local function DropAction(inst)
    local leader = inst.components.follower and inst.components.follower.leader or nil
    local item = inst.components.inventory:GetFirstItemInAnySlot()
    if leader == nil or item == nil then
        return nil
    end

    local ba = BufferedAction(inst, leader, ACTIONS.DROP, item)
    ba.options.wholestack = true
    return ba
end

local function closetoleader(inst)
    if inst.sg:HasStateTag("busy") then
        return nil
    end
    local leader = inst.components.follower and inst.components.follower.leader or nil
    if leader and leader:GetDistanceSqToInst(inst) < TUNING.POLLY_ROGERS_RANGE * TUNING.POLLY_ROGERS_RANGE then
        return true
    end
end

local ShouldRunAway = {
    tags = { "hostile" },
    notags = { "NOCLICK", "invisible" }, -- NOTES(JBK): You can not fear what you can not see right Polly?
    fn = function(thing, polly)
        if thing.components.follower ~= nil then
            local leader = thing.components.follower:GetLeader()
            if leader and leader:HasTag("player") then -- TODO(JBK): PVP check.
                return false
            end
        end
        return true
    end,
}

local PollyRogerBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function PollyRogerBrain:OnStart()
    local root =
    PriorityNode(
    {
        WhileNode( function() return not self.inst.sg:HasStateTag("busy") end, "NO BRAIN WHEN BUSY",
            PriorityNode({
                WhileNode( function() return self.inst.components.hauntable and self.inst.components.hauntable.panic end, "PanicHaunted", Panic(self.inst)),
                WhileNode( function() return self.inst.components.health.takingfiredamage end, "OnFire", Panic(self.inst)),
                RunAway(self.inst, ShouldRunAway, AVOID_MONSTER_DIST, AVOID_MONSTER_STOP),
                RunAway(self.inst, ShouldRunAway, SEE_MONSTER_DIST, STOP_RUN_DIST), -- NOTES(JBK): Polly Rogers has an atypical home to go back to so do not use typical home run logic!
                WhileNode( function() return closetoleader(self.inst) end, "Stayclose",
                    PriorityNode({
                        DoAction(self.inst, PickUpAction, nil, true),
                        DoAction(self.inst, GiveAction, nil, true),
                        DoAction(self.inst, DropAction, nil, true),
                    },.25)),
                Follow(self.inst, function() return self.inst.components.follower and self.inst.components.follower.leader or nil end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
                StandStill(self.inst),
            }, .25)
        ),
    }, .25)
    self.bt = BT(self.inst, root)
end

return PollyRogerBrain