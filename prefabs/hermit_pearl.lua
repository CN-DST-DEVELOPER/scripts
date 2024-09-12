local assets =
{
    Asset("ANIM", "anim/hermit_pearl.zip"),
}

local function commonfn(anim, minimapicon)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()

    if minimapicon ~= nil then
        inst.entity:AddMiniMapEntity()
    end

    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    if minimapicon ~= nil then
        inst.MiniMapEntity:SetIcon(minimapicon..".png")
        inst.MiniMapEntity:SetPriority(7)
    end

    inst:AddTag("irreplaceable")
    inst:AddTag("hermitpearl")

    inst.AnimState:SetBank("hermit_pearl")
    inst.AnimState:SetBuild("hermit_pearl")
    inst.AnimState:PlayAnimation(anim)

    MakeInventoryFloatable(inst, "med", .15, 0.7)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst:AddComponent("tradable")

    MakeHauntableLaunch(inst)

    return inst
end

local function fn()
    local inst = commonfn("idle", "hermit_pearl")

    inst:AddTag("gem")

    return inst
end

local function crackedfn()
    return commonfn("cracked")
end

return
    Prefab("hermit_pearl",         fn,        assets),
    Prefab("hermit_cracked_pearl", crackedfn, assets)