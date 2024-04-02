require "behaviours/standstill"

---------------------------------------------------------------------------------------------------

-- Table shared by all storage robots.
-- Keeping this for mods / people spawning more of them.
local ignorethese = { --[[ [item] = worker ]] }

local StorageRobotBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function StorageRobotBrain:IgnoreItem(item)
    self:UnignoreItem()

    self._targetitem = item

    ignorethese[item] = self.inst
end

function StorageRobotBrain:UnignoreItem()
    if self._targetitem and ignorethese[self._targetitem] then
        ignorethese[self._targetitem] = nil
    end
end

function StorageRobotBrain:ShouldIgnoreItem(item)
    return ignorethese[item] ~= nil and ignorethese[item] ~= self.inst
end

---------------------------------------------------------------------------------------------------

local function PickUpAction(inst)
    local activeitem = inst.components.inventory:GetActiveItem()

    if activeitem ~= nil then
        inst.components.inventory:DropItem(activeitem, true, true)
    end

    ----------------

    local onlytheseprefabs

    local item = inst.components.inventory:GetFirstItemInAnySlot()

    if item ~= nil then
        if (item.components.stackable == nil or item.components.stackable:IsFull()) then
            return
        end

        onlytheseprefabs = {[item.prefab] = true}
    end

    ----------------

    local item = inst:FindPickupableItem(onlytheseprefabs)

    if item == nil then
        return
    end

    inst.brain:IgnoreItem(item)

    return BufferedAction(inst, item, item.components.trap ~= nil and ACTIONS.CHECKTRAP or ACTIONS.PICKUP, nil, nil, nil, nil, nil, nil, 0)
end

---------------------------------------------------------------------------------------------------

local function StoreItemAction(inst)
    local item = inst.components.inventory:GetFirstItemInAnySlot() or inst.components.inventory:GetActiveItem() -- This is intentionally backwards to give the bigger stacks first.

    if item == nil then
        return nil
    end

    inst.brain:UnignoreItem()

    local container = inst:FindContainerWithItem(item)

    return container ~= nil and BufferedAction(inst, container, ACTIONS.STORE, item) or nil
end

---------------------------------------------------------------------------------------------------

local function GoHomeAction(inst)
    local pos = inst:GetSpawnPoint()

    if pos == nil then
        return
    end

    inst.brain:UnignoreItem()

    local item = inst.components.inventory:GetFirstItemInAnySlot() or inst.components.inventory:GetActiveItem() -- This is intentionally backwards to give the bigger stacks first.

    if item ~= nil then
        inst.components.inventory:DropItem(item, true, true)
    end

    return BufferedAction(inst, nil, ACTIONS.WALKTO, nil, pos, nil, 0.2)
end

---------------------------------------------------------------------------------------------------

function StorageRobotBrain:OnStart()
    self.PickUpAction = PickUpAction
    self.StoreItemAction  = StoreItemAction
    self.GoHomeAction = GoHomeAction

    local root = PriorityNode(
    {
        WhileNode( function() return not self.inst.sg:HasAnyStateTag("busy", "broken") end, "NO BRAIN WHEN BUSY OR BROKEN",
            PriorityNode({
                DoAction( self.inst, self.PickUpAction,     "Pick Up Item",    true ),
                DoAction( self.inst, self.StoreItemAction,  "Store Item",      true ),
                DoAction( self.inst, self.GoHomeAction,     "Return to spawn", true ),
                StandStill(self.inst),
            }, .25)
        ),
    }, .25)

    self.bt = BT(self.inst, root)
end

function StorageRobotBrain:OnInitializationComplete()
    self.inst:UpdateSpawnPoint(true)
end

return StorageRobotBrain
