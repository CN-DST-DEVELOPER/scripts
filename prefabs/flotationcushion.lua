local assets =
{
    Asset("ANIM", "anim/flotationcushion.zip"),
}

local function OnEquip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_float", skin_build, "swap_float", inst.GUID, "flotationcushion")
	else
		owner.AnimState:OverrideSymbol("swap_float", "flotationcushion", "swap_float")
	end
	--swap_float anims use ARM_normal and not ARM_carry
	--owner.AnimState:Show("ARM_carry")
	--owner.AnimState:Hide("ARM_normal")
end

local function OnUnequip(inst, owner)
	--swap_float anims use ARM_normal and not ARM_carry
	--owner.AnimState:Hide("ARM_carry")
	--owner.AnimState:Show("ARM_normal")
	if inst:GetSkinBuild() then
		owner:PushEvent("unequipskinneditem", inst:GetSkinName())
	end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("flotationcushion")
    inst.AnimState:SetBuild("flotationcushion")
    inst.AnimState:PlayAnimation("idle")

	MakeInventoryFloatable(inst, "small", 0.1, { 1.1, 1, 1.1 })

	inst:AddTag("cattoy")

	--playerfloater (from playerfloater component) added to pristine state for optimization
	inst:AddTag("playerfloater")

	--Sneak these into pristine state for optimization
	inst:AddTag("__equippable")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	--Remove these tags so that they can be added properly when replicating components below
	inst:RemoveTag("__equippable")

	inst:PrereplicateComponent("equippable")

    --
	inst:AddComponent("playerfloater")
	inst.components.playerfloater:SetOnEquip(OnEquip)
	inst.components.playerfloater:SetOnUnequip(OnUnequip)

    --
    inst:AddComponent("inspectable")

    --
    inst:AddComponent("inventoryitem")

    return inst
end

return Prefab("flotationcushion", fn, assets)
