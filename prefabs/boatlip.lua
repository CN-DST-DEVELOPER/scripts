local assets =
{
    Asset("ANIM", "anim/boat_test.zip"),
}

local grass_assets =
{
    Asset("ANIM", "anim/boat_grass.zip"),
}

local ice_assets =
{
    Asset("ANIM", "anim/boat_ice.zip"),
}

local prefabs =
{
}

local function commonfn(bank, build)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("NOBLOCK")
    inst:AddTag("DECOR")

    inst.AnimState:SetBank(bank or "boat_01")
    inst.AnimState:SetBuild(build or "boat_test")
    inst.AnimState:PlayAnimation("lip", true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
    inst.AnimState:SetLayer(LAYER_BELOW_GROUND)
    inst.AnimState:SetSortOrder(ANIM_SORT_ORDER_BELOW_GROUND.BOAT_LIP)
    inst.AnimState:SetFinalOffset(0)
    inst.AnimState:SetOceanBlendParams(TUNING.OCEAN_SHADER.EFFECT_TINT_AMOUNT)
    inst.AnimState:SetInheritsSortKey(false)

    inst.Transform:SetRotation(90)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

local function fn()
    return commonfn()
end

local function grassfn()
    return commonfn("boat_grass", "boat_grass")
end

local function icefn()
    return commonfn("boat_ice", "boat_ice")
end

return Prefab("boatlip", fn, assets, prefabs),
    Prefab("boatlip_grass", grassfn, grass_assets, prefabs),
    Prefab("boatlip_ice", icefn, ice_assets, prefabs)
