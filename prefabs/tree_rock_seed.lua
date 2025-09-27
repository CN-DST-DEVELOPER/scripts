require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/tree_rock_seed.zip"),
}

local prefabs =
{
    "tree_rock_sapling",
    "spoiled_food",
}

local function OnDeploy(inst, pt)
    inst = inst.components.stackable:Get()
    inst:Remove()

    local sapling = SpawnPrefab("tree_rock_sapling")
    sapling:StartGrowing()
    sapling.Transform:SetPosition(pt:Get())
    sapling.SoundEmitter:PlaySound("dontstarve/wilson/plant_tree")
end

local function CanDeploy(inst, pt, mouseover, deployer, rot)
    local tile = TheWorld.Map:GetTileAtPoint(pt:Get())
    if not TileGroupManager:IsLandTile(tile) then
        return false
    end

    if TileGroupManager:IsTemporaryTile(tile) then
        return false
    end

    if not TheWorld.Map:IsDeployPointClear(pt, inst, inst.replica.inventoryitem:DeploySpacingRadius()) then
        return false
    end

    return true
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("tree_rock_seed")
    inst.AnimState:SetBuild("tree_rock_seed")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("deployedplant")
    inst:AddTag("icebox_valid")
    inst:AddTag("cattoy")
    inst:AddTag("show_spoilage")
    inst:AddTag("treeseed")

    MakeInventoryFloatable(inst, "small", 0.15)

    inst._custom_candeploy_fn = CanDeploy

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("tradable")

    inst:AddComponent("perishable")
    inst.components.perishable:SetPerishTime(TUNING.PERISH_MED)
    inst.components.perishable:StartPerishing()
    inst.components.perishable.onperishreplacement = "spoiled_food"

    inst:AddComponent("edible")
    inst.components.edible.hungervalue = TUNING.CALORIES_TINY
    inst.components.edible.healthvalue = TUNING.HEALING_TINY
    inst.components.edible.foodtype = FOODTYPE.RAW

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("deployable")
    inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM)
    inst.components.deployable:SetDeploySpacing(DEPLOYSPACING.PLACER_DEFAULT)
    inst.components.deployable.ondeploy = OnDeploy

    --inst:AddComponent("winter_treeseed") --Maybe some day?
    --inst.components.winter_treeseed:SetTree("winter_deciduoustree")

    inst:AddComponent("forcecompostable")
    inst.components.forcecompostable.brown = true

    MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
    MakeSmallPropagator(inst)
    MakeHauntableLaunchAndIgnite(inst)

    return inst
end

return Prefab("tree_rock_seed", fn, assets, prefabs),
       MakePlacer("tree_rock_seed_placer", "tree_rock_seed", "tree_rock_seed", "idle_planted")