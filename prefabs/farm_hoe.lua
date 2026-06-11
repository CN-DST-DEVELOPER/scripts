local assets =
{
    Asset("ANIM", "anim/quagmire_hoe.zip"),
}

local golden_assets =
{
    Asset("ANIM", "anim/goldenhoe.zip"),
    Asset("ANIM", "anim/swap_goldenhoe.zip"),
}

local fumarole_assets =
{
    Asset("ANIM", "anim/fumarolehoe.zip"),
    Asset("INV_IMAGE", "fumarole_farm_hoe_2"),
    Asset("INV_IMAGE", "fumarole_farm_hoe_3"),
    Asset("INV_IMAGE", "fumarole_farm_hoe_4"),
}

local prefabs =
{
    "farm_soil",
}

local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
end

local function OnFiniteUsesFinished(inst)
    if inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner ~= nil then
        inst.components.inventoryitem.owner:PushEvent("toolbroke", { tool = inst })
    end

    inst:Remove()
end

-------------------------------------------------------------------------

local function MakeFarmHoe(name, common_postinit, master_postinit, data, _assets, _prefabs)
    local bank = data ~= nil and data.bank or "quagmire_hoe"
    local build = data ~= nil and data.build or "quagmire_hoe"
    local anim = data ~= nil and data.anim or "idle"
    local swap_build = data ~= nil and data.swap_build or "quagmire_hoe"
    local sym_name = data ~= nil and data.sym_name or "swap_quagmire_hoe"
    local nofiniteuses = data ~= nil and data.nofiniteuses or nil
    local maxfiniteuses = data ~= nil and data.maxfiniteuses or TUNING.FARM_HOE_USES
    local floater_scale = data ~= nil and data.floater_scale or {0.8, 0.4, 0.8}
    local floater_swap_data = { bank = bank, sym_build = swap_build, sym_name = sym_name, anim = anim }

    local _OnEquip = (data ~= nil and data.onequipfn) or function(inst, owner)
        local skin_build = inst:GetSkinBuild()
        if skin_build ~= nil then
            owner:PushEvent("equipskinneditem", inst:GetSkinName())
            owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, sym_name, inst.GUID, swap_build)
        else
            owner.AnimState:OverrideSymbol("swap_object", swap_build, sym_name)
        end
        owner.AnimState:Show("ARM_carry")
        owner.AnimState:Hide("ARM_normal")
    end

    local _OnUnequip = (data ~= nil and data.onunequipfn) or OnUnequip

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(build)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(anim)

        inst:AddTag("sharp")

        --weapon (from weapon component) added to pristine state for optimization
        inst:AddTag("weapon")

        MakeInventoryFloatable(inst, "med", 0.05, floater_scale, true, -7, floater_swap_data)

        inst.scrapbook_subcat = "tool"

        if common_postinit ~= nil then
            common_postinit(inst)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")

        inst:AddComponent("equippable")
        inst.components.equippable:SetOnEquip(_OnEquip)
        inst.components.equippable:SetOnUnequip(_OnUnequip)

        inst:AddComponent("weapon")
        inst.components.weapon:SetDamage(TUNING.FARM_HOE_DAMAGE)

        inst:AddInherentAction(ACTIONS.TILL)

        if not nofiniteuses then
            inst:AddComponent("finiteuses")
            inst.components.finiteuses:SetMaxUses(maxfiniteuses)
            inst.components.finiteuses:SetUses(maxfiniteuses)
            inst.components.finiteuses:SetOnFinished(OnFiniteUsesFinished)
            inst.components.finiteuses:SetConsumption(ACTIONS.TILL, 1)
        end

        inst:AddComponent("farmtiller")

        MakeHauntableLaunch(inst)

        if master_postinit ~= nil then
            master_postinit(inst)
        end

        return inst
    end

    return Prefab(name, fn, _assets, _prefabs)
end

-----------------------------------------------------------------------------------------

local GOLD_DATA =
{
    bank = "goldenhoe",
    build = "goldenhoe",
    swap_build = "swap_goldenhoe",
    sym_name = "swap_goldenhoe",
}

local function PlayGoldSound(inst, data)
    if data and data.owner then
        data.owner.SoundEmitter:PlaySound("dontstarve/wilson/equip_item_gold")
    end
end

