local assets =
{
    Asset("ANIM", "anim/gears.zip"),
}

local function ResetInUse(inst)
	inst.components.useabletargeteditem:StopUsingItem()
end

local function OnUsedOnChess(inst, target, doer)
	if target.TryBefriendChess and target:HasTag("befriendable_clockwork") and target:TryBefriendChess(doer) then
		if target.components.health then
			target.components.health:SetPercent(1)
		end
		if target.components.sleeper then
			target.components.sleeper:WakeUp()
		end
		inst.components.stackable:Get():Remove()
		if inst:IsValid() then
			--We don't need to lock this item as "inuse"
			inst:DoStaticTaskInTime(0, ResetInUse)
		end
		return true
	end
	return false
end

local function UseableTargetedItem_ValidTarget(inst, target, doer)
	if not target:HasTag("befriendable_clockwork") then
		return false
	end
	local follower = target.replica.follower
	return follower ~= nil and follower:GetLeader() == nil
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("gears")
    inst.AnimState:SetBuild("gears")
    inst.AnimState:PlayAnimation("idle")

    inst.pickupsound = "metal"

    inst:AddTag("molebait")

    MakeInventoryFloatable(inst, "med", nil, 0.7)

	inst.UseableTargetedItem_ValidTarget = UseableTargetedItem_ValidTarget

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")

    inst:AddComponent("bait")

    inst:AddComponent("edible")
    inst.components.edible.foodtype = FOODTYPE.GEARS
    inst.components.edible.healthvalue = TUNING.HEALING_HUGE
    inst.components.edible.hungervalue = TUNING.CALORIES_HUGE
    inst.components.edible.sanityvalue = TUNING.SANITY_HUGE

    inst:AddComponent("repairer")
    inst.components.repairer.repairmaterial = MATERIALS.GEARS
    inst.components.repairer.workrepairvalue = TUNING.REPAIR_GEARS_WORK
    inst.components.repairer.healthrepairvalue = TUNING.REPAIR_GEARS_HEALTH

	inst:AddComponent("useabletargeteditem")
	inst.components.useabletargeteditem:SetOnUseFn(OnUsedOnChess)

	inst:AddComponent("snowmandecor")

    MakeHauntableLaunchAndSmash(inst)

    return inst
end

return Prefab("gears", fn, assets)