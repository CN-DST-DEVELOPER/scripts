local assets =
{
    Asset("ANIM", "anim/armor_onemanband.zip"), --naming convention inconsistent
}

local function CalcDapperness(inst, owner)
    local numfollowers = owner.components.leader ~= nil and owner.components.leader:CountFollowers() or 0
    local numpets = owner.components.petleash ~= nil and owner.components.petleash:GetNumPets() or 0
    return -TUNING.DAPPERNESS_SMALL - math.max(0, numfollowers - numpets) * TUNING.SANITYAURA_SMALL
end

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_body_tall", "armor_onemanband", "swap_body_tall")
    inst.components.fueled:StartConsuming()
    inst.components.leaderrollcall:Enable()
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body_tall")
    inst.components.fueled:StopConsuming()
    inst.components.leaderrollcall:Disable()
end

local function onequiptomodel(inst, owner)
    inst.components.fueled:StopConsuming()
    inst.components.leaderrollcall:Disable()
end

local function haunt_foley_delayed(inst)
    inst.SoundEmitter:PlaySound(inst.foleysound)
end
local function OnHaunt(inst)
    inst.components.leaderrollcall:Enable()
    inst.hauntsfxtask = inst:DoPeriodicTask(.3, haunt_foley_delayed)
    return true
end

local function OnUnHaunt(inst)
    inst.components.leaderrollcall:Disable()
    inst.hauntsfxtask:Cancel()
    inst.hauntsfxtask = nil
end

local function OnPutInInventoryFn(inst)
    if inst.components.hauntable:IsHaunted() then
        inst.components.hauntable:StopHaunt()
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst:AddTag("band")

	--shadowlevel (from shadowlevel component) added to pristine state for optimization
	inst:AddTag("shadowlevel")

    inst.AnimState:SetBank("onemanband")
    inst.AnimState:SetBuild("armor_onemanband")
    inst.AnimState:PlayAnimation("anim")

    inst.foleysound = "dontstarve/wilson/onemanband"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetSinks(true)
    inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventoryFn)

    inst:AddComponent("fueled")
    inst.components.fueled.fueltype = FUELTYPE.ONEMANBAND
    inst.components.fueled:InitializeFuelLevel(TUNING.ONEMANBAND_PERISHTIME)
    inst.components.fueled:SetDepletedFn(inst.Remove)

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable.dapperfn = CalcDapperness
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable:SetOnEquipToModel(onequiptomodel)

	inst:AddComponent("shadowlevel")
	inst.components.shadowlevel:SetDefaultLevel(TUNING.ONEMANBAND_SHADOW_LEVEL)

    inst:AddComponent("leader")

    inst:AddComponent("leaderrollcall") -- must be added after inventoryitem
    inst.components.leaderrollcall:SetRadius(TUNING.ONEMANBAND_RANGE)
    inst.components.leaderrollcall:SetMaxFollowers(TUNING.ONEMANBAND_MAXFOLLOWERS)
    inst.components.leaderrollcall:SetCanTendFarmPlant(true)

    inst:AddComponent("hauntable")
    inst.components.hauntable:SetHauntValue(TUNING.HAUNT_SMALL)
    inst.components.hauntable:SetOnHauntFn(OnHaunt)
    inst.components.hauntable:SetOnUnHauntFn(OnUnHaunt)

    return inst
end

return Prefab("onemanband", fn, assets)