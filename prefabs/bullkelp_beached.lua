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

local function ReplaceOnPickup(inst, pickupguy, src_pos)
    inst:Remove()

    local x, y, z = pickupguy.Transform:GetWorldPosition()

    local kelp = SpawnPrefab("kelp")
    local root = SpawnPrefab("bullkelp_root")

    kelp.Transform:SetPosition(x, 0, z)
    root.Transform:SetPosition(x, 0, z)

    pickupguy.components.inventory:GiveItem(kelp, nil, src_pos)
    pickupguy.components.inventory:GiveItem(root, nil, src_pos)

    return true -- True because inst was removed.
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
    inst.components.inventoryitem:SetOnPickupFn(ReplaceOnPickup)

    MakeMediumBurnable(inst, TUNING.LARGE_BURNTIME)
    MakeSmallPropagator(inst)

    MakeHauntableIgnite(inst)

    return inst
end

return Prefab("bullkelp_beachedroot", fn, assets, prefabs)
