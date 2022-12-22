local assets =
{
    Asset("ANIM", "anim/x_marks_spot.zip"),
    Asset("MINIMAP_IMAGE", "pirate_stash"),
}

local MAX_LOOTFLING_DELAY = 0.8

local function fling_loot_in_slot(inst, slot)
	local loot = inst.components.inventory:GetItemInSlot(slot)
	if loot ~= nil then
		loot = inst.components.inventory:DropItem(loot, true)
		if loot ~= nil and loot:IsValid() then
			Launch(loot, loot, 2)
		end
	end

	--This way, if saved while we're flinging will just resume as a diggable
	--stash again, with the remaining loot.
	if inst.queued > 1 then
		inst.queued = inst.queued - 1
	else
		inst.components.inventory:DropEverything() --JUST in case
		inst:Remove()
	end
end

local function queue_fling_in_slot(inst, slot)
	inst.queued = (inst.queued or 0) + 1
	inst:DoTaskInTime(MAX_LOOTFLING_DELAY * math.random(), fling_loot_in_slot, slot)
end

local function stash_dug(inst)
	if not inst.flinging then
		inst.flinging = true
		inst:Hide()
		SpawnPrefab("collapse_small").Transform:SetPosition(inst.Transform:GetWorldPosition())

		local inv = inst.components.inventory
		for k in pairs(inv.itemslots) do
			queue_fling_in_slot(inst, k)
		end
	end
end

local function hascopyof(inst, item)
	for k, v in pairs(inst.components.inventory.itemslots) do
		if v ~= item and v.prefab == "blueprint" and v.recipetouse == item.recipetouse then
			return true
		end
	end
	return false
end

local function checkistreasure(inst, item)
	return item.prefab == "blueprint"
		and (item.recipetouse == "pirate_flag_pole" or item.recipetouse == "polly_rogershat")
		and not hascopyof(inst, item)
end

local function stashloot(inst, item)
	if item ~= nil and item:IsValid() then
		local first = inst.nextslot
		repeat
			local olditem = inst.components.inventory:GetItemInSlot(inst.nextslot)
			if olditem ~= nil and not (olditem:HasTag("irreplaceable") or checkistreasure(inst, olditem)) then
				olditem:Remove()
				olditem = nil
			end
			if olditem == nil then
				inst.components.inventory:GiveItem(item, inst.nextslot)
				if inst.flinging then
					queue_fling_in_slot(inst, inst.nextslot)
				end
				inst.nextslot = inst.nextslot < inst.components.inventory.maxslots and inst.nextslot + 1 or 1
				return
			end
		until inst.nextslot == first

		--No open slot
		if not item:HasTag("irreplaceable") then
			item:Remove()
		elseif item.components.inventoryitem ~= nil then
			item.components.inventoryitem:DoDropPhysics(x, 0, z, true)
		elseif item.Physics ~= nil then
			Launch(item, item, 1)
		else
			item.Transform:SetPosition(inst.Transform:GetWorldPosition())
		end
	end
end

local function OnSave(inst, data)
	data.nextslot = inst.nextslot > 1 and inst.nextslot or nil
end

local function OnLoad(inst, data)
	if data ~= nil and data.nextslot ~= nil and data.nextslot <= TUNING.PIRATE_STASH_INV_SIZE then
		inst.nextslot = data.nextslot
	end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddMiniMapEntity()

    inst.MiniMapEntity:SetIcon("pirate_stash.png")

    inst.AnimState:SetBank("x_marks_spot")
    inst.AnimState:SetBuild("x_marks_spot")
    inst.AnimState:PlayAnimation("idle")

	inst:AddTag("irreplaceable")
	inst:AddTag("buried")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst:AddComponent("inspectable")

	inst:AddComponent("inventory")
	inst.components.inventory.maxslots = TUNING.PIRATE_STASH_INV_SIZE

	inst:AddComponent("preserver")
	inst.components.preserver:SetPerishRateMultiplier(0)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.DIG)
    inst.components.workable:SetWorkLeft(1)
    inst.components.workable:SetOnWorkCallback(stash_dug)

    inst:ListenForEvent("onremove", function()
        if TheWorld.components.piratespawner then
            TheWorld.components.piratespawner:ClearCurrentStash()
        end
    end)

	inst.nextslot = 1
    inst.stashloot = stashloot

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

return Prefab("pirate_stash", fn, assets)
