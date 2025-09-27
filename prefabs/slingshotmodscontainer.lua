local assets =
{
	Asset("ANIM", "anim/ui_slingshotmods.zip"),
}

local function PostUpdate(inst)
	TheFocalPoint.SoundEmitter:PlaySound("meta5/walter/slingshot_UI_modify")

	--technically not safe to remove during update loop, but we will
	--do it anyway as long as we don't use any other post update fns
	inst.components.updatelooper:RemovePostUpdateFn(PostUpdate)
	inst._sfxqueued = nil
end

local function OnItemChanged(inst)
	if inst._sfxqueued == nil then
		local container = inst.replica.container
		--works fine for nil ThePlayer 
		--busy check to ignore the events when server data arrives on
		--clients since container prediction already played the sound
		if container:IsOpenedBy(ThePlayer) and not container:IsBusy() then
			inst._sfxqueued = true
			inst.components.updatelooper:AddPostUpdateFn(PostUpdate)
		end
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddNetwork()

	inst:AddTag("CLASSIFIED")

	if not TheNet:IsDedicated() then
		inst:ListenForEvent("itemget", OnItemChanged)
		inst:ListenForEvent("itemlose", OnItemChanged)
		inst:AddComponent("updatelooper")
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("container")
	inst.components.container:WidgetSetup("slingshotmodscontainer")
	inst.components.container.skipautoclose = true

	inst.install_target = nil

	return inst
end

return Prefab("slingshotmodscontainer", fn, assets)
