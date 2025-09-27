local assets =
{
	Asset("ANIM", "anim/player_boat_sink.zip"),
	Asset("ANIM", "anim/player_float.zip"),
}

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("wilson")
	inst.AnimState:SetBuild("player_boat_sink")
	inst.AnimState:PlayAnimation("float_water_pst")
	inst.AnimState:SetFinalOffset(-1)

	inst.Transform:SetSixFaced()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false
	inst:ListenForEvent("animover", inst.Remove)

	return inst
end

return Prefab("player_float_hop_water_fx", fn, assets)
