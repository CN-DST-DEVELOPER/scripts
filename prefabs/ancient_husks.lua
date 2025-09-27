local assets =
{
	Asset("ANIM", "anim/ancient_husk.zip"),
}

--[[
handmaid
architect
mason
]]

local function SetId(inst, id)
	if id ~= inst.id then
		inst.id = id
		inst.AnimState:PlayAnimation("husk_"..id)
		if id ~= "handmaid" then
			inst.Physics:SetCapsule(1.3, 2)
		end
	end
	return inst
end

local function OnSave(inst, data)
	data.id = inst.id ~= "handmaid" and inst.id or nil
end

local function OnLoad(inst, data)--, ents)
	if data and data.id then
		inst:SetId(data.id)
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeObstaclePhysics(inst, 1)

	inst.AnimState:SetBank("ancient_husk")
	inst.AnimState:SetBuild("ancient_husk")
	inst.AnimState:PlayAnimation("husk_handmaid")

	--these tags fit mechanically, even tho they're technically statues
	inst:AddTag("structure")
	inst:AddTag("statue")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")

	inst.id = "handmaid"

	inst.SetId = SetId
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

return Prefab("ancient_husk", fn, assets)
