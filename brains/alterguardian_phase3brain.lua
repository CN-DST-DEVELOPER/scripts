require "behaviours/doaction"
require "behaviours/standandattack"
require "behaviours/standstill"

local AlterGuardian_Phase3Brain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

-- If we get too far from the spawnpoint, walk straight back to it.
local function GoHomeAction(inst)
    local spawnpoint_position = inst.components.knownlocations:GetLocation("spawnpoint")
    if spawnpoint_position == nil or inst:GetDistanceSqToPoint(spawnpoint_position:Get()) < TUNING.ALTERGUARDIAN_PHASE3_GOHOMEDSQ then
		inst.sg.mem.isdodging = nil
        return nil
    else
		inst.sg.mem.isdodging = true
        return BufferedAction(inst, nil, ACTIONS.WALKTO, nil, spawnpoint_position)
    end
end

local START_FACE_DIST = TUNING.ALTERGUARDIAN_PHASE3_ATTACK_RANGE
local function GetFaceTargetFn(inst)
	inst.sg.mem.isdodging = nil
    local target = inst.components.combat.target or FindClosestPlayerToInst(inst, START_FACE_DIST, true)
    return target ~= nil and not target:HasTag("notarget") and target or nil
end

local KEEP_FACE_DIST = TUNING.ALTERGUARDIAN_PHASE3_ATTACK_RANGE + 3
local function KeepFaceTargetFn(inst, target)
    return not target:HasTag("notarget") and inst:IsNear(target, KEEP_FACE_DIST)
end

local function ShouldAttack(inst)
	inst.sg.mem.isdodging = nil
	return inst.components.combat.target
		and inst.components.combat:CanAttack(inst.components.combat.target)
		and not inst.components.combat:InCooldown()
end

local function ShouldDodge(inst)
	if not inst.components.timer:TimerExists("runaway_blocker") then
		inst.sg.mem.isdodging = true
		return true
	end
	inst.sg.mem.isdodging = nil
	return false
end

local PHASE3_HUNTERPARAMS =
{
    tags = { "_combat" },
    notags = { "INLIMBO", "playerghost" },
	oneoftags = { "character", "monster", "shadowminion" },
}

local ATTACK_TIMEOUT = 10
local AVOID_PLAYER_DIST = 3
local AVOID_PLAYER_STOP = 5
function AlterGuardian_Phase3Brain:OnStart()
    local root = PriorityNode({
		WhileNode(function() return ShouldAttack(self.inst) end, "DoAttack",
			StandAndAttack(self.inst, nil, 1)),
        DoAction(self.inst, GoHomeAction),
		WhileNode(function() return ShouldDodge(self.inst) end, "Run Away",
			RunAway(self.inst, PHASE3_HUNTERPARAMS, AVOID_PLAYER_DIST, AVOID_PLAYER_STOP)),
        FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
        StandStill(self.inst),
    }, .25)

    self.bt = BT(self.inst, root)
end

function AlterGuardian_Phase3Brain:OnInitializationComplete()
    self.inst.components.knownlocations:RememberLocation("spawnpoint", self.inst:GetPosition())
end

return AlterGuardian_Phase3Brain
