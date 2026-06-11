local ItemSlot = require "widgets/itemslot"

local InvSlot = Class(ItemSlot, function(self, num, atlas, bgim, owner, container)
    ItemSlot._ctor(self, atlas, bgim, owner)
    self.owner = owner
    self.container = container
    self.num = num
end)

function InvSlot:OnControl(control, down)
    if InvSlot._base.OnControl(self, control, down) then return true end
    if not down then
        return false
    end

    local isreadonlycontainer = self.container.IsReadOnlyContainer and self.container:IsReadOnlyContainer()

    if control == CONTROL_ACCEPT then
        --generic click, with possible modifiers
        if isreadonlycontainer then
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
            return true
        end
        if TheInput:IsControlPressed(CONTROL_FORCE_INSPECT) then
            self:Inspect()
        elseif TheInput:IsControlPressed(CONTROL_FORCE_TRADE) then
			local stack_mod = TheInput:IsControlPressed(CONTROL_FORCE_STACK)
			if self:CanTradeItem(stack_mod) then
				self:TradeItem(stack_mod)
            else
                return false
            end
        else
            self:Click(TheInput:IsControlPressed(CONTROL_FORCE_STACK))
        end
    elseif control == CONTROL_SECONDARY then
        --alt use (usually RMB)
        if isreadonlycontainer then
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
            return true
        end
        if TheInput:IsControlPressed(CONTROL_FORCE_TRADE) then
			local single = TheInput:IsControlPressed(CONTROL_FORCE_STACK)
			if (	self.tile and
					self.tile.item and
					self.tile.item.replica.inventoryitem and
					self.tile.item.replica.inventoryitem:IsLockedInSlot()
				) and
				not (	single and
						self.tile.item.replica.stackable and
						self.tile.item.replica.stackable:IsStack()
					)
			then
				self:UseItem()
			else
				self:DropItem(single)
			end
        else
            self:UseItem()
        end
        --the rest are explicit control presses for controllers
    elseif control == CONTROL_SPLITSTACK then
        if isreadonlycontainer then
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
            return true
        end
        self:Click(true)
    elseif control == CONTROL_TRADEITEM then
        if isreadonlycontainer then
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
            return true
        end
		if self:CanTradeItem(false) then
            self:TradeItem(false)
        else
            return false
        end
    elseif control == CONTROL_TRADESTACK then
        if isreadonlycontainer then
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
            return true
        end
		if self:CanTradeItem(true) then
            self:TradeItem(true)
        else
            return false
        end
    elseif control == CONTROL_INSPECT then
        if isreadonlycontainer then
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
            return true
        end
        self:Inspect()
    else
        return false
    end
    return true
end

