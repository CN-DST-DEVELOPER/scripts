local assets =
{
    Asset("ANIM", "anim/flower_petals.zip"),
}

local prefabs =
{
    "small_puff",
    "petals_evil",
}

local function OnHaunt(inst, haunter)
    if math.random() > TUNING.HAUNT_CHANCE_HALF then
        return false
    end

    local x, y, z = inst.Transform:GetWorldPosition()

    SpawnPrefab("small_puff").Transform:SetPosition(x, y, z)

    local new = SpawnPrefab("petals_evil")
    if new then
        new.Transform:SetPosition(x, y, z)

        local stackable = inst.components.stackable
        local new_stackable = new.components.stackable
        if new_stackable and stackable and stackable:IsStack() then
            new_stackable:SetStackSize(stackable:StackSize())
        end

        local inventoryitem = inst.components.inventoryitem
        local new_inventoryitem = new.components.inventoryitem
        if new_inventoryitem and inventoryitem then
            new_inventoryitem:InheritMoisture(inventoryitem:GetMoisture(), inventoryitem:IsWet())
        end

        local perishable = inst.components.perishable
        local new_perishable = new.components.perishable
        if new_perishable and perishable then
            new_perishable:SetPercent(perishable:GetPercent())
        end

        new:PushEvent("spawnedfromhaunt", { haunter = haunter, oldPrefab = inst })
        inst:PushEvent("despawnedfromhaunt", { haunter = haunter, newPrefab = new })

        inst.persists = false
        inst.entity:Hide()

        inst:DoTaskInTime(0, inst.Remove)
    end

    inst.components.hauntable.hauntvalue = TUNING.HAUNT_SMALL
    return true
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("petals")
    inst.AnimState:SetBuild("flower_petals")
    inst.AnimState:PlayAnimation("anim")

    inst.pickupsound = "vegetation_grassy"

    inst:AddTag("cattoy")
    inst:AddTag("vasedecoration")

    MakeInventoryFloatable(inst)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --
    local edible = inst:AddComponent("edible")
    edible.healthvalue = TUNING.HEALING_TINY
    edible.hungervalue = 0
    edible.foodtype = FOODTYPE.VEGGIE

    --
    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.TINY_FUEL

    --
    inst:AddComponent("inspectable")

    --
    inst:AddComponent("inventoryitem")

    --
    local perishable = inst:AddComponent("perishable")
    perishable:SetPerishTime(TUNING.PERISH_FAST)
    perishable:StartPerishing()
    perishable.onperishreplacement = "spoiled_food"

    --
    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    --
    inst:AddComponent("tradable")

    --
    local upgrader = inst:AddComponent("upgrader")
    upgrader.upgradetype = UPGRADETYPES.GRAVESTONE

    --
    inst:AddComponent("vasedecoration")

    MakeSmallBurnable(inst, TUNING.TINY_BURNTIME)
    MakeSmallPropagator(inst)

	inst:AddComponent("snowmandecor")

    MakeHauntableLaunchAndPerish(inst)
    AddHauntableCustomReaction(inst, OnHaunt, false, true, false)

    return inst
end

return Prefab("petals", fn, assets, prefabs)
