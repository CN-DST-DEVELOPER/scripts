local assets =
{
    Asset("ANIM", "anim/torso_dragonfly.zip"),
}

local function OnBlocked(owner, data, inst)
	if not ShouldProcOnAttackedOrBlocked(inst, owner, data) then
		return
	end
    owner.SoundEmitter:PlaySound("dontstarve/wilson/hit_scalemail")
    if data.attacker ~= nil and
        not (data.attacker.components.health ~= nil and data.attacker.components.health:IsDead()) and
		not IsRangedWeapon(data.weapon) and
        data.attacker.components.burnable ~= nil and
        not data.redirected and
        not data.attacker:HasTag("thorny") then
        data.attacker.components.burnable:Ignite(nil,nil,owner)
    end
end

local function onequip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "torso_dragonfly")
    else
        owner.AnimState:OverrideSymbol("swap_body", "torso_dragonfly", "swap_body")
    end

	if inst._onblocked == nil then
		inst._onblocked = function(owner, data) OnBlocked(owner, data, inst) end
	end
	inst:ListenForEvent("blocked", inst._onblocked, owner)
	inst:ListenForEvent("attacked", inst._onblocked, owner)

    if owner.components.health ~= nil then
        owner.components.health.externalfiredamagemultipliers:SetModifier(inst, 1 - TUNING.ARMORDRAGONFLY_FIRE_RESIST)
    end
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")

	inst:RemoveEventCallback("blocked", inst._onblocked, owner)
	inst:RemoveEventCallback("attacked", inst._onblocked, owner)
	inst._onblocked = nil

    if owner.components.health ~= nil then
        owner.components.health.externalfiredamagemultipliers:RemoveModifier(inst)
    end

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

    inst.AnimState:SetBank("torso_dragonfly")
    inst.AnimState:SetBuild("torso_dragonfly")
    inst.AnimState:PlayAnimation("anim")

    local swap_data = {bank = "torso_dragonfly", anim = "anim"}
    MakeInventoryFloatable(inst, "small", 0.2, 0.80, nil, nil, swap_data)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("armor")
    inst.components.armor:InitCondition(TUNING.ARMORDRAGONFLY, TUNING.ARMORDRAGONFLY_ABSORPTION)

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable.dapperness = TUNING.DAPPERNESS_MED

    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("armordragonfly", fn, assets)
