
local BrainCommon = require("brains/braincommon")

local Chest_MimicBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local INTERACT_COOLDOWN_NAME = "interaction_cooldown"

local SEE_DIST = 30

local function TryToHide(inst)
    if inst.sg:HasStateTag("busy") then
        return nil
    end

    local ipos = inst:GetPosition()
    local walkable_offset = FindWalkableOffset(ipos, PI2*math.random(), 15, nil, true, false, nil, false, false)
    if not walkable_offset then
        return nil
    else
        local position = ipos + walkable_offset
        return BufferedAction(inst, nil, ACTIONS.MOLEPEEK, nil, position)
    end
end

local FINDITEMS_MUST_TAGS = { "_inventoryitem" }
local FINDITEMS_CANT_TAGS = {
    "creature", "DECOR", "FX", "heavy", "hostile", "INLIMBO", "monster", "nosteal", "outofreach",
}
local function FindGroundItemAction(inst)
    if inst.sg:HasStateTag("busy")
            or inst.components.timer:TimerExists(INTERACT_COOLDOWN_NAME)
            or inst.components.inventory:IsFull() then
        return nil
    end

    local test_ground_item = function(item)
        return item:GetTimeAlive() >= 1
            and item.components.inventoryitem ~= nil
    end
    local target = FindEntity(inst, SEE_DIST, test_ground_item, FINDITEMS_MUST_TAGS, FINDITEMS_CANT_TAGS)
    if not target then return nil end

    local action_to_perform = (inst.components.eater:CanEat(target) and ACTIONS.EAT) or ACTIONS.PICKUP
    local buffered_action = BufferedAction(inst, target, action_to_perform)

    inst._start_interact_cooldown_callback = inst._start_interact_cooldown_callback or function()
        inst.components.timer:StartTimer(INTERACT_COOLDOWN_NAME, GetRandomWithVariance(5, 2))
    end
    buffered_action:AddSuccessAction(inst._start_interact_cooldown_callback)
    buffered_action.validfn = function()
        return not (target.components.inventoryitem and target.components.inventoryitem:IsHeld())
            and (not target.sg or not target.sg:HasStateTag("flight"))
            and target:IsNear(inst, 4)
    end
    return buffered_action
end

local function GetWanderPoint(inst)
    local target = inst:GetNearestPlayer(true)
    return (target ~= nil and target:GetPosition())
        or inst.components.knownlocations:GetLocation("spawnpoint")
        or nil
end

function Chest_MimicBrain:OnStart()
	local root = PriorityNode(
    {
        BrainCommon.PanicTrigger(self.inst),

        WhileNode(function() return self.inst.components.inventory:IsFull() end, "Inventory Full",
            DoAction(self.inst, TryToHide, "Try To Transform Back")
        ),

        WhileNode(function() return not self.inst.sg:HasStateTag("jumping") end, "NotJumpingBehaviour",
            PriorityNode({
                IfNode(function() return not self.inst.components.timer:TimerExists("angry") end, "Not Angry",
                    DoAction(self.inst, FindGroundItemAction, "Find Things To Gobble Up", nil, 10)
                ),

                ChaseAndAttack(self.inst, 100),

                Wander(self.inst, GetWanderPoint, 20),
            }, .25)
        ),
    }, .25 )

    self.bt = BT(self.inst, root)
end

function Chest_MimicBrain:OnInitializationComplete()
    self.inst.components.knownlocations:RememberLocation("spawnpoint", self.inst:GetPosition())
end

return Chest_MimicBrain