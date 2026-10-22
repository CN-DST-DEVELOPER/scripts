local BALLOONS = require "prefabs/balloons_common"

local assets =
{
    Asset("ANIM", "anim/balloonvest.zip"),
    Asset("SCRIPT", "scripts/prefabs/balloons_common.lua"),
}

local prefabs =
{
	"balloon_pop_body",
}

local function OnOwnerAttackedFn(owner, data, inst)
	if inst.components.poppable and ShouldProcOnAttackedOrBlocked(inst, owner, data) then
		inst.components.poppable:Pop()
    end
end

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_body", "balloonvest", "swap_body")
	inst.components.fueled:StartConsuming()
	if inst._onownerattackedfn == nil then
		inst._onownerattackedfn = function(owner, data) OnOwnerAttackedFn(owner, data, inst) end
	end
	inst:ListenForEvent("attacked", inst._onownerattackedfn, owner)
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
    inst.components.fueled:StopConsuming()
	inst:RemoveEventCallback("attacked", inst._onownerattackedfn, owner)
	inst._onownerattackedfn = nil
end

local function onequiptomodel(inst)
    inst.components.fueled:StopConsuming()
end

local function onpreventdrowningdamagefn(inst)
	inst.components.poppable:Pop()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("balloonvest")
    inst.AnimState:SetBuild("balloonvest")
    inst.AnimState:PlayAnimation("idle")

    MakeInventoryFloatable(inst, "small", 0.1, 0.80)

	inst:AddTag("cattoy")
    inst:AddTag("balloon")
	inst:AddTag("noepicmusic")

    inst.foleysound = "wes/common/foley/balloon_vest"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	BALLOONS.MakeBalloonMasterInit(inst, BALLOONS.DoPop)

    inst:AddComponent("fueled")
    inst.components.fueled.fueltype = FUELTYPE.MAGIC
    inst.components.fueled:InitializeFuelLevel(TUNING.PERISH_ONE_DAY)
	inst.components.fueled:SetDepletedFn(BALLOONS.FueledDepletedPop)

	inst:AddComponent("flotationdevice")
	inst.components.flotationdevice.onpreventdrowningdamagefn = onpreventdrowningdamagefn

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable:SetOnEquipToModel(onequiptomodel)

    return inst
end

return Prefab("balloonvest", fn, assets, prefabs)
