local assets =
{
    Asset("ANIM", "anim/purebrilliance.zip"),
    Asset("INV_IMAGE", "purebrilliance"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("purebrilliance")
    inst.AnimState:SetBuild("purebrilliance")
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetSymbolLightOverride("pb_energy_loop", .5)
	inst.AnimState:SetSymbolLightOverride("pb_ray", .5)
	inst.AnimState:SetSymbolLightOverride("SparkleBit", .5)
	inst.AnimState:SetLightOverride(.1)

	MakeInventoryFloatable(inst, "small", .1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

    --
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    --
    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    --
    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("purebrilliance", fn, assets)
