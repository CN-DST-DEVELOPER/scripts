local assets =
{
    Asset("ANIM", "anim/flower_petals_evil.zip"),
    Asset("ANIM", "anim/meat_rack_food_petals.zip"),
}

local prefabs =
{
    "petals_evil_dried",
    "spoiled_food",
}

local function OnSpawnedFromHaunt(inst, data)
    Launch(inst, data.haunter, TUNING.LAUNCH_SPEED_SMALL)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("flower_petals_evil")
    inst.AnimState:SetBuild("flower_petals_evil")
    inst.AnimState:PlayAnimation("anim")

    inst.pickupsound = "vegetation_grassy"

    MakeInventoryFloatable(inst)

	--dryable (from dryable component) added to pristine state for optimization
	inst:AddTag("dryable")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("tradable")

    inst:AddComponent("inspectable")

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.TINY_FUEL

    MakeSmallBurnable(inst, TUNING.TINY_BURNTIME)
    MakeSmallPropagator(inst)

    inst:AddComponent("inventoryitem")

    inst:AddComponent("edible") --Different effect? Reduce health?
    inst.components.edible.healthvalue = 0
    inst.components.edible.hungervalue = 0
    inst.components.edible.sanityvalue = -TUNING.SANITY_TINY
    inst.components.edible.foodtype = FOODTYPE.VEGGIE

    inst:AddComponent("perishable")
    inst.components.perishable:SetPerishTime(TUNING.PERISH_FAST)
    inst.components.perishable:StartPerishing()
    inst.components.perishable.onperishreplacement = "spoiled_food"

	inst:AddComponent("snowmandecor")

    inst:AddComponent("dryable")
    inst.components.dryable:SetProduct("petals_evil_dried")
    inst.components.dryable:SetDryTime(TUNING.DRY_FAST)
	inst.components.dryable:SetBuildFile("meat_rack_food_petals")
    inst.components.dryable:SetDriedBuildFile("meat_rack_food_petals")

    MakeHauntableLaunchAndPerish(inst)
    inst:ListenForEvent("spawnedfromhaunt", OnSpawnedFromHaunt)

    return inst
end

return Prefab("petals_evil", fn, assets, prefabs)