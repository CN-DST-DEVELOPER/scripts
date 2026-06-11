local WX78Common = require("prefabs/wx78_common")

local assets =
{
    Asset("ANIM", "anim/nightmarefuel.zip"),
}

local function ResetInUse(inst)
	inst.components.useabletargeteditem:StopUsingItem()
end

local WX78_BUFF_DATA = { duration = TUNING.SKILLS.WX78.SHADOWFUEL_DEBUFF_TIME }
local function OnUseAsWX78(inst, target, doer)
    if target.components.upgrademoduleowner then
        target:AddDebuff("wx78_shadow_fuel_debuff", "wx78_shadow_fuel_debuff", WX78_BUFF_DATA)
		inst.components.stackable:Get():Remove()
		if inst:IsValid() then
			--We don't need to lock this item as "inuse"
			inst:DoStaticTaskInTime(0, ResetInUse)
		end
        return true
    end
end

local function ValidTargetToConsumeAsWX78(inst, target, doer)
    -- wx
    local socketholder = (target or doer).components.socketholder
    return socketholder ~= nil and (socketholder:GetHighestQualitySocketed(SOCKETNAMES.SHADOW) > SOCKETQUALITY.NONE)
        and ( (target == doer) or (target == nil) )
end

local function GetUseItemOnVerb(inst, target, doer)
    return ValidTargetToConsumeAsWX78(inst, target, doer) and "CONSUME"
        or nil
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("nightmarefuel")
    inst.AnimState:SetBuild("nightmarefuel")
    inst.AnimState:PlayAnimation("idle_loop", true)
    inst.AnimState:SetMultColour(1, 1, 1, 0.5)
    inst.AnimState:UsePointFiltering(true)

	--waterproofer (from waterproofer component) added to pristine state for optimization
	inst:AddTag("waterproofer")

    MakeInventoryFloatable(inst)

    -- before MakeItemSocketable_Client (it handles hooking)
    inst.UseableTargetedItem_ValidTarget = ValidTargetToConsumeAsWX78
    MakeItemSocketable_Client(inst, SOCKETNAMES.SHADOW)

    inst.GetUseItemOnVerb = GetUseItemOnVerb

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- before WX78Common.MakeItemSocketable (it handles hooking)
    inst:AddComponent("useabletargeteditem")
    inst.components.useabletargeteditem:SetOnUseFn(OnUseAsWX78)

    WX78Common.MakeItemSocketable(inst)
    inst.components.socketable:SetSocketQuality(SOCKETQUALITY.LOW)

	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM
    inst:AddComponent("inspectable")
    inst:AddComponent("fuel")
    inst.components.fuel.fueltype = FUELTYPE.NIGHTMARE
    inst.components.fuel.fuelvalue = TUNING.LARGE_FUEL
    inst:AddComponent("repairer")
    inst.components.repairer.repairmaterial = MATERIALS.NIGHTMARE
    inst.components.repairer.finiteusesrepairvalue = TUNING.NIGHTMAREFUEL_FINITEUSESREPAIRVALUE

	inst:AddComponent("waterproofer")
	inst.components.waterproofer:SetEffectiveness(0)

    MakeHauntableLaunch(inst)

    inst:AddComponent("inventoryitem")

    return inst
end

return Prefab("nightmarefuel", fn, assets)