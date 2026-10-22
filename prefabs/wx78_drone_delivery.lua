local easing = require("easing")

local function _dbg_print(...)
	print("[wx78_drone_delivery]:", ...)
	return true
end

local LIFTOFF_TIME = 2.5
local FADE_TIME = 1 --spawnfader fades are always 1 second

--------------------------------------------------------------------------

local function SetShadowSize(inst, size)
	if size > 0 then
		inst.DynamicShadow:Enable(true)
		inst.DynamicShadow:SetSize(size * 1.5, size * 0.75)
	else
		inst.DynamicShadow:Enable(false)
	end
end

local function OnUpdateShadow(inst)
	if inst.drone.AnimState:IsCurrentAnimation("takeoff_ground") then
		local fr = inst.drone.AnimState:GetCurrentAnimationFrame()
		if fr < 20 then
			SetShadowSize(inst, easing.outQuart(fr, 0, 0.8, 20))
		elseif fr < 50 then
			SetShadowSize(inst, easing.inQuad(fr - 20, 0.8, -0.8, 50 - 20))
		else
			inst.DynamicShadow:Enable(false)
		end
	elseif inst.drone.AnimState:IsCurrentAnimation("land") then
		local fr = inst.drone.AnimState:GetCurrentAnimationFrame()
		local numfr = inst.drone.AnimState:GetCurrentAnimationNumFrames()
		local midfr = 30 --mid-point for manually out-in ease
		local offset = 15 --don't ease all the way to and from the slowest points
		if fr < midfr then
			local d = midfr + offset
			local endsize = easing.outCubic(midfr, 0, 0.5, d) --cubic so the shadow is quickly visible to show the landing point
			local rescale = 0.5 / endsize -- so we end up at 0.5 even with the offset end point
			local size = easing.outCubic(fr, 0, 0.5 * rescale, d)
			SetShadowSize(inst, size)
		else
			local d = numfr - midfr + offset - 1
			local startsize = easing.inQuad(offset, 0.5, 0.5, d)
			local rescale = 0.5 / startsize --so we start at 0.5 even with the offset start point
			local size = easing.inQuad(fr - midfr + offset, 0.5 * rescale, 0.5, d)
			SetShadowSize(inst, size)
		end
	else
		inst.DynamicShadow:Enable(false)
	end
end

local function OnPostUpdateShadow(inst)
	inst.components.updatelooper:RemovePostUpdateFn(OnPostUpdateShadow)
	OnUpdateShadow(inst)
end

local function CreateShadow(drone)
	local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddDynamicShadow()

	inst.drone = drone
	inst.entity:SetParent(drone.entity)

	inst:AddComponent("updatelooper")
	inst.components.updatelooper:AddOnUpdateFn(OnUpdateShadow)
	if TheWorld.ismastersim then
		OnUpdateShadow(inst)
	else
		inst.components.updatelooper:AddPostUpdateFn(OnPostUpdateShadow)
	end

	return inst
end

local function OnShowFlyingShadowDirty(inst)
	if inst.showflyingshadow:value() then
		if inst.shadow == nil then
			inst.shadow = CreateShadow(inst)
		end
	elseif inst.shadow then
		inst.shadow:Remove()
		inst.shadow = nil
	end
end

local function ShowFlyingShadow(inst, show)
	if inst.showflyingshadow:value() ~= show then
		inst.showflyingshadow:set(show)

		if not TheNet:IsDedicated() then
			OnShowFlyingShadowDirty(inst)
		end
	end
end

--------------------------------------------------------------------------

local function EndPhysTask(inst)
	inst._phystask = nil
	inst.Physics:SetActive(false)
end

local function PreventStuckInObstacle(inst)
	if inst._phystask then
		inst._phystask:Cancel()
		inst._phystask = nil
	end
	if not inst:IsAsleep() then
		local x, _, z = inst.Transform:GetWorldPosition()
		inst.Physics:SetActive(true)
		inst.Physics:Teleport(x, 0, z)
		inst._phystask = inst:DoTaskInTime(0.1, EndPhysTask)
		inst._deferred_stuck_prevention = nil
	else
		inst._deferred_stuck_prevention = true
	end
end

local function CancelStuckPrevention(inst)
	inst._deferred_stuck_prevention = nil
	if inst._phystask then
		inst._phystask:Cancel()
		inst._phystask = nil
	end
	inst.Physics:SetActive(false)
end

local function OnEntityWake(inst)
	if inst._deferred_stuck_prevention then
		PreventStuckInObstacle(inst)
	end
end

--------------------------------------------------------------------------

