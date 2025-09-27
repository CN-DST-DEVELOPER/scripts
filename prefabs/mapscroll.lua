local assets =
{
    Asset("ANIM", "anim/mapscroll.zip"),
    Asset("ANIM", "anim/mapscroll_cave.zip"),
    Asset("INV_IMAGE", "mapscroll_cave"),
}

local function OnBuilt(inst, builder)
    inst.components.maprecorder:RecordMap(builder)
end

local function OnTeach(inst, learner)
    learner:PushEvent("learnmap", { map = inst })
end

local function OnDataChanged(inst)
    local maprecorder = inst.components.maprecorder

    inst.components.inspectable:SetDescription(
        maprecorder:HasData() and
        subfmt(STRINGS.MAPRECORDER.MAPDESC, {
            author = maprecorder.mapauthor or STRINGS.MAPRECORDER.UNKNOWN_AUTHOR,
            day = maprecorder.mapday ~= nil and tostring(maprecorder.mapday) or STRINGS.MAPRECORDER.UNKNOWN_DAY,
            location = maprecorder.maplocation ~= nil and STRINGS.MAPRECORDER.LOCATION[string.upper(maprecorder.maplocation)] or STRINGS.MAPRECORDER.LOCATION.DEFAULT,
        }) or
        nil
    )

    if maprecorder.maplocation == "cave" then
        inst.AnimState:SetBuild("mapscroll_cave")
        inst.components.inventoryitem:ChangeImageName("mapscroll_cave")
    else
        inst.AnimState:SetBuild("mapscroll")
        if inst.prefab == "mapscroll" then
            inst.components.inventoryitem:ChangeImageName()
        else
            inst.components.inventoryitem:ChangeImageName("mapscroll")
        end
    end
end

local function common_clientfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("mapscroll")
    inst.AnimState:SetBuild(TheWorld.worldprefab == "cave" and "mapscroll_cave" or "mapscroll")
    inst.AnimState:PlayAnimation("idle")

    MakeInventoryFloatable(inst, "med", nil, 0.85)

    inst:AddTag("mapscroll")

    return inst
end

local function common_serverfn(inst)
    inst:AddComponent("tradable")
    inst:AddComponent("inspectable")
    inst:AddComponent("erasablepaper")

    inst:AddComponent("maprecorder")
    inst.components.maprecorder:SetOnTeachFn(OnTeach)
    inst.components.maprecorder:SetOnDataChangedFn(OnDataChanged)

    inst:AddComponent("inventoryitem")
    if TheWorld.worldprefab == "cave" then
        inst.components.inventoryitem:ChangeImageName("mapscroll_cave")
    end

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL

    MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
    MakeSmallPropagator(inst)

    MakeHauntableLaunch(inst)

    inst.OnBuiltFn = OnBuilt
end

local function fn()
    local inst = common_clientfn()

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end
    common_serverfn(inst)

    return inst
end

local function fn_tricker()
    local inst = common_clientfn()

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end
    common_serverfn(inst)
    inst.components.inspectable.nameoverride = "mapscroll"
    inst.components.inventoryitem:ChangeImageName("mapscroll")

    return inst
end

return Prefab("mapscroll", fn, assets),
    Prefab("mapscroll_tricker", fn_tricker, assets)
