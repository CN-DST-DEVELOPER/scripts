local assets =
{
	Asset("ANIM", "anim/vault_activator.zip"),
}

local assets_pedestal =
{
	Asset("ANIM", "anim/vault_key_pedestal.zip"),
}

local prefabs =
{
	"vault_key_activator",
	"vault_crawler_lever",
}

local prefabs_pedestal =
{
	"vault_key_pedestal",
}

local ACTIVATOR_PHYS_RAD = 0.6
local PEDESTAL_PHYS_RAD = 1

local function OnActivateAnimOver(inst)
	inst.plate:ClosePlate()
end

local function DisableLight(inst)
	inst.Light:Enable(false)
end

local function OnDepositSpark(inst, spark)
	if inst.AnimState:IsCurrentAnimation("activator_off_idle") then
		inst:ListenForEvent("animover", OnActivateAnimOver)
		inst.AnimState:PlayAnimation("activator_on")
		inst.Light:Enable(true)
		inst:DoTaskInTime(24 * FRAMES, DisableLight)
		inst.SoundEmitter:PlaySound("rifts7/vault_pedestal/activate")
		inst:AddTag("NOCLICK")
		inst:RemoveTag("security_powerpoint")
		inst.plate:OnDepositSpark()
	end
end

local function OnPossessed(inst, data)
    local pulse = data.possesser
    if pulse ~= nil and pulse:HasTag("power_point") then
        pulse:Remove()
	end
	OnDepositSpark(inst)
end

local function IsEmpty(inst)
	return inst.AnimState:IsCurrentAnimation("activator_off_idle")
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddLight()
	inst.entity:AddNetwork()

	inst:SetPhysicsRadiusOverride(ACTIVATOR_PHYS_RAD)

	inst.Light:SetFalloff(0.8)
	inst.Light:SetIntensity(0.5)
	inst.Light:SetRadius(5)
	inst.Light:SetColour(186/255, 234/255, 255/255)
	inst.Light:Enable(false)

	inst.AnimState:SetBank("vault_activator")
	inst.AnimState:SetBuild("vault_activator")
	inst.AnimState:PlayAnimation("activator_off_idle")
	inst.AnimState:SetFinalOffset(-1)

	inst:AddTag("security_powerpoint")

	inst.IsEmpty = IsEmpty

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_anim = "scrapbook_activator"

	inst:AddComponent("inspectable")

	inst:ListenForEvent("ms_depositspark", OnDepositSpark)
	inst:ListenForEvent("possess", OnPossessed)

	inst.pulse_findrange = 6
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local function lever_OnAppearAnimOver(inst)
	inst:RemoveEventCallback("animover", lever_OnAppearAnimOver)
	inst.AnimState:PlayAnimation("lever_idle")
	inst:RemoveTag("NOCLICK")
	inst.components.activatable.inactive = true
end

local function lever_OnPullAnimOver(inst)
	if inst.AnimState:IsCurrentAnimation("lever_pull") then
		inst.plate:OnPullLever(inst._doer)
		inst.Transform:SetNoFaced()
		inst.AnimState:PlayAnimation("lever_disappear")
	else
		inst:RemoveEventCallback("animover", lever_OnPullAnimOver)
		inst.plate:ClosePlate()
	end
end

local function lever_OnActivate(inst, doer)
	if doer and doer:IsValid() then
		inst:ForceFacePoint(doer.Transform:GetWorldPosition())
	end
	inst.Transform:SetTwoFaced()

	inst:RemoveEventCallback("animover", lever_OnAppearAnimOver)
	inst:RemoveEventCallback("animover", lever_OnPullAnimOver)
	inst:ListenForEvent("animover", lever_OnPullAnimOver)

	inst._doer = doer
	inst.AnimState:PlayAnimation("lever_pull")
	inst.SoundEmitter:PlaySound("rifts6/lever/pull")
end

local function lever_OnEntityWake(inst)
	inst.OnEntityWake = nil

	if inst._pfx == nil and inst:GetCurrentPlatform() == nil then
		local _
		inst._pfx, _, inst._pfz = inst.Transform:GetWorldPosition()
		for dx = -0.5, 0.5, 1 do
			for dz = -0.5, 0.5, 1 do
				TheWorld.Pathfinder:AddWall(inst._pfx + dx, 0, inst._pfz + dz)
			end
		end
	end
end