local function gold_master_postinit(inst)
    inst.components.finiteuses:SetConsumption(ACTIONS.TILL, 1 / TUNING.GOLDENTOOLFACTOR)
    inst.components.weapon.attackwear = 1 / TUNING.GOLDENTOOLFACTOR

    inst:ListenForEvent("equipped", PlayGoldSound)
end

------------------------------------------------------------------------------------

local function fumarole_OnEquipFn(inst, owner)
    local temprange = inst.components.fumaroletool:GetTempRange()
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_fumarolehoe_"..temprange, inst.GUID, "fumarolehoe")
    else
        owner.AnimState:OverrideSymbol("swap_object", "fumarolehoe", "swap_fumarolehoe_"..temprange)
    end
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
    owner.AnimState:SetSymbolLightOverride("swap_object", TUNING.FUMAROLETOOL_LIGHTOVERRIDES[temprange])
end

local function fumarole_OnUnequipFn(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    owner.AnimState:SetSymbolLightOverride("swap_object", 0)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
end

local FUMAROLE_DATA =
{
    bank = "fumarolehoe",
    build = "fumarolehoe",
    anim = "idle_1",
    swap_build = "fumarolehoe",
    sym_name = "swap_fumarolehoe_1", -- for floater
    maxfiniteuses = TUNING.FUMAROLETOOL_NUMUSES,
    onequipfn = fumarole_OnEquipFn,
    onunequipfn = fumarole_OnUnequipFn,
}

local function fumarole_onrepaired(inst)
	inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.HANDS
	inst.components.equippable:SetOnEquip(fumarole_OnEquipFn)
	inst.components.equippable:SetOnUnequip(OnUnequip)

	inst:AddInherentAction(ACTIONS.TILL)
	inst:AddComponent("farmtiller")

	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(TUNING.FARM_HOE_DAMAGE)
end

local FUMAROLE_SWAP_DATA_BROKEN = { bank = "fumarolehoe", sym_build = "fumarolehoe", anim = "broken" }

local function fumarole_onbroken(inst)
	inst:RemoveComponent("equippable")
	inst:RemoveInherentAction(ACTIONS.TILL)
	inst:RemoveComponent("farmtiller")
	inst:RemoveComponent("weapon")
    inst.components.floater:SetBankSwapOnFloat(false, nil, FUMAROLE_SWAP_DATA_BROKEN)
end

local function fumarole_updatetemperaturerange(inst, owner, temprange)
    local light_override = TUNING.FUMAROLETOOL_LIGHTOVERRIDES[temprange]
    local anim = "idle_"..temprange
    local sym_name = "swap_fumarolehoe_"..temprange

    inst.AnimState:SetLightOverride(light_override)
    local skin_name = inst:GetSkinName() or "fumarole_farm_hoe"
    inst.components.inventoryitem:ChangeImageName(skin_name .. (temprange == 1 and "" or ("_"..temprange)))
    inst.components.floater:SetBankSwapOnFloat(true, -7, { bank = "fumarolehoe", sym_build = "fumarolehoe", sym_name = sym_name, anim = anim })
    if inst.components.floater:IsFloating() then
        inst.components.floater:SwitchToFloatAnim()
    elseif not inst.AnimState:IsCurrentAnimation("repair") then
        inst.AnimState:PlayAnimation(anim)
    end

    if owner ~= nil and inst.components.equippable:IsEquipped() then
        local skin_build = inst:GetSkinBuild()
        if skin_build ~= nil then
            owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, sym_name, inst.GUID, "fumarolehoe")
        else
            owner.AnimState:OverrideSymbol("swap_object", "fumarolehoe", sym_name)
        end
        owner.AnimState:SetSymbolLightOverride("swap_object", light_override)
    end
end

local function fumarole_common_postinit(inst)
    MakeFumaroleToolPristine(inst)
end

local function fumarole_master_postinit(inst)
    MakeFumaroleTool(inst, TUNING.FUMAROLEHOE_HEAT_ON_USE, fumarole_onbroken, fumarole_onrepaired, fumarole_updatetemperaturerange)
end

-----------------------------------------------------------------------------------------

return MakeFarmHoe("farm_hoe", nil, nil, nil, assets, prefabs),
    MakeFarmHoe("golden_farm_hoe", nil, gold_master_postinit, GOLD_DATA, golden_assets, prefabs),
    MakeFarmHoe("fumarole_farm_hoe", fumarole_common_postinit, fumarole_master_postinit, FUMAROLE_DATA, fumarole_assets, prefabs)