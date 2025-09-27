require("behaviours/wander")

--Scared of lunar stuff?

local TIMER_NAMES = {
    NOT_HUNGRY = "not_hungry",
}

local WANDER_DIST = TUNING.SHADOWTHRALL_CENTIPEDE.WANDER_DIST
local FIND_MIASMA_DIST = TUNING.SHADOWTHRALL_CENTIPEDE.FIND_MIASMA_DIST
local EAT_MIASMA_MAX = TUNING.SHADOWTHRALL_CENTIPEDE.EAT_MIASMA_MAX

local ANGLE_INTERACT_WIDTH = TUNING.SHADOWTHRALL_CENTIPEDE.ANGLE_INTERACT_WIDTH

local FINDMIASMA_CANT_TAGS = { "INLIMBO", "DECOR", "outofreach" } --Don't include "FX" the miasma clouds have FX tag.

local WANDER_TIMES = {
    minwalktime = 10,
    randwalktime = 10,
    minwaittime = 0,
    randwaittime = 0,
}

local WANDER_DATA = {
    ignore_walls = true,
    --wander_dist = 30,
    --should_run = true,
}

local ShadowThrallCentipedeBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

local function CanInteractPosWithinAngle(inst, pos)
    local rotation = inst.Transform:GetRotation()
    if rotation ~= inst.cached_rotation then
        inst.cached_rotation = rotation
        inst.cached_forwardvector = Vector3(math.cos(-rotation / RADIANS), 0, math.sin(-rotation / RADIANS))
    end
    --
    return IsWithinAngle(inst:GetPosition(), inst.cached_forwardvector, ANGLE_INTERACT_WIDTH, pos)
end

local function GetHome(inst)
    inst.control_priority = inst.PRIORITY_BEHAVIOURS.WANDERING --TODO
	return inst:GetPosition() --inst.components.knownlocations:GetLocation("spawnpoint")
end

local function TestForMiasma(item, inst)
    return item:GetTimeAlive() >= 1
        and inst.components.eater:CanEat(item)
        and CanInteractPosWithinAngle(inst, item:GetPosition())
end

local function FindValidMiasma(inst)
    if inst.sg:HasStateTag("busy") then
        return nil
    end

    return FindEntity(inst, FIND_MIASMA_DIST, TestForMiasma, nil, FINDMIASMA_CANT_TAGS, inst.components.eater:GetEdibleTags())
end

local function DoFindAndEatMiasmaAction(inst)
    local target = FindValidMiasma(inst)
    if not target then
        return nil
    end

    local buffered_action = BufferedAction(inst, target, ACTIONS.EAT)
    --
    buffered_action:AddSuccessAction(function()
        inst.miasma_counter = inst.miasma_counter + 1
        if inst.miasma_counter >= EAT_MIASMA_MAX then
            inst.controller.components.centipedebody:GrowNewSegment()
            inst.components.timer:StartTimer(TIMER_NAMES.NOT_HUNGRY, TUNING.SHADOWTHRALL_CENTIPEDE.EAT_DELAY)
            inst.miasma_counter = 0
        end
    end)
    --
    inst.control_priority = inst.PRIORITY_BEHAVIOURS.EATING
    return buffered_action
end

local function GetWanderDirection(inst)
    return (inst.Transform:GetRotation() + math.random(-90, 90)) * DEGREES
end

local SEGMENT_TAGS = {"shadowthrall_centipede"}
local function TestWanderPoint(pt)
    local x, y, z = pt:Get()
    local segment_count = TheSim:CountEntities(x, y, z, 2, SEGMENT_TAGS)
    return segment_count == 0 and not TheWorld.Map:IsPointNearHole(pt) and TheWorld.Map:IsSurroundedByLand(x, y, z, 0) -- Adds 1 automatically for overhang
end

-- Request control nodes

local function TakeControlToEat(inst)
    local target = FindValidMiasma(inst)
    if not target then
        return false
    end

    inst.control_priority = inst.PRIORITY_BEHAVIOURS.EATING
    return true
end

local function TakeControlToWander(inst)
    inst.control_priority = inst.PRIORITY_BEHAVIOURS.WANDERING
    return true
end

local UPDATE_RATE = 0.5
function ShadowThrallCentipedeBrain:OnStart()
	--local centipedebody = self.inst.controller.components.centipedebody
    local function WantsToEat() return not self.inst.components.timer:TimerExists(TIMER_NAMES.NOT_HUNGRY) end
    local function HasControl() return self.inst.controller and self.inst.controller.components.centipedebody:SegmentHasControl(self.inst) end
    local function IsNotBusy() return not self.inst.sg:HasStateTag("struggling") end

	local request_control_nodes = WhileNode(
		function()
			return not HasControl()
		end,
        "<is requesting control state guard>",
        PriorityNode({
		    -- Higher priority nodes are prioritized
		    -- E.g. eat node is higher, so if one head wants to wander, but another head wants to eat. eating head is given control.

            ConditionNode(function() return WantsToEat() and TakeControlToEat(self.inst) end, "Requesting to eat"),
            ConditionNode(function() return TakeControlToWander(self.inst) end, "Requesting to wander"),
        }, UPDATE_RATE)
    )

	local behaviour_nodes = WhileNode(
		function()
			return HasControl()
		end,
		"<is in control state guard>",
		PriorityNode({
            --RunAway(self.inst, runaway_from_lunar, 6, 10)
            --RunAway(self.inst, function() return last_segment end, 7, 9),
            IfNode(WantsToEat, "Do we want to eat?",
                DoAction(self.inst, DoFindAndEatMiasmaAction, "Finding Miasma To Eat")),
            --TODO see if we actually have a good direction to go in.
            -- If we don't, we should set our control priority even lower than wandering and trust the other head to find a way out
			Wander(self.inst, GetHome, WANDER_DIST, WANDER_TIMES, GetWanderDirection, nil, TestWanderPoint, WANDER_DATA)
		}, UPDATE_RATE)
	)

	local root = PriorityNode(
    {
        request_control_nodes,
        behaviour_nodes,
    }, UPDATE_RATE)

	self.bt = BT(self.inst, root)
end

return ShadowThrallCentipedeBrain