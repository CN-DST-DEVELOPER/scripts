
local function OnEquipped(inst, data)
    inst.components.luckitem:UpdateOwnerLuck_Internal()
end

local function OnUnequipped(inst, data)
    inst.components.luckitem:RemoveOwnerLuck_Internal()
end

local function OnStackSizeChanged(inst, data)
    inst.components.luckitem:UpdateOwnerLuck_Internal()
end

local function OnForceUpdateOwnerLuck(inst, data)
    inst.components.luckitem:UpdateOwnerLuck_Internal()
end

local LuckItem = Class(function(self, inst)
    self.inst = inst
    --
    self.luck = 0
    self.equippedluck = 0
    --
    MakeComponentAnInventoryItemSource(self)
    inst:ListenForEvent("equipped", OnEquipped)
	inst:ListenForEvent("unequipped", OnUnequipped)
    inst:ListenForEvent("stacksizechange", OnStackSizeChanged)
    inst:ListenForEvent("updateownerluck", OnForceUpdateOwnerLuck)
end)

function LuckItem:OnRemoveFromEntity()
    RemoveComponentInventoryItemSource(self)
    self.inst:RemoveEventCallback("equipped", OnEquipped)
    self.inst:RemoveEventCallback("unequipped", OnUnequipped)
    self.inst:RemoveEventCallback("stacksizechange", OnStackSizeChanged)
    self.inst:RemoveEventCallback("updateownerluck", OnForceUpdateOwnerLuck)
end

function LuckItem:UpdateOwnerLuck_Internal(owner)
    if not owner then
        local inventoryitem = self.inst.components.inventoryitem
        if inventoryitem then
            owner = inventoryitem:GetGrandOwner()
        end
    end
    if owner then
        if owner.components.luckuser then
            local isequipped = self.inst.components.equippable and self.inst.components.equippable:IsEquipped() or false
            local luck = (isequipped and self:GetEquippedLuck() or self:GetLuck()) * GetStackSize(self.inst)
            owner.components.luckuser:SetLuckSource(luck, self.inst)
        end
    end
end

function LuckItem:RemoveOwnerLuck_Internal(owner)
    if not owner then
        local inventoryitem = self.inst.components.inventoryitem
        if inventoryitem then
            owner = inventoryitem:GetGrandOwner()
        end
    end
    if owner then
        if owner.components.luckuser then
            owner.components.luckuser:RemoveLuckSource(self.inst)
        end
    end
end

-- MakeComponentAnInventoryItemSource functions
function LuckItem:OnItemSourceRemoved(owner)
    self:RemoveOwnerLuck_Internal(owner)
end

function LuckItem:OnItemSourceNewOwner(owner)
    self:UpdateOwnerLuck_Internal(owner)
end
--

function LuckItem:SetLuck(luck)
    self.luck = luck
end

function LuckItem:GetLuck()
    return FunctionOrValue(self.luck, self.inst, self.itemsource_owner)
end

function LuckItem:SetEquippedLuck(luck)
    self.equippedluck = luck
end

function LuckItem:GetEquippedLuck()
    return FunctionOrValue(self.equippedluck, self.inst, self.itemsource_owner)
end

function LuckItem:GetDebugString()
    local luck = self:GetLuck() * GetStackSize(self.inst) * 100
    local equippedluck = self:GetEquippedLuck() * GetStackSize(self.inst) * 100
    return string.format("luck: %.1f%%, equippedluck: %.1f%%", luck, equippedluck)
end

return LuckItem