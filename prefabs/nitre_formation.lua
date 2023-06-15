local assets =
{
    Asset("ANIM", "anim/pond_nitrecrystal.zip"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("pond_rock")
    inst.AnimState:SetBuild("pond_nitrecrystal")
    inst.AnimState:PlayAnimation("idle1")
    inst.AnimState:SetScale(0.75, 0.75)

    inst:AddTag("DECOR")
    inst:AddTag("nitre_formation")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    return inst
end

return Prefab("nitre_formation", fn, assets)
