local assets =
{
	Asset("ANIM", "anim/vault_pillar_guard_fx.zip"),
}

local function swipe_Reverse(inst)
	inst.AnimState:PlayAnimation("atk2")
end

local function swipe_fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("vault_pillar_guard_fx")
	inst.AnimState:SetBuild("vault_pillar_guard_fx")
	inst.AnimState:PlayAnimation("atk1")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.Reverse = swipe_Reverse

	inst.persists = false
	inst:ListenForEvent("animover", inst.Remove)

	return inst
end

local function smash_PostUpdate(inst)
	local parent = inst.entity:GetParent()
	if parent then
		inst.AnimState:SetTime(parent.AnimState:GetCurrentAnimationTime())
	end
	inst:RemoveComponent("updatelooper")
end

local function smash_CreateFx()
	local inst = CreateEntity()

	inst:AddTag("NOCLICK")
	inst:AddTag("FX")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(TheWorld.ismastersim) --done below
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("vault_pillar_guard_fx")
	inst.AnimState:SetBuild("vault_pillar_guard_fx")
	inst.AnimState:PlayAnimation("atk_smash")
	inst.AnimState:SetFinalOffset(2)

	if not TheWorld.ismastersim then
		inst.entity:SetCanSleep(false)

		inst:AddComponent("updatelooper")
		inst.components.updatelooper:AddPostUpdateFn(smash_PostUpdate)
	end

	return inst
end

local function smash_fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("vault_pillar_guard_fx")
	inst.AnimState:SetBuild("vault_pillar_guard_fx")
	inst.AnimState:PlayAnimation("atk_smash_ground")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)

	if not TheNet:IsDedicated() then
		smash_CreateFx().entity:SetParent(inst.entity)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false
	inst:ListenForEvent("animover", inst.Remove)

	return inst
end

return Prefab("vault_pillar_guard_swipe_fx", swipe_fn, assets),
	Prefab("vault_pillar_guard_smash_fx", smash_fn, assets)
