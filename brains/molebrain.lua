require "behaviours/wander"
require "behaviours/runaway"
require "behaviours/doaction"
local BrainCommon = require("brains/braincommon")

local STOP_RUN_DIST = 10
local SEE_PLAYER_DIST = 5

local AVOID_PLAYER_DIST = 0
local AVOID_PLAYER_STOP = 6

local SEE_BAIT_DIST = 20
local MAX_WANDER_DIST = 20

local MoleBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function HasHome(inst)
    return inst.components.homeseeker
        and inst.components.homeseeker.home
        and inst.components.homeseeker.home:IsValid()
    end

local function GoHomeAction(inst)
    if HasHome(inst) and inst.sg:HasStateTag("trapped") == false then
        return BufferedAction(inst, inst.components.homeseeker.home, ACTIONS.GOHOME)
    end
end

local function ShouldMakeHome(inst)
    return not HasHome(inst)
        and (inst.needs_home_time and (GetTime() - inst.needs_home_time > inst.make_home_delay))
end

local function NoHolesNoInvisibleTiles(pt)
    local tile = TheWorld.Map:GetTileAtPoint(pt:Get())
    if GROUND_INVISIBLETILES[tile] then
        return false
    end

    return not TheWorld.Map:IsPointNearHole(pt)
end

local function MakeNewHomeAction(inst)
    local pos = inst:GetPosition()
    local offset = FindWalkableOffset(pos, math.random() * TWOPI, math.random(5, 15), 120, false, false, NoHolesNoInvisibleTiles)
    if offset ~= nil then
        pos.x = pos.x + offset.x
        pos.y = 0
        pos.z = pos.z + offset.z
        return BufferedAction(inst, nil, ACTIONS.MAKEMOLEHILL, nil, pos)
    end
end

local function IsMoleBait(item)
    return item.components.bait ~= nil or item:HasTag("bell")
end

local function SelectedTargetTimeout(target)
    target.selectedasmoletarget = nil
end

local TAKEBAIT_MUST_TAGS = { "molebait" }
local TAKEBAIT_CANT_TAGS = { "outofreach", "INLIMBO", "fire" }

local function TakeBaitAction(inst)
    -- Don't look for bait if just spawned, busy making a new home, or has full inventory
    if inst:GetTimeAlive() < 3 or inst.sg:HasStateTag("busy") or ShouldMakeHome(inst) or (inst.components.inventory and inst.components.inventory:IsFull()) then
        return
    end

    local target = FindEntity(inst, SEE_BAIT_DIST, IsMoleBait, TAKEBAIT_MUST_TAGS, TAKEBAIT_CANT_TAGS)
    if target ~= nil and not target.selectedasmoletarget and target:IsOnValidGround() then
        target.selectedasmoletarget = true
        target:DoTaskInTime(5, SelectedTargetTimeout)
        local act = BufferedAction(inst, target, ACTIONS.STEALMOLEBAIT)
        act.validfn = function()
            return not (target.components.inventoryitem ~= nil and target.components.inventoryitem:IsHeld())
                and not (target.components.burnable ~= nil and target.components.burnable:IsBurning())
        end
        return act
    end
end

local function PeekAction(inst)
    return BufferedAction(inst, nil, ACTIONS.MOLEPEEK)
end

function MoleBrain:OnStart()
    local root = PriorityNode(
    {
		BrainCommon.PanicTrigger(self.inst),
        BrainCommon.ElectricFencePanicTrigger(self.inst),
        WhileNode( function() return ShouldMakeHome(self.inst) end, "Home Dug Up",
            DoAction(self.inst, MakeNewHomeAction, "Make Home", false)),
        WhileNode(function() return self.inst.flee == true end, "Flee",
            RunAway(self.inst, "scarytoprey", AVOID_PLAYER_DIST, AVOID_PLAYER_STOP)),
        WhileNode(function() return TheWorld.state.isacidraining end, "Acid Raining",
            DoAction(self.inst, GoHomeAction, "Go Home", false)),
        WhileNode(function() return not self.inst.sg:HasStateTag("busy") and
                                (GetTime() > (self.inst.last_above_time + self.inst.peek_interval))
                            end, "Should Peek",
            DoAction(self.inst, PeekAction, "Do Peek", false)),
        WhileNode(function() return self.inst.components.inventory:IsFull() end, "Deposit Inventory",
            DoAction(self.inst, GoHomeAction, "Go Home", false)),
        EventNode(self.inst, "gohome",
            DoAction(self.inst, GoHomeAction, "Go Home", false)),
        DoAction(self.inst, TakeBaitAction, "Take Bait", false),
        WhileNode(function() return TheWorld.state.isday or
                            (TheWorld.state.iscaveday and self.inst:IsInLight())
                        end, "Is Day",
            DoAction(self.inst, GoHomeAction, "Go Home", false )),
        Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("home") end, MAX_WANDER_DIST),
    }, .25)
    self.bt = BT(self.inst, root)
end

return MoleBrain