local function lever_OnRemoveEntity(inst)
	if inst._pfx then
		for dx = -0.5, 0.5, 1 do
			for dz = -0.5, 0.5, 1 do
				TheWorld.Pathfinder:RemoveWall(inst._pfx + dx, 0, inst._pfz + dz)
			end
		end
		inst._pfx, inst._pfz = nil, nil
	end
end

local function lever_GetActivateVerb(inst)--, doer)
	return "PULL"
end

local function leverfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:SetPhysicsRadiusOverride(ACTIVATOR_PHYS_RAD)

	inst.AnimState:SetBank("vault_activator")
	inst.AnimState:SetBuild("vault_activator")
	inst.AnimState:PlayAnimation("lever_appear")
	inst.AnimState:SetFinalOffset(-1)

	inst:AddTag("NOCLICK")

	inst.OnEntityWake = lever_OnEntityWake
	inst.OnRemoveEntity = lever_OnRemoveEntity

	inst.GetActivateVerb = lever_GetActivateVerb

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_anim = "scrapbook_lever"

	inst:AddComponent("inspectable")

	inst:AddComponent("activatable")
	inst.components.activatable.inactive = false
	inst.components.activatable.standingaction = true
	inst.components.activatable.OnActivate = lever_OnActivate

	inst.persists = false

	if POPULATING then
		lever_OnAppearAnimOver(inst)
	else
		inst:ListenForEvent("animover", lever_OnAppearAnimOver)
	end

	return inst
end

--------------------------------------------------------------------------

local function OnKeyTakenAnimOver(inst)
	inst.plate:OpenPlate("vault_refiner_pedestal")
end

local function pedestal_OnKeyTaken(inst)
	inst.OnEntityWake = nil
	inst.AnimState:PlayAnimation("pedestal_disappear")
	inst:ListenForEvent("animover", OnKeyTakenAnimOver)
	inst:AddTag("NOCLICK")
	inst.SoundEmitter:KillSound("loop")
	inst.SoundEmitter:PlaySound("rifts7/vault_key_pedestal/deactivate")
	inst.components.pickable.caninteractwith = false
	inst.components.pickable.canbepicked = false -- for onload
	if inst.camerafocustask then
		inst.camerafocustask:Cancel()
		inst.camerafocustask = nil
	end
	inst.plate:EnableCameraFocus(true)
end

local function pedestal_OnAppearAnimOver(inst)
	inst:RemoveEventCallback("animover", pedestal_OnAppearAnimOver)
	inst.OnEntityWake = nil
	inst.AnimState:PlayAnimation("pedestal_idle_key", true)
	inst:RemoveTag("NOCLICK")
	inst.SoundEmitter:PlaySound("rifts7/vault_key_pedestal/idle_LP", "loop")
	if inst.plate and inst.camerafocustask == nil then
		inst.plate:EnableCameraFocus(false)
	end
end

local function pedestal_DisableCameraFocus(inst)
	inst.camerafocustask = nil
	inst.plate:EnableCameraFocus(false)
end

local function pedestal_OnEntityWake(inst)
	inst.OnEntityWake = nil
	if inst.AnimState:IsCurrentAnimation("pedestal_appear") then
		inst.SoundEmitter:PlaySound("rifts7/vault_key_pedestal/activate")
	else
		inst.SoundEmitter:PlaySound("rifts7/vault_key_pedestal/idle_LP", "loop")
	end
end

local KEYLIGHT_RADIUS = 4.5
local KEYLIGHT_INTENSITY = 0.7
local KEYLIGHT_FALLOFF = 0.8
local KEYLIGHT_COLOUR = RGB(180, 240, 255)

