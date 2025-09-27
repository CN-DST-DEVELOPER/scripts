local assets =
{
	Asset("ANIM", "anim/woby_treat.zip"),
}

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("woby_treat")
	inst.AnimState:SetBuild("woby_treat")
	inst.AnimState:PlayAnimation("idle")

	inst:AddTag("meat")
	inst:AddTag("quickeat")
	inst:AddTag("monstermeat")
	inst:AddTag("quickfeed")
	inst:AddTag("pet_treat")

	MakeInventoryFloatable(inst, "small", 0.19, { 0.7, 0.9, 1 })

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

	inst:AddComponent("edible")
	inst.components.edible.ismeat = true
	inst.components.edible.foodtype = FOODTYPE.MEAT
	inst.components.edible.secondaryfoodtype = FOODTYPE.MONSTER
	inst.components.edible.healthvalue = -TUNING.HEALING_TINY
	inst.components.edible.hungervalue = TUNING.CALORIES_TINY
	inst.components.edible.sanityvalue = -TUNING.SANITY_TINY

	inst:AddComponent("tradable")
	inst.components.tradable.goldvalue = 0

	MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
	MakeSmallPropagator(inst)
	MakeHauntableLaunchAndIgnite(inst)

	return inst
end

return Prefab("woby_treat", fn, assets)
