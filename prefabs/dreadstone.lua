local assets =
{
	Asset("ANIM", "anim/dreadstone.zip"),
}

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("dreadstone")
	inst.AnimState:SetBuild("dreadstone")
	inst.AnimState:PlayAnimation("idle")

	MakeInventoryFloatable(inst, "med", .145, { .77, .75, .77 })

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("tradable")

	inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

	inst:AddComponent("inspectable")

	inst:AddComponent("inventoryitem")

	MakeHauntableLaunchAndSmash(inst)

	return inst
end

return Prefab("dreadstone", fn, assets)
