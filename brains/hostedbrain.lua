require "behaviours/wander"
require "behaviours/faceentity"
require "behaviours/chaseandattack"
require "behaviours/doaction"
require "behaviours/leash"
require "behaviours/standstill"

local BrainCommon = require("brains/braincommon")

--------------------------------------------------------------------------------------------------------------------------------

local LEASH_RETURN_DIST = 2
local LEASH_MAX_DIST = 4

local MAX_WANDER_DIST = 3

local MAX_CHASE_TIME = 100
local MAX_CHASE_DIST = 30

local FORMATION_DIST_FROM_TARGET = 8
local FORMATION_SIMULTANEOUS_ATTACKS = 2

local HOSTED_MUST_TAGS = { "shadowthrall_parasite_hosted" }
local HOSTED_CANT_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO" }

--------------------------------------------------------------------------------------------------------------------------------

local FIND_PARASITES_DIST_SQ = 20*20

local PARASITES = {}

--------------------------------------------------------------------------------------------------------------------------------

local function ClearReservedTarget(inst)
    inst.reserved_target = nil
end

local function GetTarget(inst)
    return inst.components.combat.target
end

local function GetTargetPos(inst)
    local target = GetTarget(inst)

    if target ~= nil and target:IsValid() then
        return target:GetPosition()
    end
end

local function GetFormationPos(inst)
    local pos = GetTargetPos(inst)

    if pos ~= nil then
        local angle = inst.components.combat.target:GetAngleToPoint(inst.Transform:GetWorldPosition()) * DEGREES

        pos.x = pos.x + math.cos(angle) * FORMATION_DIST_FROM_TARGET
        pos.z = pos.z - math.sin(angle) * FORMATION_DIST_FROM_TARGET

        return pos
    end
end

local function CanAttackTarget(inst)
    if inst.components.combat.target == nil or inst.components.combat:InCooldown() then
        return false
    end

    if inst.reserved_target == inst.components.combat.target then
        return true
    end

    local targetcount = 0

    local p1x, p1y, p1z = inst.Transform:GetWorldPosition()

    for ent, _ in pairs(PARASITES) do -- Include us.
        local p2x, p2y, p2z = ent.Transform:GetWorldPosition()

        if distsq(p1x, p1z, p2x, p2z) < FIND_PARASITES_DIST_SQ and ent.reserved_target == inst.components.combat.target then
            targetcount = targetcount + 1

            if targetcount >= FORMATION_SIMULTANEOUS_ATTACKS then
                return false -- No need to keep going.
            end
        end
    end

    if targetcount < FORMATION_SIMULTANEOUS_ATTACKS and math.random() <= .7 then -- Randomize a bit who's going to attack.
        inst.reserved_target = inst.components.combat.target

        return true
    end

    return false
end

local function OnAttacked(inst, data)
    inst.components.combat:SuggestTarget(data.attacker)
    inst.components.combat:ShareTarget(data.attacker, 20, nil, 30, HOSTED_MUST_TAGS)
end

local function OnRemoved(inst)
    PARASITES[inst] = nil
end

local HostedBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function HostedBrain:OnStart()
    PARASITES[self.inst] = true

    self.inst:ListenForEvent("attacked", OnAttacked)
    self.inst:ListenForEvent("onremove", OnRemoved)

    local root =
        PriorityNode(
        {
            WhileNode(function() return CanAttackTarget(self.inst) end, "Target available?",
                ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST)
            ),

            Leash(self.inst, GetFormationPos, LEASH_MAX_DIST, LEASH_RETURN_DIST, true),
            DoAction(self.inst, ClearReservedTarget, "Clear target?"), -- Clear target after being back at formation.

            FaceEntity(self.inst, GetTarget, GetTarget),
            Wander(self.inst, nil, MAX_WANDER_DIST, { minwalktime = 1, randwalktime = 3, minwaittime = 3, randwaittime = 8 }),
            StandStill(self.inst),
        }, .5)

    self.bt = BT(self.inst, root)
end

function HostedBrain:OnStop()
    PARASITES[self.inst] = nil

    self.inst.reserved_target = nil

    self.inst:RemoveEventCallback("attacked", OnAttacked)
    self.inst:RemoveEventCallback("onremove", OnRemoved)
end

return HostedBrain
