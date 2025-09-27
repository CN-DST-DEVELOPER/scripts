local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()

	inst:AddTag("NOCLICK")
	inst:AddTag("NOBLOCK")
	inst:AddTag("formationleader")
	inst:AddComponent("formationleader")

    --[[Non-networked entity]]

	inst.persists = false

	return inst
end

return Prefab("formationleader", fn)