local function SetFlying(inst, flying)
	if flying then
		inst:RemoveTag("structure")
		inst:AddTag("CLASSIFIED")
		inst:AddTag("NOCLICK")
		inst:AddTag("flying")
		inst:AddTag("outofreach")
	else
		inst:RemoveTag("CLASSIFIED")
		inst:RemoveTag("NOCLICK")
		inst:RemoveTag("flying")
		inst:RemoveTag("outofreach")
		inst:AddTag("structure")
	end
end

local function SetInteractable(inst, enable)
	--NOTE: candismantle just checks container:CanBeOpened()
	inst._nointeract = not enable or nil

	if inst._lockedforuser == nil then
		if enable then
			inst.components.container.canbeopened = true
		else
			inst._skipcloseanim = true
			inst.components.container:Close()
			inst.components.container.canbeopened = false
			inst._skipcloseanim = nil
		end
	end

	inst.components.workable:SetWorkable(enable)
	inst.components.workable:SetWorkLeft(2)
end

local function SetLockedForUser(inst, user)
	inst.components.mapdeliverable:CancelMapAction()

	if inst._lockedforuser then
		inst:RemoveEventCallback("onremove", inst._onremovelockedforuser, inst._lockedforuser)
	end
	inst._lockedforuser = user
	if user then
		inst:ListenForEvent("onremove", inst._onremovelockedforuser, user)
	end

	if not inst._nointeract then
		if user then
			inst.components.container:Close()
			inst.components.container.canbeopened = false
		else
			inst.components.container.canbeopened = true
		end
	end
end

local function CalcDeliveryTime(inst, dest, doer)
	local x, _, z = inst.Transform:GetWorldPosition()
	local dist = math.sqrt(math2d.DistSq(x, z, dest.x, dest.z))
	--[[local a = TUNING.SKILLS.WX78.DELIVERYDRONE_SPEED
	local accel_dist = 0.5 * a * 1 * 1
	local accel_and_decel_dist = 2 * accel_dist]]
	local accel_and_decel_dist = TUNING.SKILLS.WX78.DELIVERYDRONE_SPEED
	local t = dist <= accel_and_decel_dist and 2 or 2 + (dist - accel_and_decel_dist) / TUNING.SKILLS.WX78.DELIVERYDRONE_SPEED
	return LIFTOFF_TIME + t
end

local function OnStartDelivery(inst, dest, doer)
	if inst._nointeract then
		return false
	end
	inst._sender = doer
	CancelStuckPrevention(inst)
	SetFlying(inst, true)
	SetInteractable(inst, false)
	ShowFlyingShadow(inst, true)
	inst.components.globaltrackingicon:StartTracking(doer)
	inst.AnimState:PlayAnimation("takeoff_ground")
	inst.SoundEmitter:PlaySound("WX_rework/delivery_drone/takeoff")
	return true
end

local function ChangeSender(inst, sender)
	if inst._sender ~= sender then
		inst._sender = sender
		_dbg_print(string.format("<%s> sender reacquired: <%s>", tostring(inst), tostring(sender)))

		inst.components.globaltrackingicon:StartTracking(sender)
	end
end

local function CheckSender(inst)
	if inst._senderid then
		for _, v in ipairs(AllPlayers) do
			if v.userid == inst._senderid then
				inst._senderid = nil
				ChangeSender(inst, v)
				return true
			end
		end
	end
	return false
end

local function OnDeliveryProgress(inst, t, len, origin, dest)
	if t < LIFTOFF_TIME then
		if inst.entity:IsVisible() then
			if inst:IsAsleep() then
				if inst.components.floater:IsFloating() then
					inst:PushEvent("on_no_longer_landed")
				end
				inst.components.spawnfader:Cancel()
				inst:Hide()
				ShowFlyingShadow(inst, false)
			else
				if t >= 25 * FRAMES and inst.components.floater:IsFloating() then
					inst:PushEvent("on_no_longer_landed")
					SpawnPrefab("splash").Transform:SetPosition(inst.Transform:GetWorldPosition())
				end
				if t >= LIFTOFF_TIME - FADE_TIME and not inst.components.spawnfader.updating then
					--hides on "spawnfaderout", so we won't accidentally enter this block and restart again
					inst.components.spawnfader:FadeOut()
				end
			end
		end
	else
		if inst.entity:IsVisible() then
			inst.components.spawnfader:Cancel()
			inst:Hide()
			ShowFlyingShadow(inst, false)
		end

		t = t - LIFTOFF_TIME
		len = len - LIFTOFF_TIME

		local dx = dest.x - origin.x
		local dz = dest.z - origin.z
		local k
		if len <= 2 then
			k = easing.inOutQuad(t, 0, 1, len)
		else
			local dist = math.sqrt(dx * dx + dz * dz)
			local accel_and_decel_dist = TUNING.SKILLS.WX78.DELIVERYDRONE_SPEED
			local accelpart = accel_and_decel_dist / 2 / dist
			if t <= 1 then
				--1s to accel to max speed
				k = easing.inQuad(t, 0, accelpart, 1)
			elseif t < len - 1 then
				--max speed
				k = easing.linear(t - 1, accelpart, 1 - 2 * accelpart, len - 2)
			else
				--1s to decel to stop
				k = easing.outQuad(t - len + 1, 1 - accelpart, accelpart, 1)
			end
		end
        local x, _, z = inst.Transform:GetWorldPosition()
        local desiredx, desiredz = origin.x + k * dx, origin.z + k * dz
        if IsFlyingPermittedFromPointToPoint_BypassVault(x, 0, z, desiredx, 0, desiredz) then
            inst.Transform:SetPosition(desiredx, 0, desiredz)
        else
            inst.components.mapdeliverable:Stop()
        end
	end
	CheckSender(inst)
