local function on_equipped(inst, data)
    local self = inst.components.itemmimic
    self.fail_as_invobject = true

    local owner = data.owner
    if not owner then return end

    -- We're in an "equipped" listener so I'm just going to assume we have this!
    local equippable = inst.components.equippable
    if equippable.equipslot == EQUIPSLOTS.HANDS then
        inst:ListenForEvent("working", self._on_do_work, owner)
        inst:ListenForEvent("onattackother", self._on_do_attack, owner)
    elseif equippable.equipslot == EQUIPSLOTS.HEAD then
        inst:ListenForEvent("attacked", self._on_owner_attacked, owner)
        inst:ListenForEvent("blocked", self._on_owner_attacked, owner)
    elseif equippable.equipslot == EQUIPSLOTS.BODY then
        inst:ListenForEvent("attacked", self._on_owner_attacked, owner)
        inst:ListenForEvent("blocked", self._on_owner_attacked, owner)
    end
end

local function on_unequipped(inst, data)
    local self = inst.components.itemmimic
    self.fail_as_invobject = nil

    local owner = data.owner
    if not owner then return end

    -- We're in an "unequipped" listener so I'm just going to assume we have this!
    local equippable = inst.components.equippable
    if equippable.equipslot == EQUIPSLOTS.HANDS then
        inst:RemoveEventCallback("working", self._on_do_work, owner)
        inst:RemoveEventCallback("onattackother", self._on_do_attack, owner)
    elseif equippable.equipslot == EQUIPSLOTS.HEAD then
        inst:RemoveEventCallback("attacked", self._on_owner_attacked, owner)
        inst:RemoveEventCallback("blocked", self._on_owner_attacked, owner)
    elseif equippable.equipslot == EQUIPSLOTS.BODY then
        inst:RemoveEventCallback("attacked", self._on_owner_attacked, owner)
        inst:RemoveEventCallback("blocked", self._on_owner_attacked, owner)
    end
end

local function turn_evil_redirect(inst, owner)
    inst.components.itemmimic:TurnEvil(owner)
end

local function interacted_with_redirect(inst, owner)
    if owner and owner.components.talker then
        owner.components.talker:Say(GetActionFailString(owner, "GENERIC", "ITEMMIMIC"))
    end
    inst.components.itemmimic:TurnEvil(owner)
end

local function on_put_in_inventory(inst, data)
    local owner = data.owner or (inst.components.inventoryitem ~= nil and inst.components.inventoryitem:GetGrandOwner())

    if owner then
        inst:ListenForEvent("performaction", inst.components.itemmimic._perform_action_listener, owner)
    end

    -- If we're not equippable, actively transform.
    -- If we are, wait for one of the other events to fire.
    if not inst.components.equippable then
        inst:DoTaskInTime(8 + 4 * math.random(), turn_evil_redirect, owner)
    end
end

local function on_dropped(inst)
    local owner = (inst.components.inventoryitem ~= nil and inst.components.inventoryitem:GetGrandOwner())
    if owner then
        inst:RemoveEventCallback("performaction", inst.components.itemmimic._perform_action_listener, owner)
    end
end

local function on_timed_out(inst)
    local self = inst.components.itemmimic
    if self and self._auto_reveal_task then
        self._auto_reveal_task:Cancel()
        self._auto_reveal_task = nil
    end

    local owner = (inst.components.inventoryitem ~= nil and inst.components.inventoryitem:GetGrandOwner())
    turn_evil_redirect(inst, owner)
end

local ACCEPTABLE_ACTIONS =
{
    EQUIP = true,
    UNEQUIP = true,
    DROP = true,
    PICKUP = true,
}

