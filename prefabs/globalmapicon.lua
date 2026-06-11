local function UpdatePosition(inst)
	local x, y, z = inst._target.Transform:GetWorldPosition()
    if inst._x ~= x or inst._z ~= z then
        inst._x = x
        inst._z = z
        inst.Transform:SetPosition(x, 0, z)
    end
end

local function TrackEntity(inst, target, restriction, icon, noupdate)
    -- TODO(JBK): This function is not able to be ran twice without causing issues.
    inst._target = target
    if restriction ~= nil then
        inst.MiniMapEntity:SetRestriction(restriction)
    end
    if icon ~= nil then
        inst.MiniMapEntity:SetIcon(icon)
    elseif target.MiniMapEntity ~= nil then
        inst.MiniMapEntity:CopyIcon(target.MiniMapEntity)
    else
        inst.MiniMapEntity:SetIcon(target.prefab..".png")
    end
    inst:ListenForEvent("onremove", function() inst:Remove() end, target)

	if not noupdate then
		inst:AddComponent("updatelooper")
		inst.components.updatelooper:AddOnUpdateFn(UpdatePosition)
	end
    UpdatePosition(inst, target)
end

local function common_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst:AddTag("globalmapicon")
    inst:AddTag("CLASSIFIED")

    inst.MiniMapEntity:SetCanUseCache(false)
    inst.MiniMapEntity:SetIsProxy(true)

    inst.entity:SetCanSleep(false)

    return inst
end
local function common_server(inst)
    inst._target = nil
    inst.TrackEntity = TrackEntity

    inst.persists = false
end

local function overfog_fn()
    local inst = common_fn()
    inst.MiniMapEntity:SetDrawOverFogOfWar(true)

	RegisterGlobalMapIcon(inst, "globalmapicon")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    common_server(inst)
    return inst
end

local function overfog_noproxy_fn()
    local inst = common_fn()
    inst.MiniMapEntity:SetDrawOverFogOfWar(true)
    inst.MiniMapEntity:SetIsProxy(false)

	RegisterGlobalMapIcon(inst, "globalmapicon")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    common_server(inst)
    return inst
end

local function overfog_named_fn()
    local inst = common_fn()
    inst.MiniMapEntity:SetDrawOverFogOfWar(true)
    inst._target_displayname = net_string(inst.GUID, "globalmapiconnamed._target_displayname")

	RegisterGlobalMapIcon(inst, "globalmapiconnamed")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    common_server(inst)
    return inst
end

local function underfog_fn()
    local inst = common_fn()

	RegisterGlobalMapIcon(inst, "globalmapiconunderfog")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    common_server(inst)
    return inst
end

local function overfog_seeable_fn()
    local inst = common_fn()
    inst.MiniMapEntity:SetDrawOverFogOfWar(true, true)

	RegisterGlobalMapIcon(inst, "globalmapiconseeable")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    common_server(inst)
    return inst
end

--------------------------------------------------------------------------
--Create icon prefabs to be used with globaltrackingicon component.
--*See example usage below.

local function gclass_or_revealable_CreateIcon(overfog, isproxy, icondata, selected)
	local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddMiniMapEntity()

	inst.MiniMapEntity:SetIcon((selected and icondata.selectedicon or icondata.icon)..".png")
	inst.MiniMapEntity:SetPriority(selected and icondata.selectedpriority or icondata.priority or 0)
	inst.MiniMapEntity:SetCanUseCache(false)
	inst.MiniMapEntity:SetDrawOverFogOfWar(overfog)
	inst.MiniMapEntity:SetIsProxy(isproxy)

	return inst
end

local function gclass_RefreshIcon(inst)
	if inst.iconnear then
		local icon = (inst.selected and inst.icondata.selectedicon or inst.icondata.icon)..".png"
		local priority = inst.selected and inst.icondata.selectedpriority or inst.icondata.priority or 0
		inst.iconnear.MiniMapEntity:SetIcon(icon)
		inst.iconfar.MiniMapEntity:SetIcon(icon)
		inst.iconnear.MiniMapEntity:SetPriority(priority)
		inst.iconfar.MiniMapEntity:SetPriority(priority)
	end
