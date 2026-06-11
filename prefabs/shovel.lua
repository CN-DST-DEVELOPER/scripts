local assets =
{
    Asset("ANIM", "anim/shovel.zip"),
    Asset("ANIM", "anim/swap_shovel.zip"),
}

local gold_assets =
{
    Asset("ANIM", "anim/goldenshovel.zip"),
    Asset("ANIM", "anim/swap_goldenshovel.zip"),
}

local fumarole_assets =
{
    Asset("ANIM", "anim/fumaroleshovel.zip"),
    Asset("INV_IMAGE", "fumaroleshovel_2"),
    Asset("INV_IMAGE", "fumaroleshovel_3"),
    Asset("INV_IMAGE", "fumaroleshovel_4"),
}

local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
end

---------------------------------------------------------------------------------------

local function MakeShovel(name, common_postinit, master_postinit, data, _assets, _prefabs)
    local bank = data ~= nil and data.bank or "shovel"
    local build = data ~= nil and data.build or "shovel"
    local anim = data ~= nil and data.anim or "idle"
    local swap_build = data ~= nil and data.swap_build or "swap_shovel"
    local sym_name = data ~= nil and data.sym_name or "swap_shovel"
    local nofiniteuses = data ~= nil and data.nofiniteuses or nil
    local maxfiniteuses = data ~= nil and data.maxfiniteuses or TUNING.SHOVEL_USES
    local floater_scale = data ~= nil and data.floater_scale or {0.8, 0.4, 0.8}
    local floater_swap_data = { sym_build = swap_build, sym_name = sym_name, anim = anim }

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

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(anim)

        --tool (from tool component) added to pristine state for optimization
        inst:AddTag("tool")

        if TheNet:GetServerGameMode() ~= "quagmire" then
            --weapon (from weapon component) added to pristine state for optimization
            inst:AddTag("weapon")
        end

        MakeInventoryFloatable(inst, "med", 0.05, floater_scale, true, 7, floater_swap_data)

        if common_postinit ~= nil then
            common_postinit(inst)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        -----
        inst:AddComponent("tool")
        inst.components.tool:SetAction(ACTIONS.DIG)

        if TheNet:GetServerGameMode() ~= "quagmire" then
            if not nofiniteuses then
                local finiteuses = inst:AddComponent("finiteuses")
                finiteuses:SetMaxUses(maxfiniteuses)
                finiteuses:SetUses(maxfiniteuses)
                finiteuses:SetOnFinished(inst.Remove)
                finiteuses:SetConsumption(ACTIONS.DIG, 1)
            end

            -------
            inst:AddComponent("weapon")
            inst.components.weapon:SetDamage(TUNING.SHOVEL_DAMAGE)
        end

        inst:AddInherentAction(ACTIONS.DIG)

        inst:AddComponent("equippable")
        inst.components.equippable:SetOnEquip(_OnEquip)
        inst.components.equippable:SetOnUnequip(_OnUnequip)

        MakeHauntableLaunch(inst)

        if master_postinit ~= nil then
            master_postinit(inst)
        end

        return inst
    end

    return Prefab(name, fn, _assets, _prefabs)
end

------------------------------------------------------------

local GOLD_DATA =
{
    bank = "goldenshovel",
    build = "goldenshovel",
    swap_build = "swap_goldenshovel",
    sym_name = "swap_goldenshovel",
}

local function PlayGoldSound(inst, data)
    if data and data.owner then
        data.owner.SoundEmitter:PlaySound("dontstarve/wilson/equip_item_gold")
    end
end

local function gold_master_postinit(inst)
    inst.components.finiteuses:SetConsumption(ACTIONS.DIG, 1 / TUNING.GOLDENTOOLFACTOR)
    inst.components.weapon.attackwear = 1 / TUNING.GOLDENTOOLFACTOR

    inst:ListenForEvent("equipped", PlayGoldSound)
end

------------------------------------------------------------

local function fumarole_OnEquipFn(inst, owner)
    local temprange = inst.components.fumaroletool:GetTempRange()
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_fumaroleshovel_"..temprange, inst.GUID, "fumaroleshovel")
    else
        owner.AnimState:OverrideSymbol("swap_object", "fumaroleshovel", "swap_fumaroleshovel_"..temprange)
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
    bank = "fumaroleshovel",
    build = "fumaroleshovel",
    anim = "idle_1",
    swap_build = "fumaroleshovel",
    sym_name = "swap_fumaroleshovel_1", -- for floater
    maxfiniteuses = TUNING.FUMAROLETOOL_NUMUSES,
    onequipfn = fumarole_OnEquipFn,
    onunequipfn = fumarole_OnUnequipFn,
}

local function fumarole_onrepaired(inst)
	inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.HANDS
	inst.components.equippable:SetOnEquip(fumarole_OnEquipFn)
	inst.components.equippable:SetOnUnequip(OnUnequip)

    inst:AddComponent("tool")
	inst.components.tool:SetAction(ACTIONS.DIG)

	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(TUNING.AXE_DAMAGE)
end

local FUMAROLE_SWAP_DATA_BROKEN = { sym_build = "fumaroleshovel", anim = "broken" }

local function fumarole_onbroken(inst)
	inst:RemoveComponent("equippable")
	inst:RemoveComponent("tool")
	inst:RemoveComponent("weapon")
    inst.components.floater:SetBankSwapOnFloat(false, nil, FUMAROLE_SWAP_DATA_BROKEN)
end

local function fumarole_updatetemperaturerange(inst, owner, temprange)
    local light_override = TUNING.FUMAROLETOOL_LIGHTOVERRIDES[temprange]
    local anim = "idle_"..temprange
    local sym_name = "swap_fumaroleshovel_"..temprange

    inst.AnimState:SetLightOverride(light_override)
    local skin_name = inst:GetSkinName() or "fumaroleshovel"
    inst.components.inventoryitem:ChangeImageName(skin_name .. (temprange == 1 and "" or ("_"..temprange)))
    inst.components.floater:SetBankSwapOnFloat(true, 7, { sym_build = "fumaroleshovel", sym_name = sym_name, anim = anim })
    if inst.components.floater:IsFloating() then
        inst.components.floater:SwitchToFloatAnim()
    elseif not inst.AnimState:IsCurrentAnimation("repair") then
        inst.AnimState:PlayAnimation(anim)
    end

    inst.components.tool:SetAction(ACTIONS.DIG, TUNING.FUMAROLESHOVEL_EFFECTIVENESS[temprange])
    if owner ~= nil and inst.components.equippable:IsEquipped() then
        local skin_build = inst:GetSkinBuild()
        if skin_build ~= nil then
            owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, sym_name, inst.GUID, "fumaroleshovel")
        else
            owner.AnimState:OverrideSymbol("swap_object", "fumaroleshovel", sym_name)
        end
        owner.AnimState:SetSymbolLightOverride("swap_object", light_override)
    end
end

local function fumarole_common_postinit(inst)
    MakeFumaroleToolPristine(inst)
end

local function fumarole_master_postinit(inst)
    MakeFumaroleTool(inst, TUNING.FUMAROLESHOVEL_HEAT_ON_USE, fumarole_onbroken, fumarole_onrepaired, fumarole_updatetemperaturerange)
end

------------------------------------------------------------

return MakeShovel("shovel", nil, nil, nil, assets),
    MakeShovel("goldenshovel", nil, gold_master_postinit, GOLD_DATA, gold_assets),
    MakeShovel("fumaroleshovel", fumarole_common_postinit, fumarole_master_postinit, FUMAROLE_DATA, fumarole_assets)