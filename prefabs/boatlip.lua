local assets =
{
    Asset("ANIM", "anim/boat_test.zip"),
}

local grass_assets =
{
    Asset("ANIM", "anim/boat_grass.zip"),
}

local prefabs =
{
}

local function commonfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("NOBLOCK")
    inst:AddTag("DECOR")

    inst.AnimState:SetBank("boat_01")
    inst.AnimState:SetBuild("boat_test")
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
    local inst = commonfn()
    return inst
end

local function grassfn()
    local inst = commonfn()

    inst.AnimState:SetBuild("boat_grass")    
    inst.AnimState:SetBank("boat_grass")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end    

    return inst
end

return Prefab("boatlip", fn, assets, prefabs),
    Prefab("boatlip_grass", grassfn, grass_assets, prefabs)