local function pedestalfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
	inst.entity:AddNetwork()

	inst:SetPhysicsRadiusOverride(PEDESTAL_PHYS_RAD)

	inst.AnimState:SetBank("vault_key_pedestal")
	inst.AnimState:SetBuild("vault_key_pedestal")
	inst.AnimState:PlayAnimation("pedestal_appear")
	inst.AnimState:SetFinalOffset(-1)

	inst.Light:SetRadius(KEYLIGHT_RADIUS)
	inst.Light:SetIntensity(KEYLIGHT_INTENSITY)
	inst.Light:SetFalloff(KEYLIGHT_FALLOFF)
	inst.Light:SetColour(unpack(KEYLIGHT_COLOUR))
    inst.Light:Enable(true)

	inst:AddTag("NOCLICK")
	inst:AddTag("high_dolongaction")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_anim = "scrapbook_pedestal"

	inst:AddComponent("inspectable")

    inst:AddComponent("pickable")
    inst.components.pickable:SetUp("vault_key", 1000000)
    inst.components.pickable:Pause()
    inst.components.pickable.onpickedfn = pedestal_OnKeyTaken

	inst.OnKeyTaken = pedestal_OnKeyTaken

	inst.persists = false

	if POPULATING then
		inst.AnimState:PlayAnimation("pedestal_idle_key", true)
		inst:RemoveTag("NOCLICK")
	else
		inst:ListenForEvent("animover", pedestal_OnAppearAnimOver)
		inst.camerafocustask = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + 0.6, pedestal_DisableCameraFocus)
	end
	inst.OnEntityWake = pedestal_OnEntityWake

	return inst
end

--------------------------------------------------------------------------

local function refiner_OnTurnOn(inst)
	if inst._activetask == nil then
    	if inst.AnimState:IsCurrentAnimation("refiner_proximity_loop")
			or inst.AnimState:IsCurrentAnimation("use") then
    	    inst.AnimState:PushAnimation("refiner_proximity_loop", true)
    	else
    	    inst.AnimState:PlayAnimation("refiner_proximity_loop", true)
    	end

    	if not inst.SoundEmitter:PlayingSound("loop_sound") then
    	    inst.SoundEmitter:PlaySound("rifts7/refiner/proximity_lp", "loop_sound")
    	end
	end
end

local function refiner_OnTurnOff(inst)
	if inst._activetask == nil then
    	inst.AnimState:PushAnimation("refiner_idle", false)
    	inst.SoundEmitter:KillSound("loop_sound")
	end
end

local function refiner_DoneAct(inst)
    inst._activetask = nil
    if inst.components.prototyper.on then
        inst.AnimState:PlayAnimation("refiner_proximity_loop", true)
        if not inst.SoundEmitter:PlayingSound("loop_sound") then
            inst.SoundEmitter:PlaySound("rifts7/refiner/proximity_lp", "loop_sound")
        end
    else
		inst.AnimState:PushAnimation("refiner_idle")
		inst.SoundEmitter:KillSound("loop_sound")
    end
end

local function refiner_OnActivate(inst, doer, recipe)
    inst.AnimState:PlayAnimation("refiner_use")
    inst.SoundEmitter:PlaySound("rifts7/refiner/use")
    if inst._activetask ~= nil then
        inst._activetask:Cancel()
    end
    inst._activetask = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength(), refiner_DoneAct)
end

local function refiner_OnAppearAnimOver(inst)
	inst:AddTag("prototyper") -- Now it's active.
	inst:RemoveEventCallback("animover", refiner_OnAppearAnimOver)
	inst.OnEntityWake = nil
	inst.AnimState:PlayAnimation("refiner_idle", true)
	inst:RemoveTag("NOCLICK")
	if inst.plate then --we CAN reach here during construction, when plate hasn't be set
		inst.plate:EnableCameraFocus(false)
		inst.plate:PushEvent("ms_vaultrefiner_revealed")
	end
end

local function refiner_OnEntityWake(inst)
	inst.OnEntityWake = nil
	inst.SoundEmitter:PlaySound("rifts7/refiner/appear")
end

local function refinerpedestalfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
    inst.entity:AddLight()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:SetPhysicsRadiusOverride(PEDESTAL_PHYS_RAD)

	inst.AnimState:SetBank("vault_key_pedestal")
	inst.AnimState:SetBuild("vault_key_pedestal")
	inst.AnimState:PlayAnimation("refiner_appear")
	inst.AnimState:SetFinalOffset(-1)

	inst.Light:SetRadius(KEYLIGHT_RADIUS)
	inst.Light:SetIntensity(KEYLIGHT_INTENSITY)
	inst.Light:SetFalloff(KEYLIGHT_FALLOFF)
	inst.Light:SetColour(unpack(KEYLIGHT_COLOUR))
    inst.Light:Enable(true)

	inst:AddTag("NOCLICK")
	inst:AddTag("high_dolongaction")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

    inst._activetask = nil
	inst.scrapbook_anim = "scrapbook_refiner"

	inst:AddComponent("inspectable")

	inst:AddComponent("prototyper")
	inst.components.prototyper.onturnon = refiner_OnTurnOn
	inst.components.prototyper.onturnoff = refiner_OnTurnOff
	inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.VAULT_REFINER_PEDESTAL
	inst.components.prototyper.onactivate = refiner_OnActivate
	inst:RemoveTag("prototyper") -- Not active yet.

	inst.persists = false

	if POPULATING then
		refiner_OnAppearAnimOver(inst)
	else
		inst:ListenForEvent("animover", refiner_OnAppearAnimOver)
		inst.OnEntityWake = refiner_OnEntityWake
	end

	return inst
