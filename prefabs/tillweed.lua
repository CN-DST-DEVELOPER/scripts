local assets =
{
    Asset("ANIM", "anim/tillweed.zip"),
    Asset("ANIM", "anim/meat_rack_food_petals.zip"),
}

local prefabs =
{
    "spoiled_food",
    "tillweed_dried",
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("tillweed")
    inst.AnimState:SetBuild("tillweed")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("cattoy")
	--dryable (from dryable component) added to pristine state for optimization
	inst:AddTag("dryable")

    MakeInventoryFloatable(inst, "med", 0.05, 0.68)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inventoryitem")

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("edible")
    inst.components.edible.foodtype = FOODTYPE.VEGGIE
    inst.components.edible.healthvalue = TUNING.HEALING_TINY
    inst.components.edible.hungervalue = 0

    inst:AddComponent("inspectable")
    inst:AddComponent("tradable")

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.TINY_FUEL

    inst:AddComponent("perishable")
    inst.components.perishable:SetPerishTime(TUNING.PERISH_FAST)
    inst.components.perishable:StartPerishing()
    inst.components.perishable.onperishreplacement = "spoiled_food"

    inst:AddComponent("dryable")
    inst.components.dryable:SetProduct("tillweed_dried")
    inst.components.dryable:SetDryTime(TUNING.DRY_FAST)
	inst.components.dryable:SetBuildFile("meat_rack_food_petals")
    inst.components.dryable:SetDriedBuildFile("meat_rack_food_petals")

    MakeSmallBurnable(inst)
    MakeSmallPropagator(inst)

    MakeHauntableLaunchAndIgnite(inst)

    return inst
end

return Prefab("tillweed", fn, assets, prefabs)