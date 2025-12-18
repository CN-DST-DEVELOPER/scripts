--[[ For searching
	Asset("ANIM", "anim/player_boat_sink.zip"),
	Asset("ANIM", "anim/player_float.zip"),
	Asset("ANIM", "anim/player_hotspring.zip"),
]]

local function MakeFx(name, build, bankfile, anim, facings)
	local assets =
	{
		Asset("ANIM", "anim/"..build..".zip"),
	}
	if bankfile and bankfile ~= build then
		table.insert(assets, Asset("ANIM", "anim/"..bankfile..".zip"))
	end

	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddNetwork()

		inst.AnimState:SetBank("wilson")
		inst.AnimState:SetBuild(build)
		inst.AnimState:PlayAnimation(anim)
		inst.AnimState:SetFinalOffset(-1)

		if facings == 6 then
			inst.Transform:SetSixFaced()
		else
			inst.Transform:SetFourFaced()
		end

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

	return Prefab(name, fn, assets)
end

return	MakeFx("player_float_hop_water_fx", "player_boat_sink", "player_float", "float_water_pst", 6),
		MakeFx("player_hotspring_water_fx", "player_hotspring", nil, "hotspring_water_pst", 4)