end

--------------------------------------------------------------------------

local function plate_OnCameraFocusDirty(inst)
	local player = TheFocalPoint.entity:GetParent()
	if inst.camerafocus:value() and player and
		TheWorld.Map:IsPointInVaultRoom(player.Transform:GetWorldPosition()) and
		TheWorld.Map:IsPointInVaultRoom(inst.Transform:GetWorldPosition())
	then
		TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 6, 75, 4)
	else
		TheFocalPoint.components.focalpoint:StopFocusSource(inst)
	end
end

local function plate_EnableCameraFocus(inst, enable)
	if enable and inst.trial and inst.trial:IsPillarGuardAggro() then
		enable = false --don't use camera focus if pillar guards are still in combat
	end
	if enable ~= inst.camerafocus:value() then
		inst.camerafocus:set(enable)

		--Dedicated server does not need to focus camera
		if not TheNet:IsDedicated() then
			plate_OnCameraFocusDirty(inst)
		end
	end
end

local function plate_SpawnOpenPrefab(inst)
	local prefab = inst._openprefab
	inst._openprefab = nil
	if prefab then
		if inst.activator then
			if inst.activator.prefab == prefab then
				return
			end
			inst.activator:Remove()
		end
		inst.activator = SpawnPrefab(prefab)
		inst.activator.entity:SetParent(inst.entity)
		inst.activator.plate = inst
	end
end

local function plate_CreateFront(build)
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank(build)
	inst.AnimState:SetBuild(build)
	inst.AnimState:PlayAnimation("plate_front")

	return inst
end

local function plate_OnShowFrontDirty(inst)
	if inst.showfront:value() then
		if inst.front == nil and not TheNet:IsDedicated() then
			inst.front = plate_CreateFront(inst.build)
			inst.front.entity:SetParent(inst.entity)
		end
	elseif inst.front then
		inst.front:Remove()
		inst.front = nil
	end
end

local function plate_ShowFront(inst, show)
	if inst.showfront:value() ~= show then
		inst.showfront:set(show)
		plate_OnShowFrontDirty(inst)
	end
end

local function plate_OnOpenAnimOver(inst)
	inst:RemoveEventCallback("animover", plate_OnOpenAnimOver)
	inst.AnimState:PlayAnimation("plate_opened_idle")
	inst.Physics:SetActive(true)
	plate_ShowFront(inst, true)
	plate_SpawnOpenPrefab(inst)
end

local function plate_Open(inst, prefab)
	if prefab then
		inst._openprefab = prefab
		if inst.AnimState:IsCurrentAnimation("plate_opened_idle") then
			plate_SpawnOpenPrefab(inst)
		elseif inst.AnimState:IsCurrentAnimation("plate_open_pre") then
			--already opening
		else
			if POPULATING then
				plate_OnOpenAnimOver(inst)
			else
				if inst.camerafocus then
					inst:EnableCameraFocus(true)
				end
				inst:ListenForEvent("animover", plate_OnOpenAnimOver)
				inst.AnimState:PlayAnimation("plate_open_pre")
				inst.SoundEmitter:PlaySound("rifts7/plate/open")
			end
			LaunchArea(inst, inst.plateradius, 1, 0.75, 0.3, 0.8 * inst.plateradius)
		end
	end
end

local function plate_Close(inst)
	if inst._openprefab then
		inst._openprefab = nil
		inst:RemoveEventCallback("animover", plate_OnOpenAnimOver)
	end
	if inst.activator then
		inst.activator:Remove()
		inst.activator = nil
	end
	inst.Physics:SetActive(false)
	plate_ShowFront(inst, false)
	if not (inst.AnimState:IsCurrentAnimation("plate_close_pre") or
			inst.AnimState:IsCurrentAnimation("plate_closed_idle"))
	then
		if POPULATING then
			inst.AnimState:PlayAnimation("plate_closed_idle")
		else
			inst.AnimState:PlayAnimation("plate_close_pre")
			inst.AnimState:PushAnimation("plate_closed_idle", false)
			inst.SoundEmitter:PlaySound("rifts7/plate/open")
		end
	end
