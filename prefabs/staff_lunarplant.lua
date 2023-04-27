local assets =
{
	Asset("ANIM", "anim/staff_lunarplant.zip"),
}

local prefabs =
{
	"brilliance_projectile_fx",
	"staff_lunarplant_fx",
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
		inst.fx.entity:SetParent(owner.entity)
		inst.fx.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true)
		inst.fx.components.highlightchild:SetOwner(owner)
	else
		inst.fx.entity:SetParent(inst.entity)
		--For floating
		inst.fx.Follower:FollowSymbol(inst.GUID, "swap_spear", nil, nil, nil, true)
		inst.fx.components.highlightchild:SetOwner(inst)
	end
end

local function PushIdleLoop(inst)
	inst.AnimState:PushAnimation("idle")
end

local function OnStopFloating(inst)
	inst.fx.AnimState:SetFrame(0)
	inst:DoTaskInTime(0, PushIdleLoop) --#V2C: #HACK restore the looping anim, timing issues
end

local function onequip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_staff_lunarplant", inst.GUID, "staff_lunarplant")
	else
		owner.AnimState:OverrideSymbol("swap_object", "staff_lunarplant", "swap_staff_lunarplant")
	end
	owner.AnimState:Show("ARM_carry")
	owner.AnimState:Hide("ARM_normal")
	SetFxOwner(inst, owner)

	local hat, body = GetSetBonusEquip(inst, owner)
	if hat ~= nil and body ~= nil then
		inst.max_bounces = TUNING.STAFF_LUNARPLANT_SETBONUS_BOUNCES
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

	inst.max_bounces = TUNING.STAFF_LUNARPLANT_BOUNCES
end

local function OnAttack(inst, attacker, target, skipsanity)
	if inst.skin_sound then
		attacker.SoundEmitter:PlaySound(inst.skin_sound)
	end

	if not target:IsValid() then
		--target killed or removed in combat damage phase
		return
	end

	if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then
		target.components.sleeper:WakeUp()
	end
	if target.components.combat ~= nil then
		target.components.combat:SuggestTarget(attacker)
	end
	target:PushEvent("attacked", { attacker = attacker, damage = 0, weapon = inst })
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("staff_lunarplant")
	inst.AnimState:SetBuild("staff_lunarplant")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetSymbolBloom("pb_energy_loop")
	inst.AnimState:SetSymbolBloom("stone")
	inst.AnimState:SetSymbolLightOverride("pb_energy_loop01", .5)
	inst.AnimState:SetSymbolLightOverride("pb_ray", .5)
	inst.AnimState:SetSymbolLightOverride("stone", .5)
	inst.AnimState:SetSymbolLightOverride("glow", .25)
	inst.AnimState:SetLightOverride(.1)

	inst:AddTag("rangedweapon")

	--weapon (from weapon component) added to pristine state for optimization
	inst:AddTag("weapon")

	inst.projectiledelay = FRAMES

	local swap_data = { sym_build = "staff_lunarplant", sym_name = "swap_staff_lunarplant" }
	MakeInventoryFloatable(inst, "med", 0.1, { 0.9, 0.6, 0.9 }, true, -13, swap_data)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.lunarplantweapon = true
	inst.max_bounces = TUNING.STAFF_LUNARPLANT_BOUNCES

	local frame = math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1
	inst.AnimState:SetFrame(frame)
	inst.fx = SpawnPrefab("staff_lunarplant_fx")
	inst.fx.AnimState:SetFrame(frame)
	SetFxOwner(inst, nil)
	inst:ListenForEvent("floater_stopfloating", OnStopFloating)

	-------
	inst:AddComponent("finiteuses")
	inst.components.finiteuses:SetMaxUses(TUNING.STAFF_LUNARPLANT_USES)
	inst.components.finiteuses:SetUses(TUNING.STAFF_LUNARPLANT_USES)
	inst.components.finiteuses:SetOnFinished(inst.Remove)

	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(0)
	inst.components.weapon:SetRange(8, 10)
	inst.components.weapon:SetOnAttack(OnAttack)
	inst.components.weapon:SetProjectile("brilliance_projectile_fx")

	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.STAFF_LUNARPLANT_PLANAR_DAMAGE)

	inst:AddComponent("damagetypebonus")
	inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.STAFF_LUNARPLANT_VS_SHADOW_BONUS)

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip(onequip)
	inst.components.equippable:SetOnUnequip(onunequip)

	MakeHauntableLaunch(inst)

	inst.noplanarhitfx = true

	return inst
end

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	inst.AnimState:SetBank("staff_lunarplant")
	inst.AnimState:SetBuild("staff_lunarplant")
	inst.AnimState:PlayAnimation("swap_loop", true)
	inst.AnimState:SetSymbolBloom("pb_energy_loop")
	inst.AnimState:SetSymbolBloom("stone")
	inst.AnimState:SetSymbolLightOverride("pb_energy_loop01", .5)
	inst.AnimState:SetSymbolLightOverride("pb_ray", .5)
	inst.AnimState:SetSymbolLightOverride("stone", .5)
	inst.AnimState:SetSymbolLightOverride("glow", .25)
	inst.AnimState:SetLightOverride(.1)

	inst:AddComponent("highlightchild")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false

	return inst
end

return Prefab("staff_lunarplant", fn, assets, prefabs),
	Prefab("staff_lunarplant_fx", fxfn, assets)
