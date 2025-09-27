local assets_table =
{
	Asset("ANIM", "anim/vault_table_round.zip"),
}

local assets_stool =
{
	Asset("ANIM", "anim/vault_chair_stool.zip"),
}

--------------------------------------------------------------------------
--variation 1 is no moss
--table has 3 variations (1 + 2 moss)
--chair has 4 variations (1 + 3 moss)

local function SetVariation(inst, variation)
	if inst.variation ~= variation then
		if inst.variation > 1 then
			inst.AnimState:Hide("MOSS"..tostring(inst.variation - 1))
		end
		if variation > 1 then
			inst.AnimState:Show("MOSS"..tostring(variation - 1))
		end
		inst.variation = variation
	end
end

local function OnSave(inst, data)
	data.variation = inst.variation ~= 1 and inst.variation or nil
end

local function OnLoad(inst, data, ents)
	if data and data.variation then
		inst:SetVariation(data.variation)
	end
end

local function DisplayNameFn(inst)
	return STRINGS.NAMES.VAULTRELIC
end

--------------------------------------------------------------------------

--[[local function table_GetStatus(inst)
	return inst:HasTag("hasfurnituredecoritem") and "HAS_ITEM" or nil
end]]

local function table_AbleToAcceptDecor(inst, item, giver)
	return item ~= nil
end

local function table_OnDecorGiven(inst, item, giver)
	if item then
		inst.SoundEmitter:PlaySound("wintersfeast2019/winters_feast/table/food")
		if item.Physics then
			item.Physics:SetActive(false)
		end
		if item.Follower then
			item.Follower:FollowSymbol(inst.GUID, "swap_object")
		end
	end
end

local function table_OnDecorTaken(inst, item)
	-- Item might be nil if it's taken in a way that destroys it.
	if item then
		if item.Physics then
			item.Physics:SetActive(true)
		end
		if item.Follower then
			item.Follower:StopFollowing()
		end
	end
end

local function fn_table()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(0.875) --recipe min_spacing/2

	MakeObstaclePhysics(inst, 0.7)

	inst.AnimState:SetBank("vault_table_round")
	inst.AnimState:SetBuild("vault_table_round")
	inst.AnimState:PlayAnimation("idle")
	inst.AnimState:SetFinalOffset(-1)

	inst.AnimState:Hide("MOSS1")
	inst.AnimState:Hide("MOSS2")

	inst:AddTag("decortable")
	inst:AddTag("structure")

	inst.displaynamefn = DisplayNameFn

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("furnituredecortaker")
	inst.components.furnituredecortaker.abletoaccepttest = table_AbleToAcceptDecor
	inst.components.furnituredecortaker.ondecorgiven = table_OnDecorGiven
	inst.components.furnituredecortaker.ondecortaken = table_OnDecorTaken

	inst:AddComponent("inspectable")
	inst.components.inspectable.nameoverride = "relic"

	MakeHauntable(inst)

	inst.variation = 1
	inst.SetVariation = SetVariation
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

--------------------------------------------------------------------------

local function stool_GetStatus(inst)
	return inst.components.sittable:IsOccupied() and "OCCUPIED" or nil
end

local function stool_DescriptionFn(inst)--, viewer)
	inst.components.inspectable.nameoverride = inst.components.sittable:IsOccupied() and "stone_chair" or "relic"
	--return nothing
end

local function fn_stool()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(0.875) --recipe min_spacing/2

	MakeObstaclePhysics(inst, 0.25)

	inst:AddTag("structure")
	inst:AddTag("faced_chair")
	inst:AddTag("rotatableobject")

	inst.AnimState:SetBank("vault_chair_stool")
	inst.AnimState:SetBuild("vault_chair_stool")
	inst.AnimState:PlayAnimation("idle")
	inst.AnimState:SetFinalOffset(-1)

	for i = 1, 3 do
		inst.AnimState:Hide("MOSS"..tostring(i))
	end

	inst.displaynamefn = DisplayNameFn

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst.components.inspectable.descriptionfn = stool_DescriptionFn

	inst:AddComponent("sittable")

	inst:AddComponent("savedrotation")
	inst.components.savedrotation.dodelayedpostpassapply = true

	MakeHauntable(inst)

	inst.variation = 1
	inst.SetVariation = SetVariation
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

--------------------------------------------------------------------------

return Prefab("vault_table_round", fn_table, assets_table),
	Prefab("vault_stool", fn_stool, assets_stool)