function InvSlot:Click(stack_mod)
    local slot_number = self.num
	local character = self.owner
    local inventory = character and character.replica.inventory or nil
    local active_item = inventory and inventory:GetActiveItem() or nil
    local container = self.container
    local container_item = container and container:GetItemInSlot(slot_number) or nil

    if active_item ~= nil or container_item ~= nil then
        if container_item == nil then
            --Put active item into empty slot
            if container:CanTakeItemInSlot(active_item, slot_number) then
                if active_item.replica.stackable ~= nil and
                    active_item.replica.stackable:IsStack() and
                    (stack_mod or not container:AcceptsStacks()) then
                    --Put one only
                    container:PutOneOfActiveItemInSlot(slot_number)
                else
                    --Put entire stack
                    container:PutAllOfActiveItemInSlot(slot_number)
                end
                TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
            else
                TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
            end
        elseif active_item == nil then
            --Take active item from slot
            local takecount
            if inventory and inventory ~= container then -- Variable character cannot be nil from above.
                local maxtakecountfunction = GetDesiredMaxTakeCountFunction(container_item.prefab)
                if maxtakecountfunction then
                    takecount = maxtakecountfunction(character, inventory, container_item, container)
                end
            end
            if takecount then
                if takecount > 0 then
                    -- Take a set number from a slot if possible.
                    if stack_mod then
                        takecount = math.max(math.floor(takecount / 2), 1)
                    end
					if not (container_item.replica.inventoryitem and container_item.replica.inventoryitem:IsLockedInSlot()) or
						(container_item.replica.stackable and container_item.replica.stackable:StackSize() > takecount)
					then
						container:TakeActiveItemFromCountOfSlot(slot_number, takecount)
						TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
					else
						-- Block taking entire stack out of a locked slot.
						TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
					end
                else
                    -- Block taking anything if this override exists.
                    TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
                end
            elseif stack_mod and
                container_item.replica.stackable ~= nil and
                container_item.replica.stackable:IsStack() then
                --Take one only
                container:TakeActiveItemFromHalfOfSlot(slot_number)
                TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
			elseif container_item.replica.inventoryitem and container_item.replica.inventoryitem:IsLockedInSlot() then
				-- Block taking entire stack out of a locked slot.
				TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
            else
                --Take entire stack
                container:TakeActiveItemFromAllOfSlot(slot_number)
                TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
            end
        elseif container:CanTakeItemInSlot(active_item, slot_number) then
            if container_item.replica.stackable ~= nil and container_item.replica.stackable:CanStackWith(active_item) and container:AcceptsStacks() then
                --Add active item to slot stack
                if stack_mod and
                    active_item.replica.stackable ~= nil and
                    active_item.replica.stackable:IsStack() and
                    not container_item.replica.stackable:IsFull() then
                    --Add only one
                    container:AddOneOfActiveItemToSlot(slot_number)
                else
                    --Add entire stack
                    container:AddAllOfActiveItemToSlot(slot_number)
                end
                TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")

            elseif active_item.replica.stackable ~= nil and active_item.replica.stackable:IsStack() and not container:AcceptsStacks() then
                container:SwapOneOfActiveItemWithSlot(slot_number)

			elseif (container:AcceptsStacks() or not (active_item.replica.stackable and active_item.replica.stackable:IsStack()))
				and not (container_item.replica.stackable and container_item.replica.stackable:IsOverStacked())
			then
                --Swap active item with slot item
                container:SwapActiveItemWithSlot(slot_number)
                TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
            else
                TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
            end
        else
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
        end
    end
end

local function FindBestContainer(self, item, containers, exclude_containers)
    if item == nil or containers == nil then
        return
    end

    --Construction containers
    --NOTE: reusing containerwithsameitem variable
    local containerwithsameitem = self.owner ~= nil and self.owner.components.constructionbuilderuidata ~= nil and self.owner.components.constructionbuilderuidata:GetContainer() or nil
    if containerwithsameitem ~= nil then
        if containers[containerwithsameitem] ~= nil and (exclude_containers == nil or not exclude_containers[containerwithsameitem]) then
            local slot = self.owner.components.constructionbuilderuidata:GetSlotForIngredient(item.prefab)
            if slot ~= nil then
                local container = containerwithsameitem.replica.container
                if container ~= nil and container:CanTakeItemInSlot(item, slot) then
                    local existingitem = container:GetItemInSlot(slot)
                    if existingitem == nil or (container:AcceptsStacks() and existingitem.replica.stackable ~= nil and not existingitem.replica.stackable:IsFull()) then
                        return containerwithsameitem
                    end
                end
            end
        end
        containerwithsameitem = nil
    end

    --local containerwithsameitem = nil --reused with construction containers code above
    local containerwithemptyslot = nil
    local containerwithnonstackableslot = nil
    local containerwithlowpirority = nil

    for k, v in pairs(containers) do
        if exclude_containers == nil or not exclude_containers[k] then
            local container = k.replica.container or k.replica.inventory
            if container ~= nil and container:CanTakeItemInSlot(item) then
                local isfull = container:IsFull()
                if container:AcceptsStacks() then
                    if not isfull and containerwithemptyslot == nil then
                        if container.lowpriorityselection then
                            containerwithlowpirority = k
                        else
                            containerwithemptyslot = k
                        end
                    end
                    if item.replica.equippable ~= nil and container == k.replica.inventory then
                        local equip = container:GetEquippedItem(item.replica.equippable:EquipSlot())
                        if equip ~= nil and equip.prefab == item.prefab and equip.skinname == item.skinname then
                            if equip.replica.stackable ~= nil and equip.replica.stackable:CanStackWith(item) and not equip.replica.stackable:IsFull() then
                                return k
                            elseif not isfull and containerwithsameitem == nil then
                                containerwithsameitem = k
                            end
                        end
                    end
                    for k1, v1 in pairs(container:GetItems()) do
                        if v1.prefab == item.prefab and v1.skinname == item.skinname then
                            if v1.replica.stackable ~= nil and v1.replica.stackable:CanStackWith(item) and not v1.replica.stackable:IsFull() then
                                if container.lowpriorityselection then
                                    containerwithlowpirority = k
                                else
                                    return k
                                end
                            elseif not isfull and containerwithsameitem == nil then
                                containerwithsameitem = k
                            end
                        end
                    end
                elseif not isfull and containerwithnonstackableslot == nil then
                    containerwithnonstackableslot = k
                end
            end
        end
    end

    return containerwithsameitem or containerwithemptyslot or containerwithnonstackableslot or containerwithlowpirority
