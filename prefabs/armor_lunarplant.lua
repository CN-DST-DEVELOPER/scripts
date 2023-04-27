local assets =
{
	Asset("ANIM", "anim/armor_lunarplant.zip"),
}

local prefabs =
{
	"armor_lunarplant_glow_fx",
}

local function OnBlocked(owner)
	owner.SoundEmitter:PlaySound("dontstarve/common/together/armor/cactus")
end

local function GetSetBonusEquip(inst, owner)
	if owner.components.inventory ~= nil then
		local hat = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
		local weapon = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		return hat ~= nil and hat.prefab == "lunarplanthat" and hat or nil,
			weapon ~= nil and weapon.lunarplantweapon and weapon or nil
	end
end

local function onequip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "armor_lunarplant")
	else
		owner.AnimState:OverrideSymbol("swap_body", "armor_lunarplant", "swap_body")
	end

	inst:ListenForEvent("blocked", OnBlocked, owner)

	local hat, weapon = GetSetBonusEquip(inst, owner)
	if hat ~= nil then
		inst.components.damagetyperesist:AddResist("lunar_aligned", inst, TUNING.ARMOR_LUNARPLANT_SETBONUS_LUNAR_RESIST, "setbonus")
		hat.components.damagetyperesist:AddResist("lunar_aligned", hat, TUNING.ARMOR_LUNARPLANT_SETBONUS_LUNAR_RESIST, "setbonus")
		if weapon ~= nil then
			if weapon.base_damage ~= nil then
				weapon.components.weapon:SetDamage(weapon.base_damage * TUNING.WEAPONS_LUNARPLANT_SETBONUS_DAMAGE_MULT)
				weapon.components.planardamage:AddBonus(weapon, TUNING.WEAPONS_LUNARPLANT_SETBONUS_PLANAR_DAMAGE, "setbonus")
			end
			if weapon.max_bounces ~= nil then
				weapon.max_bounces = TUNING.STAFF_LUNARPLANT_SETBONUS_BOUNCES
			end
		end
	end

	if inst.fx == nil then
		inst.fx = {}
		for i = 1, 6 do
			local fx = SpawnPrefab("armor_lunarplant_glow_fx")
			if i > 1 then
				fx.AnimState:PlayAnimation("idle"..tostring(i), true)
			end
			table.insert(inst.fx, fx)
		end
	end
	local frame = math.random(inst.fx[1].AnimState:GetCurrentAnimationNumFrames()) - 1
	for i, v in ipairs(inst.fx) do
		v.entity:SetParent(owner.entity)
		v.Follower:FollowSymbol(owner.GUID, "swap_body", nil, nil, nil, true, nil, i - 1)
		v.AnimState:SetFrame(frame)
		v.components.highlightchild:SetOwner(owner)
	end
	owner.AnimState:SetSymbolLightOverride("swap_body", .1)
end

local function onunequip(inst, owner)
	owner.AnimState:ClearOverrideSymbol("swap_body")
	inst:RemoveEventCallback("blocked", OnBlocked, owner)

	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("unequipskinneditem", inst:GetSkinName())
	end

	local hat, weapon = GetSetBonusEquip(inst, owner)
	if hat ~= nil then
		hat.components.damagetyperesist:RemoveResist("lunar_aligned", hat, "setbonus")
	end
	inst.components.damagetyperesist:RemoveResist("lunar_aligned", inst, "setbonus")
	if weapon ~= nil then
		if weapon.base_damage ~= nil then
			weapon.components.weapon:SetDamage(weapon.base_damage)
			weapon.components.planardamage:RemoveBonus(weapon, "setbonus")
		end
		if weapon.max_bounces ~= nil then
			weapon.max_bounces = TUNING.STAFF_LUNARPLANT_BOUNCES
		end
	end

	if inst.fx ~= nil then
		for i, v in ipairs(inst.fx) do
			v:Remove()
		end
		inst.fx = nil
	end
	owner.AnimState:SetSymbolLightOverride("swap_body", 0)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst:AddTag("lunarplant")
	inst:AddTag("gestaltprotection")

	inst.AnimState:SetBank("armor_lunarplant")
	inst.AnimState:SetBuild("armor_lunarplant")
	inst.AnimState:PlayAnimation("anim")

	inst.foleysound = "dontstarve/movement/foley/lunarplantarmour_foley"

	local swap_data = { bank = "armor_lunarplant", anim = "anim" }
	MakeInventoryFloatable(inst, "small", 0.2, 0.80, nil, nil, swap_data)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	inst:AddComponent("armor")
	inst.components.armor:InitCondition(TUNING.ARMOR_LUNARPLANT, TUNING.ARMOR_LUNARPLANT_ABSORPTION)

	inst:AddComponent("planardefense")
	inst.components.planardefense:SetBaseDefense(TUNING.ARMOR_LUNARPLANT_PLANAR_DEF)

	inst:AddComponent("equippable")
	inst.components.equippable.equipslot = EQUIPSLOTS.BODY
	inst.components.equippable:SetOnEquip(onequip)
	inst.components.equippable:SetOnUnequip(onunequip)

	inst:AddComponent("damagetyperesist")
	inst.components.damagetyperesist:AddResist("lunar_aligned", inst, TUNING.ARMOR_LUNARPLANT_LUNAR_RESIST)

	MakeHauntableLaunch(inst)

	return inst
end

local function glowfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	inst.AnimState:SetBank("armor_lunarplant")
	inst.AnimState:SetBuild("armor_lunarplant")
	inst.AnimState:PlayAnimation("idle1", true)
	inst.AnimState:SetSymbolBloom("glowcentre")
	inst.AnimState:SetSymbolLightOverride("glowcentre", .5)
	inst.AnimState:SetLightOverride(.1)

	inst:AddComponent("highlightchild")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false

	return inst
end

return Prefab("armor_lunarplant", fn, assets, prefabs),
	Prefab("armor_lunarplant_glow_fx", glowfn, assets)
