local assets =
{
    Asset("ANIM", "anim/umbrella_voidcloth.zip"),
}

local prefabs =
{
    "voidcloth_umbrella_fx",
}

local function OnIsAcidRaining(inst, isacidraining)
    if isacidraining then
        inst.components.fueled.rate_modifiers:SetModifier(inst, -1, "acidrain")
    else
        inst.components.fueled.rate_modifiers:RemoveModifier(inst, "acidrain")
    end
end

local function OnEquip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_umbrella", inst.GUID, "umbrella_voidcloth")
	else
		owner.AnimState:OverrideSymbol("swap_object", "umbrella_voidcloth", "swap_umbrella")
	end
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    owner.DynamicShadow:SetSize(2.2, 1.4)

	if inst._fx ~= nil then
		inst._fx:Remove()
	end
    inst._fx = SpawnPrefab("voidcloth_umbrella_fx")
	inst._fx:AttachToOwner(owner)

    inst.components.fueled:StartConsuming()
    inst:WatchWorldState("isacidraining", inst.OnIsAcidRaining)
    inst:OnIsAcidRaining(TheWorld.state.isacidraining)
end

local function OnUnequip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("unequipskinneditem", inst:GetSkinName())
	end
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

    owner.DynamicShadow:SetSize(1.3, 0.6)

    if inst._fx ~= nil then
        inst._fx:Remove()
        inst._fx = nil
    end

    inst.components.fueled:StopConsuming()
    inst:StopWatchingWorldState("isacidraining", inst.OnIsAcidRaining)
end

local function OnEquipToModel(inst, owner, from_ground)
    if inst.components.fueled then
        inst.components.fueled:StopConsuming()
    end
    inst:StopWatchingWorldState("isacidraining", inst.OnIsAcidRaining)
end

local function OnPerish(inst)
    local equippable = inst.components.equippable
    if equippable ~= nil and equippable:IsEquipped() then
        local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
        if owner ~= nil then
            local data =
            {
                prefab = inst.prefab,
                equipslot = equippable.equipslot,
            }
            inst:Remove()
            owner:PushEvent("umbrellaranout", data)
            return
        end
    end
    inst:Remove()
end


local function UmbrellaFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("umbrella_voidcloth")
    inst.AnimState:SetBuild("umbrella_voidcloth")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("nopunch")
    inst:AddTag("umbrella")
    inst:AddTag("acidrainimmune")

    --waterproofer (from waterproofer component) added to pristine state for optimization
    inst:AddTag("waterproofer")

	--shadowlevel (from shadowlevel component) added to pristine state for optimization
	inst:AddTag("shadowlevel")

	inst:AddTag("shadow_item")

	MakeInventoryFloatable(inst, "large", nil, {.75, 0.35, 1})

    inst.Transform:SetScale(1.3, 1.3, 1.3)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("tradable")
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst:AddComponent("equippable")

    inst:AddComponent("waterproofer")
    inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_ABSOLUTE)

    inst:AddComponent("insulator")
    inst.components.insulator:SetSummer()
    inst.components.insulator:SetInsulation(TUNING.INSULATION_LARGE)

    inst:AddComponent("fueled")
    inst.components.fueled.fueltype = FUELTYPE.USAGE
    inst.components.fueled:SetDepletedFn(OnPerish)
    inst.components.fueled:InitializeFuelLevel(TUNING.VOIDCLOTH_UMBRELLA_PERISHTIME)

    inst.components.equippable.dapperness = -TUNING.DAPPERNESS_MED
	inst.components.equippable.is_magic_dapperness = true
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable:SetOnEquipToModel(OnEquipToModel)

	inst.components.floater:SetBankSwapOnFloat(true, -36, {sym_name = "swap_umbrella_float", sym_build = "umbrella_voidcloth", bank = "umbrella_voidcloth"})

	inst:AddComponent("shadowlevel")
	inst.components.shadowlevel:SetDefaultLevel(TUNING.VOIDCLOTH_UMBRELLA_SHADOW_LEVEL)

    MakeHauntableLaunch(inst)

    inst.OnIsAcidRaining = OnIsAcidRaining -- Mods.

    return inst
end

local function CreateFxFollowFrame()
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst:AddTag("FX")

	inst.AnimState:SetBank("umbrella_voidcloth")
	inst.AnimState:SetBuild("umbrella_voidcloth")
	inst.AnimState:PlayAnimation("swap_loop1", true)
	inst.AnimState:SetSymbolLightOverride("lightning", 1)

	inst:AddComponent("highlightchild")

	inst.persists = false

	return inst
end

local function FxOnRemoveEntity(inst)
	inst.fx:Remove()
end

local function FxOnEntityReplicated(inst)
	local owner = inst.entity:GetParent()
	if owner ~= nil then
		inst.fx = CreateFxFollowFrame()
		inst.fx.entity:SetParent(owner.entity)
		inst.fx.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true, nil, 5, 8)
		inst.fx.components.highlightchild:SetOwner(owner)
		inst.OnRemoveEntity = FxOnRemoveEntity
	end
end

local function FxAttachToOwner(inst, owner)
	inst.entity:SetParent(owner.entity)
	inst.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true, nil, 0, 2)
	inst.components.highlightchild:SetOwner(owner)

	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		FxOnEntityReplicated(inst)
	end
end

local function FollowSymbolFxFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

	inst.AnimState:SetBank("umbrella_voidcloth")
    inst.AnimState:SetBuild("umbrella_voidcloth")
    inst.AnimState:PlayAnimation("swap_loop1", true)
    inst.AnimState:SetSymbolLightOverride("lightning", 1)

    inst:AddComponent("highlightchild")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
		inst.OnEntityReplicated = FxOnEntityReplicated

        return inst
    end

	inst.AttachToOwner = FxAttachToOwner
    inst.persists = false

    return inst
end

return
        Prefab("voidcloth_umbrella",    UmbrellaFn,       assets, prefabs),
        Prefab("voidcloth_umbrella_fx", FollowSymbolFxFn, assets         )
