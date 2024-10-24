require "behaviours/follow"
require "behaviours/wander"
require "behaviours/standstill"
require "behaviours/faceentity"

local ATTACH_DIST = 1
local CLOSE_DIST = 8

local SHADOW_RIFT_PORTAL_MUST_TAGS = { "shadowrift_portal" }

local RUN_AWAY_DIST = 15
local STOP_RUN_AWAY_DIST = 30

local function TestForRemove(inst)
    local x, y, z = inst.Transform:GetWorldPosition()

    if not IsAnyPlayerInRange(x, 0, z, PLAYER_CAMERA_SEE_DISTANCE) then
        inst:Remove()
    end
end

local function FindPlayer(inst)
    return FindClosestPlayerToInst(inst, PLAYER_CAMERA_SEE_DISTANCE, true)
end

local function FindRift(inst)
    local x, y, z = inst.Transform:GetWorldPosition()

    local rifts = TheSim:FindEntities(x, 0, z, PLAYER_CAMERA_SEE_DISTANCE, SHADOW_RIFT_PORTAL_MUST_TAGS)

    return rifts[1]
end

local ShadowThrall_Parasite_Brain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

-- if no players in range, remove. update some manager
-- if rift in range, move away from it.
-- if players in range move away.

function ShadowThrall_Parasite_Brain:OnStart()
    local root = PriorityNode(
    {
        DoAction(self.inst, TestForRemove, "Remove?", true),
        RunAway(self.inst, function() return FindPlayer(self.inst) end, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST),
        RunAway(self.inst, function() return FindRift(self.inst)   end, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST),
    }, .25)
    self.bt = BT(self.inst, root)
end

return ShadowThrall_Parasite_Brain