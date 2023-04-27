local assets =
{
	Asset("ANIM", "anim/sword_lunarplant.zip"),
}

local prefabs =
{
	"sword_lunarplant_blade_fx",
	"hitsparks_fx",
}

local function GetSetBonusEquip(inst, owner)
	if owner.components.inventory ~= nil then
		local hat = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
		local body = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
		return hat ~= nil and hat.prefab == "lunarplanthat" and hat or nil,
			body ~= nil and body.prefab == "armor_lunarplant" and body or nil
	end
end

local function SetFxOwner(inst, owner)
	if owner ~= nil then
		inst.blade1.entity:SetParent(owner.entity)
		inst.blade2.entity:SetParent(owner.entity)
		inst.blade1.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true, nil, 0, 3)
		inst.blade2.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true, nil, 5, 8)
		inst.blade1.components.highlightchild:SetOwner(owner)
		inst.blade2.components.highlightchild:SetOwner(owner)
	else
		inst.blade1.entity:SetParent(inst.entity)
		inst.blade2.entity:SetParent(inst.entity)
		--For floating
		inst.blade1.Follower:FollowSymbol(inst.GUID, "swap_spear", nil, nil, nil, true, nil, 0, 3)
		inst.blade2.Follower:FollowSymbol(inst.GUID, "swap_spear", nil, nil, nil, true, nil, 5, 8)
		inst.blade1.components.highlightchild:SetOwner(inst)
		inst.blade2.components.highlightchild:SetOwner(inst)
	end
end

local function PushIdleLoop(inst)
	inst.AnimState:PushAnimation("idle")
end

local function OnStopFloating(inst)
	inst.blade1.AnimState:SetFrame(0)
	inst.blade2.AnimState:SetFrame(0)
	inst:DoTaskInTime(0, PushIdleLoop) --#V2C: #HACK restore the looping anim, timing issues
end

local function onequip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_sword_lunarplant", inst.GUID, "sword_lunarplant")
	else
		owner.AnimState:OverrideSymbol("swap_object", "sword_lunarplant", "swap_sword_lunarplant")
	end
	owner.AnimState:Show("ARM_carry")
	owner.AnimState:Hide("ARM_normal")
	SetFxOwner(inst, owner)

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
	SetFxOwner(inst, nil)

	inst.components.weapon:SetDamage(inst.base_damage)
	inst.components.planardamage:RemoveBonus(inst, "setbonus")
end

local function OnAttack(inst, attacker, target)
	if target ~= nil and target:IsValid() then
		SpawnPrefab("hitsparks_fx"):Setup(attacker, target)
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("sword_lunarplant")
	inst.AnimState:SetBuild("sword_lunarplant")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetSymbolBloom("pb_energy_loop01")
	inst.AnimState:SetSymbolLightOverride("pb_energy_loop01", .5)
	inst.AnimState:SetLightOverride(.1)

	inst:AddTag("sharp")

	--weapon (from weapon component) added to pristine state for optimization
	inst:AddTag("weapon")

	local swap_data = { sym_build = "sword_lunarplant", sym_name = "swap_sword_lunarplant" }
	MakeInventoryFloatable(inst, "med", 0.05, { 1, 0.4, 1 }, true, -17.5, swap_data)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	local frame = math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1
	inst.AnimState:SetFrame(frame)
	inst.blade1 = SpawnPrefab("sword_lunarplant_blade_fx")
	inst.blade2 = SpawnPrefab("sword_lunarplant_blade_fx")
	inst.blade2.AnimState:PlayAnimation("swap_loop2", true)
	inst.blade1.AnimState:SetFrame(frame)
	inst.blade2.AnimState:SetFrame(frame)
	SetFxOwner(inst, nil)
	inst:ListenForEvent("floater_stopfloating", OnStopFloating)

	-------
	inst:AddComponent("finiteuses")
	inst.components.finiteuses:SetMaxUses(TUNING.SWORD_LUNARPLANT_USES)
	inst.components.finiteuses:SetUses(TUNING.SWORD_LUNARPLANT_USES)
	inst.components.finiteuses:SetOnFinished(inst.Remove)

	-------
	inst.lunarplantweapon = true
	inst.base_damage = TUNING.SWORD_LUNARPLANT_DAMAGE
	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(inst.base_damage)
	inst.components.weapon:SetOnAttack(OnAttack)

	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.SWORD_LUNARPLANT_PLANAR_DAMAGE)

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

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	inst.AnimState:SetBank("sword_lunarplant")
	inst.AnimState:SetBuild("sword_lunarplant")
	inst.AnimState:PlayAnimation("swap_loop1", true)
	inst.AnimState:SetSymbolBloom("pb_energy_loop01")
	inst.AnimState:SetSymbolLightOverride("pb_energy_loop01", .5)
	inst.AnimState:SetLightOverride(.1)

	inst:AddComponent("highlightchild")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false

	return inst
end

return Prefab("sword_lunarplant", fn, assets, prefabs),
	Prefab("sword_lunarplant_blade_fx", fxfn, assets)
