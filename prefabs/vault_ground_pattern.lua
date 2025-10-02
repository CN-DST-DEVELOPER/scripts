local assets =
{
	Asset("ANIM", "anim/vault_ground_pattern.zip"),
}

local function SetVariation(inst, variation)
	if inst.variation ~= variation then
		inst.variation = variation
		inst.AnimState:PlayAnimation("idle"..tostring(variation))
	end
	return inst
end

local function HideCenter(inst)
	if not inst.nocenter then
		inst.nocenter = true
		inst.AnimState:Hide("center")
	end
	return inst
end

local function SetOrientation(inst, orientation)
	if orientation > 2 and inst.variation < 3 and not inst.nocenter then
		orientation = orientation - 2
	end
	if inst.orientation ~= orientation then
		inst.orientation = orientation
		if orientation <= 2 then
			inst.AnimState:SetScale(1, 1)
			inst.Transform:SetRotation(orientation == 1 and 0 or 180)
		else
			inst.AnimState:SetScale(-1, 1)
			inst.Transform:SetRotation(orientation == 1 and 90 or -90)
		end
	end
	return inst
end

local function OnSave(inst, data)
	data.variation = inst.variation ~= 1 and inst.variation or nil
	data.nocenter = inst.nocenter or nil
	data.orientation = inst.orientation ~= 1 and inst.orientation or nil
end

local function OnLoad(inst, data)--, ents)
	if data then
		if data.variation then
			inst:SetVariation(data.variation)
		end
		if data.nocenter then
			inst:HideCenter()
		end
		if data.orientation then
			inst:SetOrientation(data.orientation)
		end
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("vault_ground_pattern")
	inst.AnimState:SetBuild("vault_ground_pattern")
	inst.AnimState:PlayAnimation("idle1")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(-3)
	inst.AnimState:SetFinalOffset(-1)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.variation = 1
	inst.orientation = 1
	inst.SetVariation = SetVariation
	inst.HideCenter = HideCenter
	inst.SetOrientation = SetOrientation
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

return Prefab("vault_ground_pattern_fx", fn, assets)