end

local function plate_GetOpenPrefab(inst)
	return inst.activator and inst.activator.prefab or inst._openprefab
end

local function plate_OnDepositSpark(inst)
	if not inst.gotspark then
		inst.gotspark = true
		inst:PushEvent("ms_vaultactivator_changed")
	end
end

local function plate_OnPullLever(inst, doer)
	inst:PushEvent("ms_vaultcrawlerlever_pulled", doer)
end

local function plate_GotSpark(inst)
	return inst.gotspark
end

local function plate_OnSave(inst, data)
	data.gotspark = inst.gotspark
	if inst.activator ~= nil then
		if inst.activator.components.pickable ~= nil then
			data.pedestal = true

			if not inst.activator.components.pickable:CanBePicked() then
				data.pedestal_picked = true
			end
		elseif inst.activator.components.prototyper ~= nil then
			data.refiner = true
		end
	end
end

local function plate_OnLoad(inst, data, ents)
	if data then
		if data.refiner then
			inst:OpenPlate("vault_refiner_pedestal")
		elseif data.pedestal then
			inst:OpenPlate("vault_key_pedestal")
			if data.pedestal_picked then
				inst.activator:OnKeyTaken()
			end
		elseif data.gotspark then
			inst:OnDepositSpark()
			inst:ClosePlate()
		else
			inst:OpenPlate("vault_key_activator")
		end
	end
end

local function MakePlate(name, build, radius, camerafocus, assets, prefabs)
	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		inst.entity:AddNetwork()

		inst:SetDeploySmartRadius(radius + 0.15)
		MakeSmallObstaclePhysics(inst, radius)
		inst.plateradius = radius
		inst.Physics:SetActive(false)

		inst.build = build
		inst.AnimState:SetBank(build)
		inst.AnimState:SetBuild(build)
		inst.AnimState:PlayAnimation("plate_closed_idle")
		inst.AnimState:SetLayer(LAYER_BACKGROUND)
		inst.AnimState:SetSortOrder(-2)

		--Not using NOCLICK because we do want to block mouse
		--Not using decor/FX because we do want to block placement
		--Some actions will highlight targets even if not a valid action:
		--  "nomagic" blocks SPELLCAST (e.g. reskin_tool)
		--  "nohighlight" blocks complexprojectile (e.g. bombs)
		inst:AddTag("nomagic")
		inst:AddTag("nohighlight")
		inst:AddTag("blocker")

		inst.showfront = net_bool(inst.GUID, "vault_key_activator_plate.showfront", "showfrontdirty")
		if camerafocus then
			inst.camerafocus = net_bool(inst.GUID, "vault_key_activator_plate.camerafocus", "camerafocusdirty")
		end

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			inst:ListenForEvent("showfrontdirty", plate_OnShowFrontDirty)
			if camerafocus then
				inst:ListenForEvent("camerafocusdirty", plate_OnCameraFocusDirty)
			end
			return inst
		end

		inst.OnDepositSpark = plate_OnDepositSpark
		inst.OnPullLever = plate_OnPullLever
		inst.GotSpark = plate_GotSpark
		inst.OpenPlate = plate_Open
		inst.ClosePlate = plate_Close
		inst.EnableCameraFocus = camerafocus and plate_EnableCameraFocus or nil
		inst.GetOpenPrefab = plate_GetOpenPrefab
		inst.OnSave = plate_OnSave
		inst.OnLoad = plate_OnLoad

		return inst
	end

	return Prefab(name, fn, assets, prefabs)
end

--------------------------------------------------------------------------

return Prefab("vault_key_activator", fn, assets),
	Prefab("vault_crawler_lever", leverfn, assets),
	Prefab("vault_key_pedestal", pedestalfn, assets_pedestal),
	Prefab("vault_refiner_pedestal", refinerpedestalfn, assets_pedestal),
	MakePlate("vault_key_activator_plate", "vault_activator", ACTIVATOR_PHYS_RAD, false, assets, prefabs),
	MakePlate("vault_key_pedestal_plate", "vault_key_pedestal", PEDESTAL_PHYS_RAD, true, assets_pedestal, prefabs_pedestal)