end

function InvSlot:CanTradeItem(stack_mod)
    local item = self.container and (self.container.IsReadOnlyContainer == nil or not self.container:IsReadOnlyContainer()) and self.container:GetItemInSlot(self.num) or nil
	local inventoryitem = item and item.replica.inventoryitem
	if inventoryitem == nil or inventoryitem:CanOnlyGoInPocket() then
		return false -- Do not handle CanOnlyGoInPocketOrPocketContainers let TradeItem do this.
	elseif inventoryitem:IsLockedInSlot() then
		if not stack_mod then
			return false
		end
		local stackable = item.replica.stackable
		if not (stackable and stackable:IsStack()) then
			return false
		end
	end
	return true
end

--moves items between open containers
function InvSlot:TradeItem(stack_mod)
    local slot_number = self.num
	local character = self.owner
    local inventory = character and character.replica.inventory or nil
    local container = self.container
    local container_item = container and (container.IsReadOnlyContainer == nil or not container:IsReadOnlyContainer()) and container:GetItemInSlot(slot_number) or nil

    if character ~= nil and inventory ~= nil and container_item ~= nil then
        local opencontainers = inventory:GetOpenContainers()
        local haswriteablecontainer = false
        for opencontainer, _ in pairs(opencontainers) do
            if opencontainer.replica.container and not opencontainer.replica.container:IsReadOnlyContainer() then
                haswriteablecontainer = true
                break
            end
        end
        if not haswriteablecontainer then
            return
        end

        local overflow = inventory:GetOverflowContainer()
        local backpack = nil
        if overflow ~= nil and overflow:IsOpenedBy(character) then
            backpack = overflow.inst
            overflow = backpack.replica.container
            if overflow == nil then
                backpack = nil
            end
        else
            overflow = nil
        end

        --find our destination container
        local dest_inst = nil
        if container == inventory then
            local playercontainers = backpack ~= nil and { [backpack] = true } or nil
            dest_inst = FindBestContainer(self, container_item, opencontainers, playercontainers)
                or FindBestContainer(self, container_item, playercontainers)
        elseif container == overflow then
            dest_inst = FindBestContainer(self, container_item, opencontainers, { [backpack] = true })
                or (inventory:IsOpenedBy(character)
                    and FindBestContainer(self, container_item, { [character] = true })
                    or nil)
        else
            local exclude_containers = { [container.inst] = true }
            if backpack ~= nil then
                exclude_containers[backpack] = true
            end
            dest_inst = FindBestContainer(self, container_item, opencontainers, exclude_containers) or
                (inventory:IsOpenedBy(character) and character or backpack)
        end

        --if a destination container/inv is found...
        if dest_inst ~= nil then
            local takecount
            if inventory and inventory ~= container then -- Variable character cannot be nil from above.
                local maxtakecountfunction = GetDesiredMaxTakeCountFunction(container_item.prefab)
                if maxtakecountfunction then
                    takecount = maxtakecountfunction(character, inventory, container_item, container)
                end
            end
            if takecount then
                if takecount > 0 then
                    -- Take a set number from a slot if possible.
                    if stack_mod then
                        takecount = math.max(math.floor(takecount / 2), 1)
                    end
					if container_item.replica.inventoryitem and
						container_item.replica.inventoryitem:IsLockedInSlot() and
						(container_item.replica.stackable and container_item.replica.stackable:StackSize() or 1) <= takecount
					then
						TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
					else
						container:MoveItemFromCountOfSlot(slot_number, dest_inst, takecount)
						TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
					end
                else
                    -- Block taking anything if this override exists.
                    TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
                end
            elseif stack_mod and
                container_item.replica.stackable ~= nil and
                container_item.replica.stackable:IsStack() then
                container:MoveItemFromHalfOfSlot(slot_number, dest_inst)
                TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
			elseif container_item.replica.inventoryitem and container_item.replica.inventoryitem:IsLockedInSlot() then
				TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
            else
                container:MoveItemFromAllOfSlot(slot_number, dest_inst)
                TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
            end
        else
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
        end
    end
