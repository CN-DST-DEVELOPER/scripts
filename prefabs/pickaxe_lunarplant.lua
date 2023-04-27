local assets =
{
	Asset("ANIM", "anim/pickaxe_lunarplant.zip"),
}

local function GetSetBonusEquip(inst, owner)
	if owner.components.inventory ~= nil then
		local hat = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
		local body = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
		return hat ~= nil and hat.prefab == "lunarplanthat" and hat or nil,
			body ~= nil and body.prefab == "armor_lunarplant" and body or nil
	end
end

local function onequip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_pickaxe_lunarplant", inst.GUID, "pickaxe_lunarplant")
	else
		owner.AnimState:OverrideSymbol("swap_object", "pickaxe_lunarplant", "swap_pickaxe_lunarplant")
	end
	owner.AnimState:Show("ARM_carry")
	owner.AnimState:Hide("ARM_normal")

	local hat, body = GetSetBonusEquip(inst, owner)
	if hat ~= nil and body ~= nil then
		inst.components.weapon:SetDamage(inst.base_damage * TUNING.WEAPONS_LUNARPLANT_SETBONUS_DAMAGE_MULT)
		inst.components.planardamage:AddBonus(inst, TUNING.WEAPONS_LUNARPLANT_SETBONUS_PLANAR_DAMAGE, "setbonus")
	end
end

local function onunequip(inst, owner)
	owner.AnimState:Hide("ARM_carry")
	owner.AnimState:Show("ARM_normal")
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("unequipskinneditem", inst:GetSkinName())
	end

	inst.components.weapon:SetDamage(inst.base_damage)
	inst.components.planardamage:RemoveBonus(inst, "setbonus")
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("pickaxe_lunarplant")
	inst.AnimState:SetBuild("pickaxe_lunarplant")
	inst.AnimState:PlayAnimation("idle")

	--inst:AddTag("sharp")
	inst:AddTag("hammer")

	--tool (from tool component) added to pristine state for optimization
	inst:AddTag("tool")

	--weapon (from weapon component) added to pristine state for optimization
	inst:AddTag("weapon")

	local swap_data = { sym_build = "pickaxe_lunarplant", sym_name = "swap_pickaxe_lunarplant" }
	MakeInventoryFloatable(inst, "med", 0.05, { 0.75, 0.4, 0.75 }, true, -13, swap_data)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	-------
	inst:AddComponent("tool")
	inst.components.tool:SetAction(ACTIONS.HAMMER, TUNING.PICKAXE_LUNARPLANT_EFFICIENCY)
	inst.components.tool:SetAction(ACTIONS.MINE, TUNING.PICKAXE_LUNARPLANT_EFFICIENCY)

	-------
	inst:AddComponent("finiteuses")
	inst.components.finiteuses:SetMaxUses(TUNING.PICKAXE_LUNARPLANT_USES)
	inst.components.finiteuses:SetUses(TUNING.PICKAXE_LUNARPLANT_USES)
	inst.components.finiteuses:SetOnFinished(inst.Remove)
	inst.components.finiteuses:SetConsumption(ACTIONS.HAMMER, 1)
	inst.components.finiteuses:SetConsumption(ACTIONS.MINE, TUNING.HAMMER_USES / TUNING.PICKAXE_USES)

	-------
	inst.lunarplantweapon = true
	inst.base_damage = TUNING.PICKAXE_LUNARPLANT_DAMAGE
	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(inst.base_damage)

	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.PICKAXE_LUNARPLANT_PLANAR_DAMAGE)

	inst:AddComponent("damagetypebonus")
	inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.WEAPONS_LUNARPLANT_VS_SHADOW_BONUS)

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip(onequip)
	inst.components.equippable:SetOnUnequip(onunequip)

	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("pickaxe_lunarplant", fn, assets)
