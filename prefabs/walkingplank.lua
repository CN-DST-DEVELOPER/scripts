local assets =
{
    Asset("ANIM", "anim/boat_plank.zip"),
    Asset("ANIM", "anim/boat_plank_build.zip"),
}

local assets_grass =
{
    Asset("ANIM", "anim/boat_plank.zip"),
    Asset("ANIM", "anim/boat_plank_grass_build.zip"),
}

local assets_yotd =
{
    Asset("ANIM", "anim/boat_plank.zip"),
    Asset("ANIM", "anim/boat_plank_yotd_build.zip"),
}

local prefabs =
{
    "collapse_small",
}

local function common_pre(inst)
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:SetStateGraph("SGwalkingplank")

    inst.AnimState:SetBank("plank")
    inst.AnimState:SetBuild("boat_plank_build")
    inst.AnimState:SetSortOrder(ANIM_SORT_ORDER.OCEAN_BOAT)
    inst.AnimState:SetFinalOffset(2)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)

    -- from walkingplank component
    inst:AddTag("walkingplank")

    inst:AddTag("ignorewalkableplatforms") -- because it is a child of the boat

    return inst
end

local function common_pst(inst)
    inst.persists = false

    local hauntable = inst:AddComponent("hauntable")
    hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    inst:AddComponent("inspectable")

    -- The loot that this drops is generated from the uncraftable recipe; see recipes.lua for the items.
    inst:AddComponent("lootdropper")

    inst:AddComponent("walkingplank")

    return inst
end


local function fn()
    local inst = common_pre(CreateEntity())

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst = common_pst(inst)

    return inst
end

local function grassfn()
    local inst = common_pre(CreateEntity())

    inst.AnimState:SetBuild("boat_plank_grass_build")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst = common_pst(inst)

    return inst
end

local function yotdfn()
    local inst = common_pre(CreateEntity())

    inst.AnimState:SetBuild("boat_plank_yotd_build")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst = common_pst(inst)

    return inst
end

return Prefab("walkingplank", fn, assets, prefabs),
        Prefab("walkingplank_grass", grassfn, assets_grass, prefabs),
        Prefab("walkingplank_yotd", yotdfn, assets_yotd, prefabs)
