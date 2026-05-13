--V2C: This is for triggering UI animations on clients for when receiving items into
--     closed containers. This happens now mainly for specialized containers like WX
--     spatial circuit box.
--     isclosed: Box stays closed, so animate the box's icon.
--     otherwise: Box is forced open, so we can animate the item into the box.

local function OnItemDirty(inst)
	local parent = inst.entity:GetParent()
	local item = inst.item:value()
	if parent and item then
		if inst.isclosed:value() then
			local container = item.replica.container
			if container and not container:IsOpenedBy(ThePlayer) then
				inst._data =
				{
					item = item,
					isclosed = inst.isclosed:value(),
				}
				parent._receiveitemonopen = inst._data
				item:PushEvent("container_got_item_while_closed")
			end
		else
			inst._data = 
			{
				item = item,
				isstack = inst.isstack:value(),
			}
			parent._receiveitemonopen = inst._data
		end
	end
end

local function OnRemoveEntity(inst)
	local parent = inst.entity:GetParent()
	if parent and parent._receiveitemonopen == inst._data then
		parent._receiveitemonopen = nil
	end
end

local function fn()
	local inst = CreateEntity()

	if TheWorld.ismastersim then
		inst.entity:AddTransform() --So we can follow parent's sleep state
	end
	inst.entity:AddNetwork()
	inst.entity:Hide()
	inst:AddTag("CLASSIFIED")

	inst.item = net_entity(inst.GUID, "container_closed_receiveitem_classified.item", "itemdirty")
	inst.isstack = net_bool(inst.GUID, "container_closed_receiveitem_classified.isstack")
	inst.isclosed = net_bool(inst.GUID, "container_closed_receiveitem_classified.isclosed", "itemdirty")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("itemdirty", OnItemDirty)
		inst.OnRemoveEntity = OnRemoveEntity

	    return inst
	end

	inst.persists = false
	inst:DoTaskInTime(0.2, inst.Remove)

	return inst
end

return Prefab("container_closed_receiveitem_classified", fn)