end

local function OnSpawnFaderIn(inst)
	if inst:HasTag("CLASSIFIED") then
		inst:AddTag("NOCLICK") --spawnfader removed this after fadein, but we still want it
	end
end

local function OnLanded(inst) --delivery, not floater stuff!
	if inst.AnimState:IsCurrentAnimation("land") then
		inst.AnimState:PlayAnimation("land_pst")
		SetFlying(inst, false)
		ShowFlyingShadow(inst, false)
		inst:PushEvent("on_landed")
		if inst:IsAsleep() then
			OnLanded(inst)
		else
			inst.SoundEmitter:PlaySound("WX_rework/delivery_drone/land_pst")
		end
	else
		inst:RemoveEventCallback("animover", OnLanded)
		inst:RemoveEventCallback("entitysleep", OnLanded)
		inst.AnimState:PlayAnimation("closed_idle")
		SetInteractable(inst, true)
		inst.components.globaltrackingicon:StopTracking()

		--force a cached icon after the globaltrackingicon is removed
		if inst._sender and inst._sender:IsValid() and inst._sender.player_classified then
			inst._sender.player_classified.MapExplorer:RevealEntity(inst.entity)
		end
		inst._sender = nil
	end
end

local function OnStopDelivery(inst)
	PreventStuckInObstacle(inst)
	ShowFlyingShadow(inst, true)
	inst:Show()
	inst.components.spawnfader:FadeIn()
	inst.AnimState:PlayAnimation("land")
	inst:ListenForEvent("animover", OnLanded)
	inst:ListenForEvent("entitysleep", OnLanded)
	if inst:IsAsleep() then
		OnLanded(inst)
	else
		inst.SoundEmitter:PlaySound("WX_rework/delivery_drone/land_pre")
	end
end

local function OnSave(inst, data)
	if inst._sender then
		data.sender = inst._sender.userid
	end
end

local function OnLoad(inst, data)--, newents)
	if data and data.sender and inst.components.mapdeliverable:IsDelivering() then
		inst._senderid = data.sender
		if not CheckSender(inst) then
			ChangeSender(inst, nil)
		end
	end
end

local function OnLoadPostPass(inst)
	if not inst.components.mapdeliverable:IsDelivering() then
		inst:PushEvent("on_landed")
	end
end

--------------------------------------------------------------------------

local function CancelQueuedSplash(inst)
	if inst._splashtask then
		inst._splashtask:Cancel()
		inst._splashtask = nil
	end
end

local function TrySplash(inst)
	CancelQueuedSplash(inst)
	if not inst:IsAsleep() and inst.components.floater:IsFloating() then
		SpawnPrefab("splash").Transform:SetPosition(inst.Transform:GetWorldPosition())
	end
end

local function QueueSplash(inst, delay)
	if inst._splashtask then
		inst._splashtask:Cancel()
	end
	inst._splashtask = inst:DoTaskInTime(delay, TrySplash)
end

local function OnOpen(inst)--, data)
	inst.AnimState:PlayAnimation("opened_pre")
	inst.AnimState:PushAnimation("opened_idle", false)
	inst.SoundEmitter:PlaySound("WX_rework/delivery_drone/open")
	TrySplash(inst)
end

local function OnClose(inst)--, doer)
	inst.SoundEmitter:PlaySound("WX_rework/delivery_drone/close")
	if inst._skipcloseanim then
		CancelQueuedSplash(inst)
		return
	end
	inst.AnimState:PlayAnimation("closed_pre")
	inst.AnimState:PushAnimation("closed_idle", false)
	QueueSplash(inst, 10 * FRAMES)
