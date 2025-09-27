local assets =
{
    Asset("ANIM", "anim/lunar_seed.zip"),
}

local function seedfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst, 1, .5)

    inst.AnimState:SetBuild("lunar_seed")
    inst.AnimState:SetBank("lunar_seed")
    inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetSymbolLightOverride("pb_energy_loop", 0.5)
	inst.AnimState:SetSymbolLightOverride("pb_ray", 0.5)
	inst.AnimState:SetSymbolLightOverride("SparkleBit", 0.5)
	inst.AnimState:SetSymbolLightOverride("lunar_seed_loop", 0.15)

    MakeInventoryFloatable(inst, nil, 0.13, 0.9)

    inst:AddTag("lunarseed")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")

    inst:AddComponent("tradable")

    inst:AddComponent("stackable")

	MakeHauntableLaunch(inst)

    return inst
end

return Prefab("lunar_seed", seedfn, assets)