local assets =
{
    Asset("ANIM", "anim/backpack.zip"),
    Asset("ANIM", "anim/swap_backpack.zip"),
    Asset("ANIM", "anim/ui_backpack_2x4.zip"),
}

local prefabs =
{
    "ash",
	"backpack_swap_fx",
}

--------------------------------------------------------------------------

local function AddSkinIdleFollowFx(inst, skin_build)
	if inst.idlefx == nil then
		inst.idlefx = SpawnPrefab("backpack_swap_fx")
		inst.idlefx.AnimState:OverrideItemSkinSymbol("swap_follow", skin_build, "swap_follow", inst.GUID, "swap_backpack")
		inst.idlefx.entity:SetParent(inst.entity)
		--V2C: need to follow even though idle doesn't animate, because of floating animation
		inst.idlefx.Follower:FollowSymbol(inst.GUID, "swap_body", nil, nil, nil, true)
		inst.idlefx.components.highlightchild:SetOwner(inst)
		inst:AddComponent("colouradder")
		inst:AddComponent("bloomer")
		inst.components.colouradder:AttachChild(inst.idlefx)
		inst.components.bloomer:AttachChild(inst.idlefx)
		if inst.backpack_skin_fns and inst.backpack_skin_fns.followfx_postinit then
			inst.backpack_skin_fns.followfx_postinit(inst, inst.idlefx)
		end
	end
end

local function OnEntitySleep_RemoveSwapFx(inst)
	for i, v in ipairs(inst.swapfx) do
		v:Remove()
	end
	inst.swapfx = nil
	inst.OnEntitySleep = nil
end

local function AttachSkinEquipFollowFxToOwner(inst, skin_build, owner)
	if inst.swapfx == nil then
		inst.swapfx = {}
		for i = 7, 11 do
			local fx = SpawnPrefab("backpack_swap_fx")
			fx.AnimState:OverrideItemSkinSymbol("swap_follow", skin_build, "swap_follow", inst.GUID, "swap_backpack")
			fx.AnimState:PlayAnimation("swap"..tostring(i))
			if inst.backpack_skin_fns and inst.backpack_skin_fns.followfx_postinit then
				inst.backpack_skin_fns.followfx_postinit(inst, fx)
			end
			table.insert(inst.swapfx, fx)
		end
	elseif inst.swapfxowner then
		for i, v in ipairs(inst.swapfx) do
			if inst.swapfxowner.components.colouradder then
				inst.swapfxowner.components.colouradder:DetachChild(v)
			end
			if inst.swapfxowner.components.bloomer then
				inst.swapfxowner.components.bloomer:DetachChild(v)
			end
		end
	end

	inst.swapfxowner = owner
	inst.OnEntitySleep = nil

	for i = 7, 11 do
		local fx = inst.swapfx[i - 6]
		if fx:IsInLimbo() then
			fx:ReturnToScene()
		end
		fx.entity:SetParent(owner.entity)
		fx.Follower:FollowSymbol(owner.GUID, "swap_body", nil, nil, nil, true, nil, i - 1, i == 11 and 13 or nil)
		fx.components.highlightchild:SetOwner(owner)
		if owner.components.colouradder then
			owner.components.colouradder:AttachChild(fx)
		end
		if owner.components.bloomer then
			owner.components.bloomer:AttachChild(fx)
		end
	end
end

local function DetachSkinEquipFollowFxFromOwner(inst, owner)
	assert(owner == inst.swapfxowner)

	if inst.swapfx then
		if inst:IsAsleep() then
			OnEntitySleep_RemoveSwapFx(inst)
		else
			inst.OnEntitySleep = OnEntitySleep_RemoveSwapFx

			for i, v in ipairs(inst.swapfx) do
				v.Follower:StopFollowing()
				v.entity:SetParent(inst.entity)
				if not v:IsInLimbo() then
					v:RemoveFromScene()
				end
				v.components.highlightchild:SetOwner(nil)
				if inst.swapfxowner then
					if inst.swapfxowner.components.colouradder then
						inst.swapfxowner.components.colouradder:DetachChild(v)
					end
					if inst.swapfxowner.components.bloomer then
						inst.swapfxowner.components.bloomer:DetachChild(v)
					end
				end
			end
		end

		inst.swapfxowner = nil
	end
end