end

local function OnBuilt2(inst)
	inst:RemoveEventCallback("animover", OnBuilt2)
	SetInteractable(inst, true)
	inst.AnimState:PlayAnimation("closed_idle")
end

local function OnBuilt(inst)--, data)
	SetInteractable(inst, false)
	inst.AnimState:PlayAnimation("deploy")
	inst.SoundEmitter:PlaySound("WX_rework/delivery_drone/deploy")
	inst:DoTaskInTime(8 * FRAMES, inst.PushEvent, "on_landed")
	inst:ListenForEvent("animover", OnBuilt2)
end

local function ChangeToItem(inst, fast)
	inst.components.container:DropEverything()

	local item = SpawnPrefab(inst.prefab.."_item", inst.linked_skinname, inst.skin_id)
	item.Transform:SetPosition(inst.Transform:GetWorldPosition())
	item.AnimState:PlayAnimation("collapse")
	if fast then
		item.AnimState:SetFrame(8)
	end
	item.AnimState:PushAnimation("kit_idle", false)
	item.SoundEmitter:PlaySound("WX_rework/delivery_drone/collapse")
	item.components.inventoryitem:InheritWorldWetnessAtTarget(inst)
	item.components.inventoryitem:SetLanded(false, true)

	TrySplash(inst)
	inst:Remove()
end

local function OnDismantle(inst)
	ChangeToItem(inst, false)
end

local function OnHit(inst, worker, workleft, numworks)
	if not inst:HasTag("NOCLICK") then
		inst._skipcloseanim = true
		inst.components.container:DropEverything()
		inst.components.container:Close()
		inst._skipcloseanim = nil
		inst.AnimState:PlayAnimation("closed_hit")
		inst.AnimState:PushAnimation("closed_idle", false)
		TrySplash(inst)
	end
end

local function OnHammered(inst, worker)
	if not inst:HasTag("NOCLICK") then
		ChangeToItem(inst, true)
	end
end

--------------------------------------------------------------------------

local function CheckEmpty(inst)
	inst.isempty:set(inst.components.container:IsEmpty())
end

local function CanDismantle(inst, doer) --client safe
	if not inst.isempty:value() then
		return false
	elseif not (doer and doer:HasTag("batteryuser")) then
		return false
	end
	local container = inst.replica.container
	return container ~= nil and container:CanBeOpened()
end

local function CanMapDeliver(inst, doer) --client safe
	--only check this, let other wx attempt to use even when it's busy, to trigger fail strings
	return not inst.isempty:value() and doer and doer:HasTag("batteryuser")
end

--------------------------------------------------------------------------

local function OnCancelMapAction(inst, doer)
	if doer then
		doer:PushEvent("interruptcontinuousaction", inst)
	end
end

local function OnStopContinuousAction(inst, doer)
	if inst._lockedforuser == doer then
		SetLockedForUser(inst, nil)
	end
end

--------------------------------------------------------------------------

local ret = {}

