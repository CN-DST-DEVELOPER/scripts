require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/bullkelp.zip"),
    Asset("INV_IMAGE", "kullkelp_root"),
}

local prefabs =
{
    "kelp",
    "bullkelp_root",
}

local function ReplaceOnPickup(inst, container, src_pos)
    local moisture, wet = inst.components.inventoryitem:GetMoisture(), inst.components.inventoryitem:IsWet()

	inst:Remove()

	if container then
		local kelp = SpawnPrefab("kelp")
		local root = SpawnPrefab("bullkelp_root")

		kelp.components.inventoryitem:InheritMoisture(moisture, wet)
		root.components.inventoryitem:InheritMoisture(moisture, wet)

		if src_pos then
			kelp.Transform:SetPosition(src_pos:Get())
			root.Transform:SetPosition(src_pos:Get())
		end

		container:GiveItem(kelp, nil, src_pos)
		container:GiveItem(root, nil, src_pos)
	end
end

local function onpickup(inst, pickupguy, src_pos)
	ReplaceOnPickup(inst, pickupguy.components.inventory, src_pos)
	return true -- True because inst was removed.
end

local function onputininventory(inst, owner)
	--V2C: -backup if we made it into a container and skipped OnPickup.
	--     -this happens if Woby picks things up since she doesn't have
	--      inventory component.
	--NOTE: won't reach here if we did reach OnPickup, as we would have
	--      been removed already.
	ReplaceOnPickup(inst, owner.components.container or owner.components.inventory, inst:GetPosition())
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("bullkelp")
    inst.AnimState:SetBuild("bullkelp")
    inst.AnimState:PlayAnimation("dropped_beached")

    MakeInventoryFloatable(inst)

    inst:SetPrefabNameOverride("BULLKELP_PLANT")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
	inst.components.inventoryitem:SetOnPickupFn(onpickup)
	inst.components.inventoryitem:SetOnPutInInventoryFn(onputininventory)

    MakeMediumBurnable(inst, TUNING.LARGE_BURNTIME)
    MakeSmallPropagator(inst)

    MakeHauntableIgnite(inst)

    return inst
end

return Prefab("bullkelp_beachedroot", fn, assets, prefabs)