end

function InvSlot:DropItem(single)
    if self.owner and self.owner.replica.inventory and self.tile and self.tile.item then
		self.owner.replica.inventory:DropItemFromInvTile(self.tile.item, single)
    end
end

function InvSlot:UseItem()
    if self.tile ~= nil and self.tile.item ~= nil then
		local inventory = self.owner and self.owner.replica.inventory
        if inventory ~= nil then
            inventory:UseItemFromInvTile(self.tile.item)
        end
    end
end

function InvSlot:Inspect()
    if self.tile ~= nil and self.tile.item ~= nil then
		local inventory = self.owner and self.owner.replica.inventory
        if inventory ~= nil then
            inventory:InspectItemFromInvTile(self.tile.item)
        end
    end
end

--------------------------------------------------------------------------

function InvSlot:ConvertToConstructionSlot(ingredient, amount)
    if ingredient ~= nil then
        self:SetBGImage2(ingredient:GetAtlas(), ingredient:GetImage(), { 1, 1, 1, .4 })
        self.highlight_scale = 1.7

        local function onquantitychanged(tile, quantity)
            self:SetLabel(
                string.format("%i/%i", amount + quantity, ingredient.amount),
                (amount + quantity >= ingredient.amount and { .25, .75, .25, 1 }) or
                (quantity > 0 and { 1, 1, 1, 1 }) or
                { .7, .7, .7, 1 }
            )
            --return true skips updating the item tile's stack counter display
            return true
        end

        local function ontilechanged(self, tile)
            if tile ~= nil then
                self.bgimage2:Hide()
                tile:SetOnQuantityChangedFn(onquantitychanged)
                if tile.item == nil then
                    --should not happend
                    onquantitychanged(tile, 0)
                elseif tile.item.replica.stackable ~= nil then
                    tile:SetQuantity(tile.item.replica.stackable:StackSize())
                else
                    onquantitychanged(tile, 1)
                end
            else
                self.bgimage2:Show()
                onquantitychanged(nil, 0)
            end
        end

        self:SetOnTileChangedFn(ontilechanged)
        ontilechanged(self, self.tile)
    else
        self:SetBGImage2()
        self:SetLabel()
        self:SetOnTileChangedFn()
        self.highlight_scale = 1.6

        if self.tile ~= nil then
            self.tile:SetOnQuantityChangedFn()
            if self.tile.item ~= nil and self.tile.item.replica.stackable ~= nil then
                self.tile:SetQuantity(self.tile.item.replica.stackable:StackSize())
            end
        end
    end

    self.base_scale = 1.5
    self:SetScale(self.base_scale)
end

return InvSlot