local ItemMimic = Class(function(self, inst)
    self.inst = inst
    --self.fail_as_invobject = nil

    -- Machine reactions (to cover "free" light sources, mostly)
    self._on_interacted_with = function(inst2)
        local doer = (inst2.components.inventoryitem ~= nil and inst2.components.inventoryitem:GetGrandOwner())
        inst2:DoTaskInTime(10*FRAMES, interacted_with_redirect, doer)
    end
    inst:ListenForEvent("machineturnedon", self._on_interacted_with)
    inst:ListenForEvent("machineturnedoff", self._on_interacted_with)
    inst:ListenForEvent("percentusedchange", self._on_interacted_with)

    -- Equippable reactions
    self._on_do_attack = function(owner, data)
        self.inst:DoTaskInTime(5*FRAMES, turn_evil_redirect, owner)
    end
    self._on_do_work = function(owner, data)
        self.inst:DoTaskInTime(5*FRAMES, turn_evil_redirect, owner)
    end

    self._on_owner_attacked = function(owner, data)
        self.inst:DoTaskInTime(5*FRAMES, turn_evil_redirect, owner)
    end
    inst:ListenForEvent("equipped", on_equipped)
    inst:ListenForEvent("unequipped", on_unequipped)

    --
    self._perform_action_listener = function(_, action_data)
        local action = action_data.action
        if action and (action.invobject == inst) and not ACCEPTABLE_ACTIONS[action.action.id] then
            inst:DoTaskInTime(5*FRAMES, turn_evil_redirect, action.doer)
        end
    end

    inst:ListenForEvent("onputininventory", on_put_in_inventory)
    inst:ListenForEvent("ondropped", on_dropped)

    local auto_reveal_task_time = TUNING.ITEMMIMIC_AUTO_REVEAL_BASE + math.random() * TUNING.ITEMMIMIC_AUTO_REVEAL_RAND
    self._auto_reveal_task = inst:DoTaskInTime(auto_reveal_task_time, on_timed_out)
end)

function ItemMimic:TurnEvil(target)
    if self.inst.components.inventoryitem then
        local owner = self.inst.components.inventoryitem:GetGrandOwner()
        if owner then
            local holder_component = owner.components.inventory or owner.components.container
            if holder_component then
                holder_component:DropItem(self.inst)
            end
        end
    end

    local replaced = ReplacePrefab(self.inst, "itemmimic_revealed")
    replaced:ForceFacePoint(self.inst.Transform:GetWorldPosition())
    replaced:PushEvent("jump", target)

    if target and target.sg and target:IsValid() then
        target:PushEvent("startled")
        if target.components.sanity and not GetGameModeProperty("no_sanity") then
            target.components.sanity:DoDelta(-TUNING.SANITY_SMALL)
        end
    end
end

-- Update reaction
function ItemMimic:LongUpdate(dt)
    if self._auto_reveal_task then
        local remaining = GetTaskRemaining(self._auto_reveal_task) - dt
        self._auto_reveal_task:Cancel()
        if remaining > 0 then
            self._auto_reveal_task = self.inst:DoTaskInTime(remaining, on_timed_out)
        else
            self._auto_reveal_task = nil
            on_timed_out(self.inst)
        end
    end
end

-- Save/Load
function ItemMimic:OnSave()
    local savedata = {
        add_component_if_missing = true,
    }

    if self._auto_reveal_task then
        savedata.reveal_time_remaining = GetTaskRemaining(self._auto_reveal_task)
    end

    return savedata
end

function ItemMimic:OnLoad(data)
    if data and data.reveal_time_remaining then
        if self._auto_reveal_task then
            self._auto_reveal_task:Cancel()
            self._auto_reveal_task = nil
        end

        self._auto_reveal_task = self.inst:DoTaskInTime(data.reveal_time_remaining, on_timed_out)
    end
end

-- Debug
function ItemMimic:GetDebugString()
    local str = ""
    if self._auto_reveal_task then
        str = str..string.format("AUTO REVEAL IN: %.2f", GetTaskRemaining(self._auto_reveal_task))
    else
        str = str.."NO AUTO REVEAL PENDING (?)"
    end
    return str
end

return ItemMimic