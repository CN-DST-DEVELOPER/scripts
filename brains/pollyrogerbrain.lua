require "behaviours/follow"
require "behaviours/wander"
require "behaviours/faceentity"
require "behaviours/standstill"
require "behaviours/leash"

local BrainCommon = require("brains/braincommon")


local MIN_FOLLOW_DIST = 0
local MAX_FOLLOW_DIST = 8
local TARGET_FOLLOW_DIST = 6
local MAX_SALT_IDLE_DIST_SQ = 16 * 16
local WANDER_TIMING = {
    minwalktime = 0.25,
    randwalktime = 0.25,
    minwaittime = 1.5,
    randwaittime = 1.5,
}
local WANDER_DATA = {
    leashwhengoinghome = true,
}
local MAX_WANDER = 6

local STOP_RUN_DIST = 10
local SEE_MONSTER_DIST = 5
local AVOID_MONSTER_DIST = 3
local AVOID_MONSTER_STOP = 6


local function closetoleader(inst)
    if inst.sg:HasStateTag("busy") then
        return nil
    end
    local leader = inst.components.follower and inst.components.follower:GetLeader()
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

-- NOTES(JBK): A circle with 8 points is disitrubted around a circle and these lookups are to find close points from any given index on this circle.
local NearbyPoints = {}
for i = 0, 7 do
    NearbyPoints[i + 1] = (i / 8) * TWOPI
end
local NearbyPointsOffsets = {
    0,
    1, -1,
    2, -2,
    3, -3,
    4
}

local function FindNearbyOceanPos(inst)
    local leaderorself = inst.components.follower and inst.components.follower:GetLeader() or inst

    local x, y, z = leaderorself.Transform:GetWorldPosition()
    local x1, y1, z1 = inst.Transform:GetWorldPosition()
    local angle = math.atan2(z1 - z, x1 - x)
    local baseindex = math.floor((angle + EIGHTHPI) / QUARTERPI)
    for r = MAX_FOLLOW_DIST, 1, -2 do
        for i = 0, 7 do
            local offsetindex = NearbyPointsOffsets[i + 1]
            local index = (baseindex + offsetindex) % 8
            local theta = NearbyPoints[index + 1]
            local xoff, zoff = r * math.cos(theta), r * math.sin(theta)
            if TheWorld.Map:IsOceanAtPoint(x + xoff, 0, z + zoff, false) then
                return Vector3(x + xoff, 0, z + zoff)
            end
        end
    end

    return nil
end

local function IsWanderOcean(pt)
    return TheWorld.Map:IsOceanAtPoint(pt.x, pt.y, pt.z)
end


local PollyRogerBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function PollyRogerBrain:OnStart()
    local pickupparams = {
        cond = function()
            return self.inst.readytogather
        end,
        range = TUNING.POLLY_ROGERS_RANGE,
        furthestfirst = true,
    }

    local nearbyoceanpoint = nil

    local root =
    PriorityNode(
    {
        WhileNode( function() return not self.inst.sg:HasStateTag("busy") end, "NO BRAIN WHEN BUSY",
            PriorityNode({
				BrainCommon.PanicTrigger(self.inst),
                BrainCommon.ElectricFencePanicTrigger(self.inst),
                RunAway(self.inst, ShouldRunAway, AVOID_MONSTER_DIST, AVOID_MONSTER_STOP),
                RunAway(self.inst, ShouldRunAway, SEE_MONSTER_DIST, STOP_RUN_DIST), -- NOTES(JBK): Polly Rogers has an atypical home to go back to so do not use typical home run logic!
                IfNode(function()
                    if self.inst.prefab == "salty_dog" then
                        local x, y, z = self.inst.Transform:GetWorldPosition()
                        if TheWorld.Map:IsOceanAtPoint(x, y, z, false) then
                            return false
                        end
                        local counter = self.inst.components.counter
                        local count = counter and counter:GetCount("salty") or 0
                        return count >= TUNING.SALTY_DOG_MAX_SALT_COUNT
                    end
                end, "IsSaltedOnLand",
                    ActionNode(function() self.inst:PushEvent("saltshake") end)
                ),
                WhileNode( function() return closetoleader(self.inst) end, "Stayclose", BrainCommon.NodeAssistLeaderPickUps(self, pickupparams)),
                Follow(self.inst, function()
                    local leader = self.inst.components.follower and self.inst.components.follower:GetLeader()
                    if self.inst.prefab == "salty_dog" then
                        if nearbyoceanpoint and leader and leader:GetDistanceSqToPoint(nearbyoceanpoint:Get()) < MAX_SALT_IDLE_DIST_SQ then
                            return nil
                        end
                    end
                    return leader
                end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
                IfNode(function() return self.inst.prefab == "salty_dog" end, "IsSaltyDog",
                    Wander(self.inst, function(inst)
                        nearbyoceanpoint = FindNearbyOceanPos(inst)
                        return nearbyoceanpoint
                    end, MAX_WANDER, WANDER_TIMING, nil, nil, IsWanderOcean, WANDER_DATA)
                ),
                StandStill(self.inst),
            }, .25)
        ),
    }, .25)
    self.bt = BT(self.inst, root)
end

return PollyRogerBrain