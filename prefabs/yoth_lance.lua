local assets = {
    Asset("ANIM", "anim/yoth_lance.zip"),
}

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", "yoth_lance", "swap_lance")

    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

local function on_uses_finished(inst)
    local owner = inst.components.inventoryitem:GetGrandOwner()
    if owner then
        owner:PushEvent("toolbroke", { tool = inst })
    end

    inst:Remove()
end

local function OnHitOther(inst, owner, target)
    local fx = SpawnPrefab((target:HasTag("largecreature") or target:HasTag("epic")) and "round_puff_fx_lg" or "round_puff_fx_sm")
    fx.Transform:SetPosition(target.Transform:GetWorldPosition())
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("yoth_lance")
    inst.AnimState:SetBuild("yoth_lance")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("nopunch")

    MakeInventoryFloatable(inst, "med", 0.05, {1.1, 0.5, 1.1}, true, -9)

    inst:AddTag("sharp")
    inst:AddTag("pointy")
    inst:AddTag("lancejab")

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.components.floater:SetBankSwapOnFloat(true, -9, { sym_build = "fence_rotator", sym_name = "swap_fence_rotator" })

    local finiteuses = inst:AddComponent("finiteuses")
    finiteuses:SetMaxUses(TUNING.YOTH_LANCE_USES)
    finiteuses:SetUses(TUNING.YOTH_LANCE_USES)
    finiteuses:SetOnFinished(on_uses_finished)

    local weapon = inst:AddComponent("weapon")
    weapon:SetDamage(TUNING.YOTH_LANCE_ATTACK_DAMAGE)
    weapon:SetRange(TUNING.YOTH_LANCE_LENGTH)

    local joustsource = inst:AddComponent("joustsource")
    joustsource:SetSpeed(TUNING.YOTH_LANCE_JOUST_SPEED)
    joustsource:SetLanceLength(TUNING.YOTH_LANCE_LENGTH)
    joustsource:SetRunAnimLoopCount(TUNING.YOTH_LANCE_RUNANIM_LOOP_COUNT)
    joustsource:SetOnHitOtherFn(OnHitOther)

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")

    inst:AddComponent("fencerotator")

    local equippable = inst:AddComponent("equippable")
    equippable:SetOnEquip(onequip)
    equippable:SetOnUnequip(onunequip)

    return inst
end

return Prefab("yoth_lance", fn, assets)