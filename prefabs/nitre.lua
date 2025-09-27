local assets =
{
    Asset("ANIM", "anim/nitre.zip"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("nitre")
    inst.AnimState:SetBuild("nitre")
    inst.AnimState:PlayAnimation("idle")

    inst.pickupsound = "rock"

    inst:AddTag("molebait")
    inst:AddTag("quakedebris")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    local edible = inst:AddComponent("edible")
    edible.foodtype = FOODTYPE.ELEMENTAL
    edible.secondaryfoodtype = FOODTYPE.NITRE
    edible.hungervalue = 2

    inst:AddComponent("tradable")

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.MED_LARGE_FUEL
    inst.components.fuel.fueltype = FUELTYPE.CHEMICAL

    inst:AddComponent("inspectable")

    inst:AddComponent("bait")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetSinks(true)

	inst:AddComponent("snowmandecor")

    MakeHauntableLaunchAndSmash(inst)

    return inst
end

return Prefab("nitre", fn, assets)
