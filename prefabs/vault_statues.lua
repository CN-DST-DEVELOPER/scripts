local assets =
{
	Asset("ANIM", "anim/statue_vault.zip"),
	Asset("MINIMAP_IMAGE", "vault_statue_king"),
	Asset("MINIMAP_IMAGE", "vault_statue_guard"),
	Asset("MINIMAP_IMAGE", "vault_statue_gate"),
	--Asset("MINIMAP_IMAGE", "vault_statue_ancient"),
	--Asset("MINIMAP_IMAGE", "vault_statue_bug"),
}

--[[
king
guard1
guard2
guard3
gate
ancient1
ancient2
ancient3
ancient4
bug1
bug2
bug3
]]

local MINIMAP =
{
	["king"] = "vault_statue_king.png",
	["guard1"] = "vault_statue_guard.png",
	["guard2"] = "vault_statue_guard.png",
	["guard3"] = "vault_statue_guard.png",
	["gate"] = "vault_statue_gate.png",
	--["ancient1"] = "vault_statue_ancient.png",
	--["ancient2"] = "vault_statue_ancient.png",
	--["ancient3"] = "vault_statue_ancient.png",
	--["ancient4"] = "vault_statue_ancient.png",
	--["bug1"] = "vault_statue_bug.png",
	--["bug2"] = "vault_statue_bug.png",
	--["bug3"] = "vault_statue_bug.png",
}

local function SetId(inst, id)
	if id ~= inst.id then
		inst.id = id
		inst.AnimState:PlayAnimation("idle_"..id)
		inst.MiniMapEntity:SetIcon(MINIMAP[id] or "")
	end
end

local function SetScene(inst, scene)
	inst.scene = scene
end

local function GetStatus(inst)--, viewer)
	return string.upper(inst.scene)
end

local function OnSave(inst, data)
	data.id = inst.id ~= "king" and inst.id or nil
	data.scene = inst.scene ~= "lore1" and inst.scene or nil
end

local function OnLoad(inst, data)--, ents)
	if data then
		if data.id then
			inst:SetId(data.id)
		end
		if data.scene then
			inst:SetScene(data.scene)
		end
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	inst.MiniMapEntity:SetIcon("vault_statue_king.png")

	MakeObstaclePhysics(inst, 0.66)

	inst.AnimState:SetBank("statue_vault")
	inst.AnimState:SetBuild("statue_vault")
	inst.AnimState:PlayAnimation("idle_king")

	inst:AddTag("structure")
	inst:AddTag("statue")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst.id = "king"
	inst.scene = "lore1"

	inst.SetId = SetId
	inst.SetScene = SetScene
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

return Prefab("vault_statue", fn, assets)
