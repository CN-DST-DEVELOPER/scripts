require "behaviours/standstill"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/panic"
require "behaviours/wander"
require "behaviours/chaseandattack"
local BrainCommon = require("brains/braincommon")

local MAX_CHASE_TIME = 60
local MAX_CHASE_DIST = 40
local SEE_FOOD_DIST = 30
local MAX_WANDER_DIST = 40
local NO_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO", "outofreach" }

local BatBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GoHomeAction(inst)
    return inst.components.homeseeker ~= nil
        and inst.components.homeseeker.home ~= nil
        and inst.components.homeseeker.home:IsValid()
        and inst.components.homeseeker.home.components.childspawner ~= nil
        and not inst.components.teamattacker.inteam
        and BufferedAction(inst, inst.components.homeseeker.home, ACTIONS.GOHOME)
        or nil
end

local BATDESTINATION_TAG = { "batdestination" }
local function EscapeAction(inst)
    if TheWorld.state.iscaveday then
        return GoHomeAction(inst)
    end
    -- wander up through a sinkhole at night
    local x, y, z = inst.Transform:GetWorldPosition()
    local exit = TheSim:FindEntities(x, 0, z, TUNING.BAT_ESCAPE_RADIUS, BATDESTINATION_TAG)[1]
    return exit ~= nil
        and (exit.components.childspawner ~= nil or
            exit.components.hideout ~= nil)
        and BufferedAction(inst, exit, ACTIONS.GOHOME)
        or nil
end

local function IsFoodValid(item, inst)
    local isinfused = inst.components.acidinfusible ~= nil and inst.components.acidinfusible:IsInfused() -- Make isinfused super hungry.
    return item:GetTimeAlive() >= (isinfused and 1 or 8)
        and item:IsOnPassablePoint(true)
        and inst.components.eater:CanEat(item)
end
local function EatFoodAction(inst)
    if inst.sg:HasStateTag("busy") then
        return
    elseif inst.components.inventory ~= nil and inst.components.eater ~= nil then
        local target = inst.components.inventory:FindItem(function(item)
            return inst.components.eater:CanEat(item)
        end)
        if target ~= nil then
            return BufferedAction(inst, target, ACTIONS.EAT)
        end
    end

    local target = FindEntity(inst, SEE_FOOD_DIST, IsFoodValid, nil, NO_TAGS, inst.components.eater:GetEdibleTags())
    return target ~= nil and BufferedAction(inst, target, ACTIONS.PICKUP) or nil
end

-- NOTES(JBK): Similar to slurtlebrain with some changes.
local STEALFOOD_CANT_TAGS = { "playerghost", "fire", "burnt", "INLIMBO", "outofreach" }
local STEALFOOD_ONEOF_TAGS = { "player", "_container" }
local function IsStealActionValid(act)
    local itemtosteal = act.target
    return itemtosteal and (itemtosteal.components.inventoryitem and itemtosteal.components.inventoryitem:IsHeld())
end

local function StealNitreAction(inst)
    if inst.sg:HasStateTag("busy") then
        return
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, SEE_FOOD_DIST, nil, STEALFOOD_CANT_TAGS, STEALFOOD_ONEOF_TAGS)

    for i, v in ipairs(ents) do
        --go through player inv and find valid food
        local inv = v.components.inventory
        if inv and v:IsOnValidGround() then
            local pack = inv:GetEquippedItem(EQUIPSLOTS.BODY)
            local validfood = nil
            if pack and pack.components.container then
                for k = 1, pack.components.container.numslots do
                    local item = pack.components.container.slots[k]
                    if item and item.prefab == "nitre" then
                        if validfood == nil then
                            validfood = {}
                        end
                        table.insert(validfood, item)
                    end
                end
            end

            for k = 1, inv.maxslots do
                local item = inv.itemslots[k]
                if item and item.prefab == "nitre" then
                    if validfood == nil then
                        validfood = {}
                    end
                    table.insert(validfood, item)
                end
            end

            if validfood ~= nil then
                local itemtosteal = validfood[math.random(1, #validfood)]
                if itemtosteal and
                itemtosteal.components.inventoryitem and
                itemtosteal.components.inventoryitem.owner then
                    local act = BufferedAction(inst, itemtosteal, ACTIONS.STEAL)
                    act.validfn = IsStealActionValid
                    act.attack = true
                    return act
                end
            end
        end

        local container = v.components.container
        if container then
            local validfood = nil
            for k = 1, container.numslots do
                local item = container.slots[k]
                if item and item.prefab == "nitre" then
                    if validfood == nil then
                        validfood = {}
                    end
                    table.insert(validfood, item)
                end
            end

            if validfood ~= nil then
                local itemtosteal = validfood[math.random(1, #validfood)]
                local act = BufferedAction(inst, itemtosteal, ACTIONS.STEAL)
                act.validfn = IsStealActionValid
                act.attack = true
                return act
            end
        end
    end

    return nil
end

local function LeaveFormation(inst)
    if inst.components.teamattacker then
        inst.components.teamattacker:LeaveFormation()
    end
end

local function LeaveTeam(inst)
    if inst.components.teamattacker then
        inst.components.teamattacker:LeaveTeam()
    end
end

local function AcidBatAction(inst)
    local act
    local orders = inst.components.teamattacker:GetOrders()

    if orders == ORDERS.HOLD then
        act = EatFoodAction(inst)
    elseif orders == ORDERS.ATTACK then
        act = StealNitreAction(inst)
    elseif orders == nil then
        -- No orders try eating if available else steal.
        act = EatFoodAction(inst) or StealNitreAction(inst)
    end

    if act ~= nil then
        LeaveFormation(inst)
    end

    return act
end

local function GetWanderPos(inst)
    inst.components.knownlocations:GetLocation("home")
end

function BatBrain:OnStart()
    local leave_formation = function() LeaveTeam(self.inst) end
    local root = PriorityNode({
        EventNode(self.inst, "panic",
            ParallelNode{
                Panic(self.inst),
                ActionNode(leave_formation),
                WaitNode(6),
            }),

        -- Panic nodes
        WhileNode(function() return BrainCommon.ShouldTriggerPanic(self.inst) end, "Panic",
            ParallelNode{
                Panic(self.inst),
                ActionNode(leave_formation),
            }),
        WhileNode(function() return BrainCommon.ShouldAvoidElectricFence(self.inst) end, "AvoidElectricFence",
            ParallelNode{
                AvoidElectricFence(self.inst),
                ActionNode(leave_formation),
            }),
        --

        AttackWall(self.inst),
        IfNode(function()
                    self.inst.components.teamattacker:JoinFormation() -- Always try to rejoin the formation if possible.
                    return self.inst.components.acidinfusible ~= nil and self.inst.components.acidinfusible:IsInfused()
                end, "Is Acid Infused",
            DoAction(self.inst, AcidBatAction)
        ),
        ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST),
        WhileNode(function() return TheWorld.state.isday end, "IsDay",
            DoAction(self.inst, GoHomeAction)),
        WhileNode(function() return self.inst.components.teamattacker.teamleader == nil end, "No Leader",
            PriorityNode{
                DoAction(self.inst, EatFoodAction),
                MinPeriod(self.inst, TUNING.BAT_ESCAPE_TIME, false,
                    DoAction(self.inst, EscapeAction)),
                Wander(self.inst, GetWanderPos, MAX_WANDER_DIST),
            }),
    }, .25)

    self.bt = BT(self.inst, root)
end

function BatBrain:OnInitializationComplete()
    self.inst.components.knownlocations:RememberLocation("home", self.inst:GetPosition(), true)
end

return BatBrain
