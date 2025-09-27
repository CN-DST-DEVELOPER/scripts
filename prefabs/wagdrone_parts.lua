local assets =
{
	Asset("ANIM", "anim/wagdrone_parts.zip"),
	Asset("SCRIPT", "scripts/prefabs/wagdrone_common.lua"),
}

local WagdroneCommon = require("prefabs/wagdrone_common")

local function ResetInUse(inst)
	inst.components.useabletargeteditem:StopUsingItem()
end

local function OnUsed(inst, target, user)
	if target and target:IsValid() and target.persists then
		if target.prefab == "wagdrone_rolling" then
			if target.components.finiteuses == nil then
				WagdroneCommon.ChangeToFriendly(target)
				inst.components.stackable:Get():Remove()
			elseif target.components.finiteuses:GetPercent() < 1 then
				target.components.finiteuses:SetPercent(1)
				WagdroneCommon.OnRepaired(target)
				inst.components.stackable:Get():Remove()
			end
			if inst:IsValid() then
				--We don't need to lock this item as "inuse"
				inst:DoStaticTaskInTime(0, ResetInUse)
			end
			return true
		end
		return false, "CANNOT_FIX_DRONE"
	end
end

local function UseableTargetedItem_ValidTarget(inst, target, doer)
	--_inventoryitem means friendly and repairable
	return target:HasTag("wagdrone") and target:HasAnyTag("HAMMER_workable", "_inventoryitem")
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("wagdrone_parts")
	inst.AnimState:SetBuild("wagdrone_parts")
	inst.AnimState:PlayAnimation("idle")

	inst.pickupsound = "metal"

	MakeInventoryFloatable(inst, "med", 0.5, { 0.75, 1.1, 0.75 })

	inst.UseableTargetedItem_ValidTarget = UseableTargetedItem_ValidTarget

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_MEDITEM

	inst:AddComponent("useabletargeteditem")
	inst.components.useabletargeteditem:SetOnUseFn(OnUsed)

	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("wagdrone_parts", fn, assets)
