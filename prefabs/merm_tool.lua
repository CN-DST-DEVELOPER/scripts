local regular_assets =
{
    Asset("ANIM", "anim/mermtool.zip"),
    Asset("ANIM", "anim/swap_mermtool.zip"),
}

local upgraded_assets =
{
    Asset("ANIM", "anim/mermtool_upgraded.zip"),
    Asset("ANIM", "anim/swap_mermtool_upgraded.zip"),
}

---------------------------------------------------------------------------------------------------------------------------------

local function OnEquip(inst, owner)
    local skin_build = inst:GetSkinBuild()

    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, inst._swapsymbol, inst.GUID, inst._build)
    else
        owner.AnimState:OverrideSymbol("swap_object", inst._build, inst._swapsymbol)
    end

    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function OnUnequip(inst, owner)
    local skin_build = inst:GetSkinBuild()

    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end

    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

---------------------------------------------------------------------------------------------------------------------------------

local function CreateMermTool(data)
    local function fn()
        local tuning = TUNING[data.tuning]

        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(data.bank)
        inst.AnimState:SetBuild(data.build)
        inst.AnimState:PlayAnimation("idle")

        MakeInventoryFloatable(inst, "med", 0.05, {0.7, 0.4, 0.7}, true, -13, {sym_build = data.build})

        inst:AddTag(data.prefab)

        -- Tool (from tool component) added to pristine state for optimization.
        inst:AddTag("tool")

        -- Weapon (from weapon component) added to pristine state for optimization.
        inst:AddTag("weapon")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst._build = data.build
        inst._swapsymbol = "swap_"..data.bank

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")

        inst:AddComponent("weapon")
        inst.components.weapon:SetDamage(tuning.DAMAGE)

        inst:AddComponent("tool")
        inst.components.tool:SetAction(ACTIONS.CHOP, tuning.EFFICIENCY)
        inst.components.tool:SetAction(ACTIONS.MINE, tuning.EFFICIENCY)
        inst.components.tool:SetAction(ACTIONS.DIG, tuning.EFFICIENCY)
        
        inst:AddInherentAction(ACTIONS.TILL)
        inst:AddComponent("farmtiller")

        inst:AddComponent("equippable")
        inst.components.equippable:SetOnEquip(OnEquip)
        inst.components.equippable:SetOnUnequip(OnUnequip)

        inst:AddComponent("finiteuses")
        inst.components.finiteuses:SetMaxUses(tuning.USES)
        inst.components.finiteuses:SetUses(tuning.USES)
        inst.components.finiteuses:SetConsumption(ACTIONS.CHOP, tuning.CONSUMPTION.CHOP)
        inst.components.finiteuses:SetConsumption(ACTIONS.MINE, tuning.CONSUMPTION.MINE)
        inst.components.finiteuses:SetConsumption(ACTIONS.DIG,  tuning.CONSUMPTION.DIG )
        inst.components.finiteuses:SetConsumption(ACTIONS.TILL, tuning.CONSUMPTION.TILL )
        inst.components.finiteuses:SetOnFinished(inst.Remove)

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab(data.prefab, fn, data.assets)
end

---------------------------------------------------------------------------------------------------------------------------------

return
    CreateMermTool({
        prefab = "merm_tool",
        bank   = "mermtool",
        build  = "mermtool",
        tuning = "MERM_TOOL",
        assets = regular_assets,
    }),

    CreateMermTool({
        prefab = "merm_tool_upgraded",
        bank   = "mermtool_upgraded",
        build  = "mermtool_upgraded",
        tuning = "MERM_TOOL_UPGRADED",
        assets = upgraded_assets,
    })
