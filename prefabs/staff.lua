local assets =
{
    Asset("ANIM", "anim/staffs.zip"),
    Asset("ANIM", "anim/swap_staffs.zip"),
    Asset("SCRIPT", "scripts/prefabs/staff_common.lua"),
}

local stafffns = require("prefabs/staff_common").fns
local prefabs = require("prefabs/staff_common").prefabs

---------COMMON FUNCTIONS---------

local function onfinished(inst)
    inst.SoundEmitter:PlaySound("dontstarve/common/gem_shatter")
    inst:Remove()
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

local function onunequip_skinned(inst, owner)
    if inst:GetSkinBuild() ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end

    onunequip(inst, owner)
end

local function commonfn(colour, suffix, tags, hasskin, hasshadowlevel)
    local anim = colour.."staff"..suffix
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("staffs")
    inst.AnimState:SetBuild("staffs")
    inst.AnimState:PlayAnimation(anim)
    inst.scrapbook_anim = anim

    if tags ~= nil then
        for i, v in ipairs(tags) do
            inst:AddTag(v)
        end
    end

	if hasshadowlevel then
		--shadowlevel (from shadowlevel component) added to pristine state for optimization
		inst:AddTag("shadowlevel")
	end

    local floater_swap_data =
    {
        sym_build = "swap_staffs",
        sym_name = "swap_"..anim,
        bank = "staffs",
        anim = anim,
    }
    MakeInventoryFloatable(inst, "med", 0.1, {0.9, 0.4, 0.9}, true, -13, floater_swap_data)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -------
    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetOnFinished(onfinished)

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")

    inst:AddComponent("tradable")

    inst:AddComponent("equippable")

    if hasskin then
        inst.components.equippable:SetOnEquip(function(inst, owner)
            local skin_build = inst:GetSkinBuild()
            if skin_build ~= nil then
                owner:PushEvent("equipskinneditem", inst:GetSkinName())
                owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_"..anim, inst.GUID, "swap_staffs")
            else
                owner.AnimState:OverrideSymbol("swap_object", "swap_staffs", "swap_"..anim)
            end
            owner.AnimState:Show("ARM_carry")
            owner.AnimState:Hide("ARM_normal")
        end)
        inst.components.equippable:SetOnUnequip(onunequip_skinned)
    else
        inst.components.equippable:SetOnEquip(function(inst, owner)
            owner.AnimState:OverrideSymbol("swap_object", "swap_staffs", "swap_"..anim)
            owner.AnimState:Show("ARM_carry")
            owner.AnimState:Hide("ARM_normal")
        end)
        inst.components.equippable:SetOnUnequip(onunequip)
    end

	if hasshadowlevel then
		inst:AddComponent("shadowlevel")
		inst.components.shadowlevel:SetDefaultLevel(TUNING.STAFF_SHADOW_LEVEL)
	end

    return inst
end

---------COLOUR SPECIFIC CONSTRUCTIONS---------

local function red()
    --weapon (from weapon component) added to pristine state for optimization
	local inst = commonfn("red", "", { "firestaff", "weapon", "rangedweapon", "rangedlighter" }, true, true)

    inst.projectiledelay = FRAMES
    inst.scrapbook_specialinfo = "REDSTAFF"

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_removedeps = { "cutgrass" }

    MakeHauntableLaunch(inst)
    stafffns.red(inst)

    inst.components.finiteuses:SetMaxUses(TUNING.FIRESTAFF_USES)
    inst.components.finiteuses:SetUses(TUNING.FIRESTAFF_USES)

    local floater_swap_data =
    {
        sym_build = "swap_staffs",
        sym_name = "swap_redstaff",
        bank = "staffs",
        anim = "redstaff"
    }
    inst.components.floater:SetBankSwapOnFloat(true, -9.5, floater_swap_data)
    inst.components.floater:SetScale({0.85, 0.4, 0.85})

    return inst
end

local function blue_common(build, coldness)
    --weapon (from weapon component) added to pristine state for optimization
    local suffix = (coldness > 1) and tostring(coldness) or ""
	local inst = commonfn(build, suffix, { "icestaff", "weapon", "rangedweapon", "extinguisher" }, true, true)

    inst.projectiledelay = FRAMES
    inst.icestaff_coldness = coldness or 1

    inst.scrapbook_specialinfo = "BLUESTAFF"

    if not TheWorld.ismastersim then
        return inst
    end

    MakeHauntableLaunch(inst)
    stafffns.blue(inst)

    inst.components.finiteuses:SetMaxUses(TUNING.ICESTAFF_USES)
    inst.components.finiteuses:SetUses(TUNING.ICESTAFF_USES)

    inst.components.floater:SetScale({0.8, 0.4, 0.8})

    return inst
