local function SamePrefabAndSkin(inst, other)
    return inst.prefab == other.prefab and inst.skinname == other.skinname
end

local function onitem(self, item)
    if item ~= nil then
        self.inst:AddTag("inventoryitemholder_take")

        if not self.acceptstacks then
            self.inst:RemoveTag("inventoryitemholder_give")
        end
    else
        self.inst:AddTag("inventoryitemholder_give")
        self.inst:RemoveTag("inventoryitemholder_take")
    end
end

local function onacceptstacks(self, acceptstacks)
    if acceptstacks then
        self.inst:AddTag("inventoryitemholder_give")
    end
end

---------------------------------------------------------------------------------------------------------------

-- Hold an item that can be taken at any time.
-- Does NOT support perishable items at the moment.
-- The item drops when the structure finishes burning.

local InventoryItemHolder = Class(function(self, inst)
    self.inst = inst

    self.item = nil

    self.allowed_tags = nil
    self.acceptstacks = false

    self.onitemgivenfn = nil
    self.onitemtakenfn = nil

    self._onitemremoved = function(item) self.item = nil end
end,
nil,
{
    item = onitem,
    acceptstacks = onacceptstacks,
})

---------------------------------------------------------------------------------------------------------------

function InventoryItemHolder:SetAllowedTags(tags)
    self.allowed_tags = tags
end

function InventoryItemHolder:SetOnItemGivenFn(fn)
    self.onitemgivenfn = fn
end

function InventoryItemHolder:SetOnItemTakenFn(fn)
    self.onitemtakenfn = fn
end

function InventoryItemHolder:SetAcceptStacks(bool)
    self.acceptstacks = bool == true
end

---------------------------------------------------------------------------------------------------------------

function InventoryItemHolder:IsHolding()
    return self.item ~= nil
end

---------------------------------------------------------------------------------------------------------------

function InventoryItemHolder:CanGive(item, giver)
    if item.components.inventoryitem == nil then
        return false
    end

    if self.allowed_tags == nil or item:HasOneOfTags(self.allowed_tags) then
        if not self:IsHolding() then
            return true
        end

        return self.acceptstacks and
            self.item.components.stackable ~= nil and
            not self.item.components.stackable:IsFull() and
            SamePrefabAndSkin(self.item, item)
    end
end

function InventoryItemHolder:CanTake(taker)
    return self.item ~= nil and self.item:IsValid()
end

---------------------------------------------------------------------------------------------------------------

function InventoryItemHolder:GiveItem(item, giver)
    if not self:CanGive(item, giver) then
        return false
    end

	local owner = item.components.inventoryitem:GetGrandOwner()
	if owner then
		if owner.components.inventory then
			--Use DropItem
			--RemoveItem should only be used when immediately giving back to inventory
			item = owner.components.inventory:DropItem(item, self.acceptstacks) or item
		else--if owner.components.container then
			--V2C: containers should not be able to perform a give action anyway.
			return false
		end
	end

    if self.item ~= nil and self.item.components.stackable ~= nil then
        item = self.item.components.stackable:Put(item)

        if item ~= nil then
            giver.components.inventory:GiveItem(item)

            item = nil
        end
    end

    if item ~= nil and item:IsValid() then
        self.inst:AddChild(item)
        item:RemoveFromScene()
        item.Transform:SetPosition(0, 0, 0)
        item.components.inventoryitem:HibernateLivingItem()
        item:AddTag("outofreach")

        self.inst:ListenForEvent("onremove", self._onitemremoved, item)

        self.item = item
    end

    if self.item ~= nil and (self.item.components.stackable == nil or self.item.components.stackable:IsFull()) then
        self.inst:RemoveTag("inventoryitemholder_give")
    end

    if self.onitemgivenfn ~= nil then
        -- Be aware that the item might be nil at this point, in case it gets stacked on given.
        self.onitemgivenfn(self.inst, item, giver)
    end

    return true
end

function InventoryItemHolder:TakeItem(taker, wholestack)
    if wholestack == nil then
        wholestack = true
    end

    if not self:CanTake(taker) then
        return false
    end

    local item = not wholestack and self.item.components.stackable ~= nil and self.item.components.stackable:Get() or self.item

    if item == self.item then
        self.inst:RemoveChild(self.item)

        self.item:RemoveTag("outofreach")

        self.inst:RemoveEventCallback("onremove", self._onitemremoved, self.item)

    elseif self.item.components.stackable ~= nil and not self.item.components.stackable:IsFull() then
        self.inst:AddTag("inventoryitemholder_give")
    end

    item.components.inventoryitem:InheritWorldWetnessAtTarget(self.inst)

    local pos = self.inst:GetPosition()

    if taker ~= nil and taker:IsValid() and taker.components.inventory ~= nil then
        taker.components.inventory:GiveItem(item, nil, pos)
    else
        item.Transform:SetPosition(pos:Get())
        item.components.inventoryitem:OnDropped(true)
    end

    if self.onitemtakenfn ~= nil then
        -- Be aware that the item might be invalid at this point, in case it gets stacked on taken.
        self.onitemtakenfn(self.inst, item, taker, item == self.item)
    end

    if item == self.item then
        self.item = nil
    end

    return true
end

---------------------------------------------------------------------------------------------------------------

function InventoryItemHolder:OnSave()
    local data = {}
    local references = nil

    if self.item ~= nil and self.item:IsValid() and self.item.persists then
        data.item, references = self.item:GetSaveRecord()
    end

    return next(data) ~= nil and data or nil, references
end

function InventoryItemHolder:OnLoad(data, newents)
    if data.item ~= nil then
        local item = SpawnSaveRecord(data.item, newents)

        if item ~= nil then
            self:GiveItem(item, self.inst)
        end
    end
end

---------------------------------------------------------------------------------------------------------------

function InventoryItemHolder:OnRemoveFromEntity()
    self:TakeItem()

    self.inst:RemoveTag("inventoryitemholder_give")
    self.inst:RemoveTag("inventoryitemholder_take")
end

---------------------------------------------------------------------------------------------------------------

function InventoryItemHolder:GetDebugString()
    return string.format(
        "Item:  %s   |   Allowed Tags:   %s",
        tostring(self.item),
        self.allowed_tags ~= nil and table.concat(self.allowed_tags, ", ") or "NO RESTRICTIONS"
    )
end

---------------------------------------------------------------------------------------------------------------

return InventoryItemHolder