end

local function gclass_OnMapSelected(inst)
	inst.selected = true
	gclass_RefreshIcon(inst)
end

local function gclass_OnCancelMapTarget(inst)
	inst.selected = nil
	gclass_RefreshIcon(inst)
end

local function gclass_or_revealable_TrackEntity(inst, target, restriction)--, icon, noupdate)
	inst._target = target

	--used for private map revealer to hide client reveals from unsharded host.
	--clients can just ignore this, since these are already network classified.
	if restriction then
		inst._restriction = restriction
		if inst.icon and not (ThePlayer and ThePlayer:HasTag(restriction)) then
			inst.icon:Remove()
			inst.icon = nil
		end
	end

	inst:ListenForEvent("onremove", function() inst:Remove() end, target)

	inst:AddComponent("updatelooper")
	inst.components.updatelooper:AddOnUpdateFn(UpdatePosition)
	UpdatePosition(inst)
end

local function gclass_Init(inst)
	inst.iconnear = gclass_or_revealable_CreateIcon(true, false, inst.icondata, inst.selected)
	inst.iconfar = gclass_or_revealable_CreateIcon(true, true, inst.icondata, inst.selected)
	inst.iconnear.entity:SetParent(inst.entity)
	inst.iconfar.entity:SetParent(inst.entity)
	if inst.icondata.fogrevealer then
		inst.iconfar.MiniMapEntity:SetIsFogRevealer(true)
	end
end

local function gclass_SetClassifiedOwner(inst, owner)
	inst.owner = owner
	inst.Network:SetClassifiedTarget(owner or inst)

	if owner and owner.HUD then
		if inst.iconnear == nil then
			gclass_Init(inst)
		end
	elseif inst.iconnear then
		inst.iconnear:Remove()
		inst.iconfar:Remove()
		inst.iconnear = nil
		inst.iconfar = nil
	end
end

local function revealable_Init(inst)
	if inst._inittask then
		inst._inittask:Cancel()
		inst._inittask = nil
	end
	inst.OnEntitySleep = nil
	inst.OnEntityWake = nil

	--owner CANNOT see this, since they have gclass instead.
	--restriction only needed to apply on unsharded host, hence ThePlayer.
	if not (inst.owner:value() and inst.owner:value().HUD) and
		(inst._restriction == nil or (ThePlayer and ThePlayer:HasTag(inst._restriction)))
	then
		if inst.icon == nil then
			inst.icon = gclass_or_revealable_CreateIcon(false, inst.isproxy:value(), inst.icondata)
			inst.icon.entity:SetParent(inst.entity)
		end
	elseif inst.icon then
		inst.icon:Remove()
		inst.icon = nil
	end
end

local function revealable_SetAsProxyExcludingOwner(inst, owner)
	inst.owner:set(owner)
	inst.isproxy:set(true)

	if not TheNet:IsDedicated() then
		revealable_Init(inst)
	end
end

local function revealable_SetAsNonProxyExcludingOwner(inst, owner)
	inst.owner:set(owner)
	inst.isproxy:set(false)

	if not TheNet:IsDedicated() then
		revealable_Init(inst)
	end
end

