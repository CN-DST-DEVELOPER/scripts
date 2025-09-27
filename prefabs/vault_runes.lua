local assets =
{
	Asset("ANIM", "anim/vault_runes.zip"),
}

local function GetDescription(inst, viewer)
	if viewer.components.inventory and viewer.components.inventory:EquipHasTag("ancient_reader") then
		return STRINGS.VAULT_RUNE[string.upper(inst.id)]
	end
end

local function SetId(inst, id)
	inst.id = id
	local anim = string.sub(id, 1, 4) == "lore" and "idle1" or "idle2"
	if not inst.AnimState:IsCurrentAnimation(anim) then
		inst.AnimState:PlayAnimation(anim)
	end
end

local function OnSave(inst, data)
	data.id = inst.id ~= "lobby" and inst.id or nil
end

local function OnLoad(inst, data, ents)
	if data and data.id then
		inst:SetId(data.id)
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	MakeObstaclePhysics(inst, 0.5)

	inst.MiniMapEntity:SetIcon("vault_rune.png")

	inst.AnimState:SetBank("vault_runes")
	inst.AnimState:SetBuild("vault_runes")
	inst.AnimState:PlayAnimation("idle2")

	inst:AddTag("structure")
	inst:AddTag("statue")
	inst:AddTag("ancient_text")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst.components.inspectable.descriptionfn = GetDescription

	inst.id = "lobby"

	inst.SetId = SetId
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

return Prefab("vault_rune", fn, assets)
