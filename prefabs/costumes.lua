local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
end

local function makecostume(name, common_postinit, master_postinit, data)
    local noburn = data ~= nil and data.noburn or nil
    local foleysound = data ~= nil and data.foleysound or "dontstarve/movement/foley/logarmour"

    local assets =
    {
        Asset("ANIM", "anim/"..name..".zip"),
    }

    local function onequip(inst, owner)
        local skin_build = inst:GetSkinBuild()

        if skin_build ~= nil then
            owner:PushEvent("equipskinneditem", inst:GetSkinName())
            owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, name)
        else
            owner.AnimState:OverrideSymbol("swap_body", name, "swap_body")
        end
    end

    local COSTUME_FLOATER_SWAPDATA = { bank = name, anim = "anim" }
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(name)
        inst.AnimState:SetBuild(name)
        inst.AnimState:PlayAnimation("anim")

        inst.foleysound = foleysound

        MakeInventoryFloatable(inst, "small", nil, nil, nil, nil, COSTUME_FLOATER_SWAPDATA)

        inst.scrapbook_specialinfo = "COSTUME"

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
        inst.components.equippable.equipslot = EQUIPSLOTS.BODY
        inst.components.equippable:SetOnEquip(onequip)
        inst.components.equippable:SetOnUnequip(onunequip)

        if not noburn then
            MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
            MakeSmallPropagator(inst)
        end

        MakeHauntableLaunch(inst)

        if master_postinit ~= nil then
            master_postinit(inst)
        end

        return inst
    end

    return Prefab(name, fn, assets)
end

--

local princess_data = { foleysound = "dontstarve/movement/foley/metalarmour", noburn = true }
local function princess_common_postinit(inst)
    inst:AddTag("metal")
    inst:AddTag("hardarmor")
end

local function princess_onsetbonus_enabled(inst)
    inst:AddTag("unluckysource")
end
local function princess_onsetbonus_disabled(inst)
    inst:RemoveTag("unluckysource")
end

local function princess_master_postinit(inst)
    inst:AddComponent("armor")
    inst.components.armor:InitCondition(TUNING.COSTUME_PRINCESS_BODY, TUNING.COSTUME_PRINCESS_BODY_ABSORPTION)

    local setbonus = inst:AddComponent("setbonus")
    setbonus:SetSetName(EQUIPMENTSETNAMES.YOTH_PRINCESS)
    setbonus:SetOnEnabledFn(princess_onsetbonus_enabled)
    setbonus:SetOnDisabledFn(princess_onsetbonus_disabled)
end

return  makecostume("costume_doll_body"),
        makecostume("costume_queen_body"),
        makecostume("costume_king_body"),
        makecostume("costume_blacksmith_body"),
        makecostume("costume_mirror_body"),
        makecostume("costume_tree_body"),
        makecostume("costume_fool_body"),
        -- Year of the Clockwork Knight
        makecostume("costume_princess_body", princess_common_postinit, princess_master_postinit, princess_data)