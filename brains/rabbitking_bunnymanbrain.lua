require("behaviours/wander")
require("behaviours/follow")
require("behaviours/chaseandattack")
require("behaviours/runaway")
require("behaviours/panic")
require("behaviours/chattynode")

local BrainCommon = require("brains/braincommon")

local MIN_FOLLOW_DIST = 2
local TARGET_FOLLOW_DIST = 5
local MAX_FOLLOW_DIST = 9
local MAX_WANDER_DIST = 8

local MAX_CHASE_TIME = 10
local MAX_CHASE_DIST = 30

local function GetLeader(inst)
    return inst.components.follower.leader
end
local function GetLeaderPos(inst)
    local leader = GetLeader(inst)
    if leader then
        return leader:GetPosition()
    end

    return nil
end

local RabbitKing_BunnymanBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function RabbitKing_BunnymanBrain:OnStart()
    local root =
        PriorityNode(
        {
            BrainCommon.PanicWhenScared(self.inst, .25, "RABBIT_PANICBOSS"),
            WhileNode( function() return self.inst.components.hauntable and self.inst.components.hauntable.panic end, "PanicHaunted",
                ChattyNode(self.inst, "RABBIT_PANICHAUNT",
                    Panic(self.inst))),
            WhileNode(function() return self.inst.components.health.takingfiredamage end, "OnFire",
                ChattyNode(self.inst, "RABBIT_PANICFIRE",
                    Panic(self.inst))),
            ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST),
            Follow(self.inst, GetLeader, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
            ParallelNode{
                Wander(self.inst, GetLeaderPos, MAX_WANDER_DIST),
                LoopNode{
                    WaitNode(1),
                    ActionNode(function()
                        if GetLeader(self.inst) == nil then
                            self.inst:PushEvent("burrowaway")
                        end
                    end),
                }
            },
        }, .5)

    self.bt = BT(self.inst, root)
end

return RabbitKing_BunnymanBrain
