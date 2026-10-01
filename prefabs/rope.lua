local assets =
{
    Asset("ANIM", "anim/rope.zip"),
}

local function ResetInUse(inst)
    inst.components.useabletargeteditem:StopUsingItem()
end

local function OnUsedRope(inst, target, doer)
    if target.OnUsedRope then
        local success, reason = target:OnUsedRope(inst, doer)
        if inst:IsValid() then
            --We don't need to lock this item as "inuse"
            inst:DoStaticTaskInTime(0, ResetInUse)
        end
        if success then
            return true
        end
        return success, reason
    end
    return false
end

local function UseableTargetedItem_ValidTarget(inst, target, doer)
    return target:HasTag("canrope")
end

local function GetUseItemOnVerb(inst, target, doer)
    return "TIE_ONTO"
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("rope")
    inst.AnimState:SetBuild("rope")
    inst.AnimState:PlayAnimation("idle")

    inst.pickupsound = "cloth"

    inst:AddTag("cattoy")

    MakeInventoryFloatable(inst, "small", 0.05)

    inst.UseableTargetedItem_ValidTarget = UseableTargetedItem_ValidTarget
    inst.GetUseItemOnVerb = GetUseItemOnVerb

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inventoryitem")

    inst:AddComponent("inspectable")
    inst:AddComponent("stackable")

    MakeSmallBurnable(inst, TUNING.LARGE_BURNTIME)
    MakeSmallPropagator(inst)
    MakeHauntableLaunchAndIgnite(inst)

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.MED_FUEL

    inst:AddComponent("tradable")

    local useabletargeteditem = inst:AddComponent("useabletargeteditem")
    useabletargeteditem:SetOnUseFn(OnUsedRope)

    return inst
end

return Prefab("rope", fn, assets)