local function MakeDrone(name, numcols, numrows, required_skill)
	local function OnStartMapAction(inst, doer)
		if doer == nil or inst._nointeract then
			return false
		elseif required_skill and not (doer.components.skilltreeupdater and doer.components.skilltreeupdater:IsActivated(required_skill)) then
			return false, "NOSKILL_DRONE"
		elseif inst._lockedforuser or inst.components.container:IsOpenedByOthers(doer) then
			return false, "INUSE"
		elseif inst.isempty:value() then
			return false, "EMPTY"
		end
		SetLockedForUser(inst, doer)
		return true
	end

	local assets =
	{
		Asset("ANIM", "anim/"..name..".zip"),
		Asset("ANIM", string.format("anim/ui_wx_deliverydrone_%ux%u.zip", numcols, numrows)),
		Asset("MINIMAP_IMAGE", name.."_selected"),
	}

	local assets_kit =
	{
		Asset("ANIM", "anim/"..name..".zip"),
	}

	local prefabs =
	{
		name.."_globalicon",
		name.."_revealableicon",
		"splash",
		"bufferedmapaction",
	}

	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		inst.entity:AddMiniMapEntity()
		inst.entity:AddNetwork()

		MakeInventoryPhysics(inst, 50, 1)
		inst.Physics:SetActive(false)
		inst.Physics:SetCollisionMask(
			COLLISION.WORLD,
			COLLISION.OBSTACLES,
			COLLISION.SMALLOBSTACLES)

		inst.MiniMapEntity:SetIcon(name..".png")
        inst.MiniMapEntity:SetAlwaysOutsideVRS(true)

		inst.AnimState:SetBank(name)
		inst.AnimState:SetBuild(name)
		inst.AnimState:PlayAnimation("closed_idle")

		inst:AddTag("structure")
		inst:AddTag("chest")
        inst:AddTag("staysthroughvirtualrooms")

		inst.showflyingshadow = net_bool(inst.GUID, name..".showflyingshadow", "showflyingshadowdirty")
		inst.isempty = net_bool(inst.GUID, name..".isempty")
		inst.isempty:set(true)

		MakeInventoryFloatable(inst, "med", 0.4, { 1.05, 1.2, 1 }) -- it's not inventory, but can still use this

		inst:AddComponent("spawnfader")

		inst.candismantle = CanDismantle
		inst.canmapdeliver = CanMapDeliver

		inst.bufferedmapaction_icondata = { icon = name.."_selected" }

		if name ~= "wx78_drone_delivery" then
			inst:SetPrefabNameOverride("wx78_drone_delivery")
		end

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			inst:ListenForEvent("showflyingshadowdirty", OnShowFlyingShadowDirty)

			return inst
		end

		inst:AddComponent("inspectable")

		inst:AddComponent("portablestructure")
		inst.components.portablestructure:SetOnDismantleFn(OnDismantle)

		inst:AddComponent("container")
		inst.components.container:WidgetSetup(name)
		inst.components.container.onopenfn = OnOpen
		inst.components.container.onclosefn = OnClose
		inst.components.container.skipopensnd = true
		inst.components.container.skipclosesnd = true

		inst:AddComponent("mapdeliverable")
		inst.components.mapdeliverable:SetDeliveryTimeFn(CalcDeliveryTime)
		inst.components.mapdeliverable:SetOnStartDeliveryFn(OnStartDelivery)
		inst.components.mapdeliverable:SetOnDeliveryProgressFn(OnDeliveryProgress)
		inst.components.mapdeliverable:SetOnStopDeliveryFn(OnStopDelivery)
		inst.components.mapdeliverable:SetOnStartMapActionFn(OnStartMapAction)
		inst.components.mapdeliverable:SetOnCancelMapActionFn(OnCancelMapAction)

		inst:AddComponent("globaltrackingicon")

		inst:AddComponent("workable")
		inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
		inst.components.workable:SetWorkLeft(2)
		inst.components.workable:SetOnWorkCallback(OnHit)
		inst.components.workable:SetOnFinishCallback(OnHammered)

		inst:ListenForEvent("itemget", CheckEmpty)
		inst:ListenForEvent("itemlose", CheckEmpty)
		inst:ListenForEvent("onbuilt", OnBuilt)
		inst:ListenForEvent("spawnfaderin", OnSpawnFaderIn)
		inst:ListenForEvent("spawnfaderout", inst.Hide)
		inst:ListenForEvent("stopcontinuousaction", OnStopContinuousAction)

		inst._onremovelockedforuser = function(user) SetLockedForUser(inst, nil) end

		inst.OnSave = OnSave
		inst.OnLoad = OnLoad
		inst.OnEntityWake = OnEntityWake
		inst.OnLoadPostPass = OnLoadPostPass

		return inst
	end

	local globalicon, revealableicon = MakeGlobalTrackingIcons(name, { icondata = { icon = name.."_air", priority = 21 } })

	table.insert(ret, Prefab(name, fn, assets, prefabs))
	table.insert(ret, globalicon)
	table.insert(ret, revealableicon)
	table.insert(ret, MakeDeployableKitItem(name.."_item",
		name, --prefab to deploy
		name, --bank
		name, --build
		"kit_idle", --anim
		assets_kit,
		{ size = "med", y_offset = 0.4, scale = { 0.85, 1.05, 1 } }, --float
		{ "donotautopick", "usedeploystring" }, --tags
		nil, --burnable
		{	deployspacing = DEPLOYSPACING.MEDIUM,
			restrictedtag = "batteryuser",
			common_postinit = function(inst) --yup it's put in the deployable data
				inst.entity:AddSoundEmitter()
				inst:SetPrefabNameOverride("wx78_drone_delivery") --for both big and small
			end
		}, --deployable
		TUNING.STACK_SIZE_LARGEITEM))
	table.insert(ret, MakePlacer(name.."_item_placer", name, name, "closed_idle"))
end

MakeDrone("wx78_drone_delivery", 3, 2, "wx78_deliverydrone_2")
MakeDrone("wx78_drone_delivery_small", 3, 1, "wx78_deliverydrone_1")

return unpack(ret)
