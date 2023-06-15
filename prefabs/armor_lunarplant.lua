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

local function OnEnabledSetBonus(inst)
	inst.components.damagetyperesist:AddResist("lunar_aligned", inst, TUNING.ARMOR_LUNARPLANT_SETBONUS_LUNAR_RESIST, "setbonus")
end

local function OnDisabledSetBonus(inst)
	inst.components.damagetyperesist:RemoveResist("lunar_aligned", inst, "setbonus")
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

	if inst.fx ~= nil then
		inst.fx:Remove()
	end
	inst.fx = SpawnPrefab("armor_lunarplant_glow_fx")
	inst.fx:AttachToOwner(owner)
	owner.AnimState:SetSymbolLightOverride("swap_body", .1)
end

local function onunequip(inst, owner)
	owner.AnimState:ClearOverrideSymbol("swap_body")
	inst:RemoveEventCallback("blocked", OnBlocked, owner)

	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("unequipskinneditem", inst:GetSkinName())
	end

	if inst.fx ~= nil then
		inst.fx:Remove()
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

	local setbonus = inst:AddComponent("setbonus")
	setbonus:SetSetName(EQUIPMENTSETNAMES.LUNARPLANT)
	setbonus:SetOnEnabledFn(OnEnabledSetBonus)
	setbonus:SetOnDisabledFn(OnDisabledSetBonus)

	MakeHauntableLaunch(inst)

	return inst
end

--------------------------------------------------------------------------

local function CreateFxFollowFrame(i)
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst:AddTag("FX")

	inst.AnimState:SetBank("armor_lunarplant")
	inst.AnimState:SetBuild("armor_lunarplant")
	inst.AnimState:PlayAnimation("idle"..tostring(i), true)
	inst.AnimState:SetSymbolBloom("glowcentre")
	inst.AnimState:SetSymbolLightOverride("glowcentre", .5)
	inst.AnimState:SetLightOverride(.1)

	inst:AddComponent("highlightchild")

	inst.persists = false

	return inst
end

local function glow_OnRemoveEntity(inst)
	for i, v in ipairs(inst.fx) do
		v:Remove()
	end
end

local function glow_SpawnFxForOwner(inst, owner)
	inst.fx = {}
	local frame
	for i = 1, 6 do
		local fx = CreateFxFollowFrame(i)
		frame = frame or math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1
		fx.entity:SetParent(owner.entity)
		fx.Follower:FollowSymbol(owner.GUID, "swap_body", nil, nil, nil, true, nil, i - 1)
		fx.AnimState:SetFrame(frame)
		fx.components.highlightchild:SetOwner(owner)
		table.insert(inst.fx, fx)
	end
	inst.OnRemoveEntity = glow_OnRemoveEntity
end

local function glow_OnEntityReplicated(inst)
	local owner = inst.entity:GetParent()
	if owner ~= nil then
		glow_SpawnFxForOwner(inst, owner)
	end
end

local function glow_AttachToOwner(inst, owner)
	inst.entity:SetParent(owner.entity)
	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		glow_SpawnFxForOwner(inst, owner)
	end
end

local function glowfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst.OnEntityReplicated = glow_OnEntityReplicated

		return inst
	end

	inst.AttachToOwner = glow_AttachToOwner
	inst.persists = false

	return inst
end

return Prefab("armor_lunarplant", fn, assets, prefabs),
	Prefab("armor_lunarplant_glow_fx", glowfn, assets)
