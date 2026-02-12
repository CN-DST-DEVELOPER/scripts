local assets =
{
    Asset("ANIM", "anim/armor_yoth_knight.zip"),
}

local function OnBlocked(owner)
    owner.SoundEmitter:PlaySound("dontstarve/wilson/hit_armour")
end

local function OnEquip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "armor_yoth_knight")
    else
		owner.AnimState:OverrideSymbol("swap_body", "armor_yoth_knight", "swap_body")
    end

    inst:ListenForEvent("blocked", OnBlocked, owner)
end

local function OnUnequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
    inst:RemoveEventCallback("blocked", OnBlocked, owner)

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
end

local function OnSetBonusEnabled(inst)
    inst:AddTag("luckysource")
end
local function OnSetBonusDisabled(inst)
    inst:RemoveTag("luckysource")
end

local SWAP_FLOATER_DATA = { bank = "armor_yoth_knight", anim = "anim" }
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("armor_yoth_knight")
    inst.AnimState:SetBuild("armor_yoth_knight")
    inst.AnimState:PlayAnimation("anim")

    inst:AddTag("metal")
    inst:AddTag("hardarmor")

    inst.foleysound = "dontstarve/movement/foley/metalarmour"

    MakeInventoryFloatable(inst, "small", 0.2, 0.80, nil, nil, SWAP_FLOATER_DATA)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")

    inst:AddComponent("armor")
    inst.components.armor:InitCondition(TUNING.ARMOR_YOTH_KNIGHT, TUNING.ARMOR_YOTH_KNIGHT_ABSORPTION)

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)

    local setbonus = inst:AddComponent("setbonus")
	setbonus:SetSetName(EQUIPMENTSETNAMES.YOTH_KNIGHT)
    setbonus:SetOnEnabledFn(OnSetBonusEnabled)
    setbonus:SetOnDisabledFn(OnSetBonusDisabled)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("armor_yoth_knight", fn, assets)