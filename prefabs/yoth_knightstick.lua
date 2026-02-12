local assets =
{
    Asset("ANIM", "anim/yoth_knightstick.zip"),
}

local function OnEquip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "yoth_knightstick", inst.GUID, "swap_knightstick")
    else
        owner.AnimState:OverrideSymbol("swap_object", "yoth_knightstick", "swap_knightstick")
    end

    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    if inst._owner ~= nil then
        inst:RemoveEventCallback("locomote", inst._onlocomote, inst._owner)
    end
    inst._owner = owner
    inst:ListenForEvent("locomote", inst._onlocomote, owner)
end

local function OnUnequip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end

    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

    if inst._owner ~= nil then
        inst:RemoveEventCallback("locomote", inst._onlocomote, inst._owner)
        inst._owner = nil
    end

    inst.components.fueled:StopConsuming()
end

local FLOATER_SCALE = { 0.85, 0.45, 0.85 }
local FLOATER_SWAP_DATA = { sym_build = "yoth_knightstick", sym_name = "swap_knightstick" }
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("yoth_knightstick")
    inst.AnimState:SetBuild("yoth_knightstick")
    inst.AnimState:PlayAnimation("idle")

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")

    inst:AddTag("gallopstick")

    MakeInventoryFloatable(inst, "med", 0.05, FLOATER_SCALE, true, 1, FLOATER_SWAP_DATA)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_subcat = "tool"

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    -- inst.components.equippable.walkspeedmult = TUNING.CANE_SPEED_MULT

    inst:AddComponent("fueled")
    inst.components.fueled.fueltype = FUELTYPE.USAGE
    inst.components.fueled.no_sewing = true
    inst.components.fueled:SetDepletedFn(inst.Remove)
    inst.components.fueled:InitializeFuelLevel(TUNING.YOTH_KNIGHTSTICK_PERISHTIME)

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.CANE_DAMAGE)

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.LARGE_FUEL

    inst._onlocomote = function(owner)
        if owner.components.locomotor.wantstomoveforward then
            if not inst.components.fueled.consuming then
                inst.components.fueled:StartConsuming()
            end
        elseif inst.components.fueled.consuming then
            inst.components.fueled:StopConsuming()
        end
    end

    MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
    MakeSmallPropagator(inst)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("yoth_knightstick", fn, assets)