end

local function blue()
    return blue_common("blue", 1)
end
local function blue2()
    return blue_common("blue", 2)
end
local function blue3()
    return blue_common("blue", 3)
end

local function purple()
	local inst = commonfn("purple", "", { "nopunch" }, true, true)

    inst.scrapbook_specialinfo = "PURPLESTAFF"

    if not TheWorld.ismastersim then
        return inst
    end

    MakeHauntableLaunch(inst)
    stafffns.purple(inst)

    inst.components.finiteuses:SetMaxUses(TUNING.TELESTAFF_USES)
    inst.components.finiteuses:SetUses(TUNING.TELESTAFF_USES)

    inst.components.floater:SetScale({0.9, 0.4, 0.9})

    return inst
end

local function yellow()
	local inst = commonfn("yellow", "", { "nopunch", "allow_action_on_impassable" }, true, true)

    stafffns.yellow_client(inst)

    if not TheWorld.ismastersim then
        return inst
    end

    MakeHauntableLaunch(inst)
    stafffns.yellow(inst)

    inst.components.finiteuses:SetMaxUses(TUNING.YELLOWSTAFF_USES)
    inst.components.finiteuses:SetUses(TUNING.YELLOWSTAFF_USES)

    local floater_swap_data =
    {
        sym_build = "swap_staffs",
        sym_name = "swap_yellowstaff",
        bank = "staffs",
        anim = "yellowstaff"
    }
    inst.components.floater:SetBankSwapOnFloat(true, -14, floater_swap_data)

    return inst
end

local function green()
	local inst = commonfn("green", "", { "nopunch" }, true, true)

    if not TheWorld.ismastersim then
        return inst
    end

    MakeHauntableLaunch(inst)
    stafffns.green(inst)

    inst.components.finiteuses:SetMaxUses(TUNING.GREENSTAFF_USES)
    inst.components.finiteuses:SetUses(TUNING.GREENSTAFF_USES)

    return inst
end

local function orange()
    --weapon (from weapon component) added to pristine state for optimization
	local inst = commonfn("orange", "", { "weapon" }, true, true)

    stafffns.orange_client(inst)

    if not TheWorld.ismastersim then
        return inst
    end

    MakeHauntableLaunch(inst)
    stafffns.orange(inst)

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.CANE_DAMAGE) -- NOTES(JBK): This item is created from a cane it should do cane damage.

    inst.components.equippable.walkspeedmult = TUNING.CANE_SPEED_MULT

    inst.components.finiteuses:SetMaxUses(TUNING.ORANGESTAFF_USES)
    inst.components.finiteuses:SetUses(TUNING.ORANGESTAFF_USES)
    inst.components.finiteuses:SetIgnoreCombatDurabilityLoss(true)

    return inst
end

local function opal()
	local inst = commonfn("opal", "", { "nopunch", "allow_action_on_impassable" }, true, false)

    stafffns.opal_client(inst)

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_adddeps = {"moonbase"}

    MakeHauntableLaunch(inst)
    stafffns.opal(inst)

    inst.components.finiteuses:SetMaxUses(TUNING.OPALSTAFF_USES)
    inst.components.finiteuses:SetUses(TUNING.OPALSTAFF_USES)

    local floater_swap_data =
    {
        sym_build = "swap_staffs",
        sym_name = "swap_opalstaff",
        bank = "staffs",
        anim = "opalstaff"
    }
    inst.components.floater:SetBankSwapOnFloat(true, -14, floater_swap_data)

    return inst
end

return Prefab("icestaff", blue, assets, prefabs.blue),
    Prefab("icestaff2", blue2, assets, prefabs.blue2),
    Prefab("icestaff3", blue3, assets, prefabs.blue3),
    Prefab("firestaff", red, assets, prefabs.red),
    Prefab("telestaff", purple, assets, prefabs.purple),
    Prefab("orangestaff", orange, assets, prefabs.orange),
    Prefab("greenstaff", green, assets, prefabs.green),
    Prefab("yellowstaff", yellow, assets, prefabs.yellow),
    Prefab("opalstaff", opal, assets, prefabs.opal)
