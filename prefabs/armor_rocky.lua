local assets =
{
    Asset("ANIM", "anim/armor_rocky.zip"),
}

local function OnBlocked(owner)
    owner.SoundEmitter:PlaySound("dontstarve/wilson/hit_rockyboss")
end

local function OnKnockbackBlocked(owner)
    if owner.components.rider and owner.components.rider:IsRiding() then
        local armor = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
        armor.components.armor:TakeDamage(TUNING.ARMOR_ROCKY_KNOCKBACK_BLOCKED_DAMAGE)
    end
end

local function OnEquip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "armor_rocky")
    else
		owner.AnimState:OverrideSymbol("swap_body", "armor_rocky", "swap_body")
    end

    inst:ListenForEvent("blocked", OnBlocked, owner)
    inst:ListenForEvent("knockbackblocked", OnKnockbackBlocked, owner)
end

local function OnUnequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
    inst:RemoveEventCallback("blocked", OnBlocked, owner)
    inst:RemoveEventCallback("knockbackblocked", OnKnockbackBlocked, owner)

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("armor_rocky")
    inst.AnimState:SetBuild("armor_rocky")
    inst.AnimState:PlayAnimation("idle")

	inst:AddTag("heavyarmor")
	inst:AddTag("hardarmor")
    inst:AddTag("superheavyarmor")

    inst.foleysound = "dontstarve/movement/foley/rockyboss_armor"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetSinks(true)

    inst:AddComponent("armor")
    inst.components.armor:InitCondition(TUNING.ARMOR_ROCKY, TUNING.ARMOR_ROCKY_ABSORPTION)

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable.walkspeedmult = TUNING.ARMOR_ROCKY_SLOW

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("armor_rocky", fn, assets)