local function OnBackpackSkinChanged(inst, skin_build)
	if inst.idlefx then
		inst.idlefx:Remove()
		inst.idlefx = nil
		inst:RemoveComponent("colouradder")
		inst:RemoveComponent("bloomer")
	end
	if inst.swapfx then
		for i, v in ipairs(inst.swapfx) do
			v:Remove()
		end
		inst.swapfx = nil
		inst.swapfxowner = nil
		inst.OnEntitySleep = nil
	end

	if inst.usefollowsymbol and skin_build then
		if inst.components.equippable:IsEquipped() then
			AttachSkinEquipFollowFxToOwner(inst, skin_build, inst.components.inventoryitem.owner)
		else
			AddSkinIdleFollowFx(inst, skin_build)
		end
	end
end

local function ForEachSkinFollowFx(inst, cb, ...)
	if inst.idlefx then
		cb(inst, inst.idlefx, ...)
	end
	if inst.swapfx then
		for i, v in ipairs(inst.swapfx) do
			cb(inst, v, ...)
		end
	end
end

--------------------------------------------------------------------------

local function onequip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "swap_backpack" )

		if inst.usefollowsymbol then
			AttachSkinEquipFollowFxToOwner(inst, skin_build, owner)
		end
		if inst.backpack_skin_fns and inst.backpack_skin_fns.onequip then
			inst.backpack_skin_fns.onequip(inst, owner)
		end
    else
        owner.AnimState:OverrideSymbol("swap_body", "swap_backpack", "swap_body")
    end

    if inst.components.container ~= nil then
        inst.components.container:Open(owner)
    end
end

local function onunequip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())

		if inst.usefollowsymbol then
			DetachSkinEquipFollowFxFromOwner(inst, owner)
			AddSkinIdleFollowFx(inst, skin_build)
		end
		if inst.backpack_skin_fns and inst.backpack_skin_fns.onunequip then
			inst.backpack_skin_fns.onunequip(inst, owner)
		end
    end
    owner.AnimState:ClearOverrideSymbol("swap_body")
    owner.AnimState:ClearOverrideSymbol("backpack")
    if inst.components.container ~= nil then
        inst.components.container:Close(owner)
    end
end

local function onequiptomodel(inst, owner, from_ground)
    if inst.components.container ~= nil then
        inst.components.container:Close(owner)
    end
end

local function onburnt(inst)
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
        inst.components.container:Close()
    end

    SpawnPrefab("ash").Transform:SetPosition(inst.Transform:GetWorldPosition())

    inst:Remove()
end

local function onignite(inst)
    if inst.components.container ~= nil then
        inst.components.container.canbeopened = false
    end
end

local function onextinguish(inst)
    if inst.components.container ~= nil then
        inst.components.container.canbeopened = true
    end
end

local function OnSave(inst, data)
	if inst.backpack_skin_fns and inst.backpack_skin_fns.onsave then
		inst.backpack_skin_fns.onsave(inst, data)
	end
end

local function OnLoad(inst, data, ents)
	if inst.backpack_skin_fns and inst.backpack_skin_fns.onload then
		inst.backpack_skin_fns.onload(inst, data, ents)
	end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("backpack1")
    inst.AnimState:SetBuild("swap_backpack")
    inst.AnimState:PlayAnimation("anim")

    inst:AddTag("backpack")

    inst.MiniMapEntity:SetIcon("backpack.png")

    inst.foleysound = "dontstarve/movement/foley/backpack"

    local swap_data = {bank = "backpack1", anim = "anim"}
    MakeInventoryFloatable(inst, "small", 0.2, nil, nil, nil, swap_data)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.cangoincontainer = false

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable:SetOnEquipToModel(onequiptomodel)

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("backpack")

    MakeSmallBurnable(inst)
    MakeSmallPropagator(inst)
    inst.components.burnable:SetOnBurntFn(onburnt)
    inst.components.burnable:SetOnIgniteFn(onignite)
    inst.components.burnable:SetOnExtinguishFn(onextinguish)

    MakeHauntableLaunchAndDropFirstItem(inst)

	inst.OnBackpackSkinChanged = OnBackpackSkinChanged
	inst.ForEachSkinFollowFx = ForEachSkinFollowFx
	--inst.OnEntitySleep is set/unset above
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

    return inst
end

local function swapfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	inst.AnimState:SetBank("backpack1")
    inst.AnimState:SetBuild("swap_backpack")
	inst.AnimState:PlayAnimation("swap14")
	inst.AnimState:SetFinalOffset(1)

	inst:AddComponent("highlightchild")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("colouradder")
	inst:AddComponent("bloomer")

	inst.persists = false

	return inst
end

return Prefab("backpack", fn, assets, prefabs),
	Prefab("backpack_swap_fx", swapfxfn)
