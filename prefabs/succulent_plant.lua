local assets =
{
    Asset("ANIM", "anim/succulent.zip"),
}

local assets_inv =
{
    Asset("ANIM", "anim/succulent_picked.zip"),
    Asset("ANIM", "anim/meat_rack_food_petals.zip"),
}

local prefabs =
{
    "succulent_picked",
}

local prefabs_inv =
{
    "spoiled_food",
    "succulent_picked_dried",
}

local function SetupPlant(inst, plantid)
    if inst.plantid == nil then
        inst.plantid = plantid or math.random(5)
    end

    if inst.plantid == 1 then
        inst.AnimState:ClearOverrideSymbol("Symbol_1")
    else
        inst.AnimState:OverrideSymbol("Symbol_1", "succulent", "Symbol_"..tostring(inst.plantid))
    end
end

local function onsave(inst, data)
    data.plantid = inst.plantid
end

local function onload(inst, data)
    SetupPlant(inst, data ~= nil and data.plantid or nil)
end

local function plantfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("succulent")
    inst.AnimState:SetBuild("succulent")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("succulent")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("pickable")
    inst.components.pickable.picksound = "dontstarve/wilson/pickup_plants"
    inst.components.pickable:SetUp("succulent_picked")
	inst.components.pickable.remove_when_picked = true
    inst.components.pickable.quickpick = true

    MakeSmallBurnable(inst)
    MakeSmallPropagator(inst)

    MakeHauntableIgnite(inst)

    --------SaveLoad
    inst.OnSave = onsave
    inst.OnLoad = onload

    inst:DoTaskInTime(0, SetupPlant)

    return inst
end

local function invfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("succulent_picked")
    inst.AnimState:SetBuild("succulent_picked")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("cattoy")
	--dryable (from dryable component) added to pristine state for optimization
	inst:AddTag("dryable")

    MakeInventoryFloatable(inst, "med", nil, 0.8)

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

    inst:AddComponent("edible")
    inst.components.edible.healthvalue = TUNING.HEALING_TINY
    inst.components.edible.hungervalue = 0
    inst.components.edible.foodtype = FOODTYPE.VEGGIE

    inst:AddComponent("perishable")
    inst.components.perishable:SetPerishTime(TUNING.PERISH_FAST)
    inst.components.perishable:StartPerishing()
    inst.components.perishable.onperishreplacement = "spoiled_food"

    inst:AddComponent("dryable")
    inst.components.dryable:SetProduct("succulent_picked_dried")
    inst.components.dryable:SetDryTime(TUNING.DRY_FAST)
	inst.components.dryable:SetBuildFile("meat_rack_food_petals")
    inst.components.dryable:SetDriedBuildFile("meat_rack_food_petals")

    MakeHauntableLaunchAndIgnite(inst)

    return inst
end

return Prefab("succulent_plant", plantfn, assets, prefabs),
    Prefab("succulent_picked", invfn, assets_inv, prefabs_inv)