--Usage:
--MakeGlobalTrackingIcons("jesses_cat")
--MakeGlobalTrackingIcons("omars_cat", { icondata = { priority = 67 } })
--MakeGlobalTrackingIcons("vitos_cat", { icondata = { icon = "armello", priority = 99 } })
--MakeGlobalTrackingIcons("mays_cat", {
--	icondata = {
--		icon = "xlm", --default
--		priority = 21,
--		revealableicon = "xlm", --override revealable icon (seen by everyone except owner)
--		globalicon = "xlm_outlined", --override global icon (only seen by owner)
--		selectedicon = "xlm_selected", --override when selected in map screen (only seen by owner)
--		selectedpriority = MINIMAP_DECORATION_PRIORITY,
--	}})
function MakeGlobalTrackingIcons(name, data)
	local icondata = data and data.icondata and {
		icon = data.icondata.globalicon or data.icondata.icon or name,
		selectedicon = data.icondata.selectedicon,
		priority = data.icondata.priority,
		selectedpriority = data.icondata.selectedpriority,
		fogrevealer = data.icondata.fogrevealer,
	} or {
		icon = name,
	}

	local assets =
	{
		Asset("MINIMAP_IMAGE", icondata.icon),
	}

	if icondata.selectedicon then
		if icondata.selectedicon ~= icondata.icon then
			table.insert(assets, Asset("MINIMAP_IMAGE", icondata.selectedicon))
		else
			icondata.selectedicon = nil
		end
	end

	local revealable_icondata = data and data.icondata and (data.icondata.revealableicon or data.icondata.icon) or name
	local assets_revealable = revealable_icondata ~= icondata.icon and
	{
		Asset("MINIMAP_IMAGE", revealable_icondata)
	} or nil

	if revealable_icondata ~= icondata.icon or icondata.selectedicon or icondata.selectedpriority or icondata.fogrevealer then
		revealable_icondata =
		{
			icon = revealable_icondata,
			priority = data and data.icondata.priority,
		}
	else
		revealable_icondata = nil
	end

	local function gclass_fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddNetwork()

		inst:AddTag("CLASSIFIED")
		inst:AddTag("globalmapicon")

		inst.entity:SetCanSleep(false)

		inst.icondata = icondata

		if icondata.selectedicon then
			inst:ListenForEvent("mapselected", gclass_OnMapSelected)
			inst:ListenForEvent("cancelmaptarget", gclass_OnCancelMapTarget)
		end

		RegisterGlobalMapIcon(inst, name)

		if data.global_common_postinit then
			data.global_common_postinit(inst)
		end

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			gclass_Init(inst)

			return inst
		end

		inst.Network:SetClassifiedTarget(inst) --no owner until initialized

		inst.persists = false

		inst.SetClassifiedOwner = gclass_SetClassifiedOwner
		inst.TrackEntity = gclass_or_revealable_TrackEntity

		if data.global_master_postinit then
			data.global_master_postinit(inst)
		end

		return inst
	end

	local function revealable_fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddNetwork()

		inst:AddTag("CLASSIFIED")
		inst:AddTag("globalmapicon")

		inst.entity:SetCanSleep(false)

		inst.owner = net_entity(inst.GUID, "revealableicon.owner", "dirty")
		inst.isproxy = net_bool(inst.GUID, "revealableicon.isproxy", "dirty")

		inst.icondata = revealable_icondata or icondata

		if data.revealable_common_postinit then
			data.revealable_common_postinit(inst)
		end

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			inst.OnEntitySleep = revealable_Init
			inst.OnEntityWake = revealable_Init
			inst:ListenForEvent("dirty", revealable_Init)

			return inst
		end

		inst.persists = false

		if not TheNet:IsDedicated() then
			--This is just in case it's spawned and not initialized.
			--V2C: must use task so it can be cancelled when initialized.
			inst._inittask = inst:DoStaticTaskInTime(0, revealable_Init)
		end

		inst.SetAsProxyExcludingOwner = revealable_SetAsProxyExcludingOwner
		inst.SetAsNonProxyExcludingOwner = revealable_SetAsNonProxyExcludingOwner
		inst.TrackEntity = gclass_or_revealable_TrackEntity

		if data.revealable_master_postinit then
			data.revealable_master_postinit(inst)
		end

		return inst
	end

	return Prefab(name.."_globalicon", gclass_fn, assets),
		Prefab(name.."_revealableicon", revealable_fn, assets_revealable or assets)
end

--------------------------------------------------------------------------

return Prefab("globalmapicon", overfog_fn),
    Prefab("globalmapiconnoproxy", overfog_noproxy_fn),
    Prefab("globalmapiconnamed", overfog_named_fn),
    Prefab("globalmapiconunderfog", underfog_fn),
    Prefab("globalmapiconseeable", overfog_seeable_fn)
