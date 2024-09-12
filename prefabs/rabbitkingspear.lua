local assets = {
    Asset("ANIM", "anim/rabbitkingspear.zip"),
    Asset("ANIM", "anim/swap_rabbitkingspear.zip"),
}

local function onequip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_rabbitkingspear", inst.GUID, "swap_rabbitkingspear")
    else
        owner.AnimState:OverrideSymbol("swap_object", "swap_rabbitkingspear", "swap_rabbitkingspear")
    end
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
end

local function onattack(inst, owner, target)
    if target and target:HasTag("manrabbit") then
        if owner.components.sanity ~= nil then
            owner.components.sanity:DoDelta(TUNING.RABBITKINGSPEAR_SANITY_DELTA)
        end
    end
end

local function DamageCalculator(inst, attacker, target)
    local damage = TUNING.RABBITKINGSPEAR_DAMAGE
    if target and target:HasTag("manrabbit") then
        damage = damage * TUNING.RABBITKINGSPEAR_DAMAGE_BONUS
    end
    return damage
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("rabbitkingspear")
    inst.AnimState:SetBuild("rabbitkingspear")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("shadow_item")
    inst:AddTag("sharp")
    inst:AddTag("manrabbitscarer")

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")

    --shadowlevel (from shadowlevel component) added to pristine state for optimization
    inst:AddTag("shadowlevel")

    local swap_data = {sym_build = "swap_rabbitkingspear"}
    MakeInventoryFloatable(inst, "large", 0.05, {0.8, 0.35, 0.8}, true, -27, swap_data)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_weapondamage = { TUNING.RABBITKINGSPEAR_DAMAGE, TUNING.RABBITKINGSPEAR_DAMAGE * TUNING.RABBITKINGSPEAR_DAMAGE_BONUS }

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(DamageCalculator)
    inst.components.weapon.onattack = onattack

    -------

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(TUNING.RABBITKINGSPEAR_USES)
    inst.components.finiteuses:SetUses(TUNING.RABBITKINGSPEAR_USES)
    inst.components.finiteuses:SetOnFinished(inst.Remove)

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable.dapperness = TUNING.CRAZINESS_SMALL
    inst.components.equippable.is_magic_dapperness = true

	inst:AddComponent("shadowlevel")
	inst.components.shadowlevel:SetDefaultLevel(TUNING.RABBITKINGSPEAR_SHADOW_LEVEL)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("rabbitkingspear", fn, assets)
