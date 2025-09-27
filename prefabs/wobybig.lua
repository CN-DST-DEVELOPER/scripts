local WobyCommon = require("prefabs/wobycommon")

local assets =
{
    Asset("ANIM", "anim/woby_big_build.zip"),
	Asset("ANIM", "anim/woby_big_lunar_build.zip"),
	Asset("ANIM", "anim/woby_big_shadow_build.zip"),
    Asset("ANIM", "anim/woby_big_transform.zip"),
    Asset("ANIM", "anim/woby_big_travel.zip"),
    Asset("ANIM", "anim/woby_big_mount_travel.zip"),
    Asset("ANIM", "anim/woby_big_mount_basic.zip"),
	Asset("ANIM", "anim/woby_big_mount_sprint.zip"),
	Asset("ANIM", "anim/woby_big_mount_dash.zip"),
    Asset("ANIM", "anim/woby_big_actions.zip"),
    Asset("ANIM", "anim/woby_big_basic.zip"),
    Asset("ANIM", "anim/woby_big_boat_jump.zip"),

	Asset("ANIM", "anim/spell_icons_woby.zip"),
    Asset("ANIM", "anim/ui_woby_3x3.zip"),
    Asset("PKGREF", "anim/ui_woby_3x4.zip"), --using 3x3 instead

    Asset("ANIM", "anim/pupington_woby_build.zip"),
	Asset("ANIM", "anim/pupington_woby_lunar_build.zip"),
	Asset("ANIM", "anim/pupington_woby_shadow_build.zip"),
    Asset("SOUND", "sound/beefalo.fsb"),

	Asset("ANIM", "anim/wilson_fx.zip"),

	Asset("SCRIPT", "scripts/prefabs/wobycommon.lua"),
}

local prefabs =
{
    "wobysmall",
	"woby_rack_container",
	"woby_rack_swap_fx",
	"pet_hunger_classified",
	"woby_commands_classified",
	"woby_dash_shadow_fx",
	"woby_dash_silhouette_fx",
}

local brain = require("brains/wobybigbrain")

local sounds_for_mounted_emotes =
{
	walk = "dontstarve/characters/walter/woby/big/footstep",
	grunt = "dontstarve/characters/walter/woby/big/chuff",
	yell = "dontstarve/characters/walter/woby/big/bark",
	swish = "dontstarve/characters/walter/woby/big/tail",
	curious = "dontstarve/characters/walter/woby/big/chuff",
	angry = "dontstarve/characters/walter/woby/big/bark",
	sleep = "dontstarve/characters/walter/woby/big/sleep",
}

-------------------------------------------------------------------------------

--This applies wobybig normal/alignment build or overrides (can be used on us or on rider's animstate)
local function _ApplyAlignmentOverrides_Internal(inst, animstate, alignment, skin_build)
	local base_name = "woby_big"
	if alignment then
		base_name = base_name.."_"..alignment
	end
	local base_build = base_name.."_build"
	if skin_build then
		if alignment or animstate ~= inst.AnimState then
			for _, symbol in ipairs(WobyCommon.BIG_SYMBOLS) do
				animstate:OverrideItemSkinSymbol(symbol, skin_build, symbol, inst.GUID, base_build)
			end
		else
			--Lunar/shadow builds have the same symbols as the base build
			animstate:ClearOverrideBuild(base_build)
		end
    elseif animstate == inst.AnimState then
        animstate:ClearOverrideBuild(base_build)
        animstate:SetBuild(base_build)
    else
        animstate:AddOverrideBuild(base_build)
    end
end

--This applies wobysmall normal/alignment overrides
local function _ApplySmallBuildOverrides_Internal(inst, alignment, skin_build)
	local base_name = "pupington_woby"
	if alignment then
		base_name = base_name.."_"..alignment
	end
	local base_build = base_name.."_build"
	if skin_build then
		skin_build = skin_build:gsub("woby_big", "pupington_woby")
		for _, symbol in ipairs(WobyCommon.SMALL_SYMBOLS) do
			inst.AnimState:OverrideItemSkinSymbol(symbol, skin_build, symbol, inst.GUID, base_build)
		end
	else
		inst.AnimState:AddOverrideBuild(base_build)
	end
end

--External interface for rider: this clears wobybig normal/alignment overrides from rider's animstate
local function ClearBuildOverrides(inst, animstate)
	assert(animstate ~= inst.AnimState)
	--Lunar/shadow builds have the same symbols as the base build
	animstate:ClearOverrideBuild("woby_big_build")
end

--External interface for rider: this applies wobybig normal/alignment overrides to rider's animstate
local function ApplyBuildOverrides(inst, animstate)
	_ApplyAlignmentOverrides_Internal(inst, animstate, inst.alignment, inst:GetSkinBuild())
end

--Used by sg: this applies normal wobysmall & alignment overrides during transform state
local function ApplySmallBuildOverrides(inst)
	if not inst._hassmallbuild then
		_ApplySmallBuildOverrides_Internal(inst, inst.alignment, inst:GetSkinBuild())
		if inst.components.wobyrack then
			inst.AnimState:AddOverrideBuild("woby_rack")
			for i = 1, 3 do
				local item, name, build = inst.components.wobyrack:GetItemInSlot(i)
				if item then
					inst.AnimState:OverrideSymbol("swap_dried"..tostring(i), build, name)
					inst.AnimState:OverrideSymbol("rope"..tostring(i), "woby_rack", "rope")
				else
					inst.AnimState:OverrideSymbol("rope"..tostring(i), "woby_rack", "rope_empty")
				end
			end
		end
		inst._hassmallbuild = true
	end
end

--Used by prefabskin.lua
local function OnWobySkinChanged(inst, skin_build)
	if inst._hassmallbuild then
		_ApplySmallBuildOverrides_Internal(inst, inst.alignment, skin_build)
	end
	local rider = inst.components.rideable:GetRider()
	if rider then
		_ApplyAlignmentOverrides_Internal(inst, rider.AnimState, inst.alignment, skin_build)
	end
	_ApplyAlignmentOverrides_Internal(inst, inst.AnimState, inst.alignment, skin_build)

	if inst.pet_hunger_classified then
		inst.pet_hunger_classified:SetBuild(skin_build and skin_build:gsub("woby_big", "status_woby"):gsub("_shadow", ""):gsub("_lunar", "") or nil)
	end
end

local function SetAlignmentBuild(inst, alignment, showfx)
	if inst.alignment ~= alignment then
		if inst.pet_hunger_classified then
			inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.LUNAR, alignment == "lunar")
			inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.SHADOW, alignment == "shadow")
		end
		inst.alignment = alignment
        local skin_build = inst:GetSkinBuild()
        if skin_build then
            skin_build = skin_build:gsub("_lunar", ""):gsub("_shadow", "")
            if inst.alignment then
                skin_build = skin_build .. "_" .. inst.alignment
            end
        end
        TheSim:ReskinEntity(inst.GUID, inst.skinname, skin_build, nil, inst._playerlink.userid)
        inst:OnWobySkinChanged(skin_build)
		if showfx and alignment then
			if alignment == "lunar" then
				WobyCommon.DoLunarAlignFx(inst)
			elseif alignment == "shadow" then
				WobyCommon.DoShadowAlignFx(inst)
			end
			inst.sg:HandleEvent("showalignmentchange")
		end
	end
end

-------------------------------------------------------------------------------
--Rack

local function OnAnyOpen(inst, data)
	if data and data.doer and data.doer == inst._playerlink then
		inst.components.wobyrack:GetContainer():Open(data.doer)
	end
end

local function OnAnyClose(inst, data)
	if data and data.doer then
		inst.components.wobyrack:GetContainer():Close(data.doer)
	end
end

local function SetRackFxOwner(inst, owner)
	if inst._rackfxowner and inst._rackfxowner.components.colouradder then
		inst._rackfxowner.components.colouradder:DetachChild(inst.rackfx1)
		inst._rackfxowner.components.colouradder:DetachChild(inst.rackfx2)
	end
	inst._rackfxowner = owner
	owner = owner or inst
	inst.rackfx1.entity:SetParent(owner.entity)
	inst.rackfx2.entity:SetParent(owner.entity)
	inst.rackfx1.Follower:FollowSymbol(owner.GUID, "swap_saddle", 0, 0, 0, true, false, 0, 2)
	inst.rackfx2.Follower:FollowSymbol(owner.GUID, "swap_saddle", 0, 0, 0, true, false, 2)
	inst.rackfx1.components.highlightchild:SetOwner(owner)
	inst.rackfx2.components.highlightchild:SetOwner(owner)
	if owner.components.colouradder then
		owner.components.colouradder:AttachChild(inst.rackfx1)
		owner.components.colouradder:AttachChild(inst.rackfx2)
	end
end

local function ShowRackItem(inst, slot, name, build)
	inst.rackfx1:ShowRackItem(slot, name, build)
	inst.rackfx2:ShowRackItem(slot, name, build)
	if inst._hassmallbuild then
		inst.AnimState:OverrideSymbol("swap_dried"..tostring(slot), build, name)
		inst.AnimState:OverrideSymbol("rope"..tostring(slot), "woby_rack", "rope")
	end
end

local function HideRackItem(inst, slot)
	inst.rackfx1:HideRackItem(slot)
	inst.rackfx2:HideRackItem(slot)
	if inst._hassmallbuild then
		inst.AnimState:ClearOverrideSymbol("swap_dried"..tostring(slot))
		inst.AnimState:OverrideSymbol("rope"..tostring(slot), "woby_rack", "rope_empty")
	end
end

local function EnableRack(inst, enable, showanim)
	if enable then
		if inst.components.wobyrack == nil then
			inst:AddComponent("wobyrack")
			inst.components.wobyrack:EnableDrying()
			inst.components.wobyrack:SetShowItemFn(ShowRackItem)
			inst.components.wobyrack:SetHideItemFn(HideRackItem)
			inst.components.container.onanyopenfn = OnAnyOpen
			inst.components.container.onanyclosefn = OnAnyClose
			inst.rackfx1 = SpawnPrefab("woby_rack_swap_fx")
			inst.rackfx2 = SpawnPrefab("woby_rack_swap_fx")
			inst.rackfx2.AnimState:PlayAnimation("swap_2")
			SetRackFxOwner(inst, inst.components.rideable:GetRider())
			if inst._hassmallbuild then
				inst.AnimState:AddOverrideBuild("woby_rack")
				for i = 1, 3 do
					inst.AnimState:OverrideSymbol("rope"..tostring(i), "woby_rack", "rope_empty")
				end
			end
			if inst.components.container:IsOpenedBy(inst._playerlink) then
				inst.components.wobyrack:GetContainer():Open(inst._playerlink)
			end
			if showanim then
				local rider = inst.components.rideable:GetRider()
				if rider == nil then
					inst.sg:HandleEvent("showrack")
				elseif rider.sg then
					rider.sg:HandleEvent("woby_showrack")
				end
			end
		end
	elseif inst.components.wobyrack then
		inst.components.container.onanyopenfn = nil
		inst.components.container.onanyclosefn = nil
		inst:RemoveComponent("wobyrack")
		inst.rackfx1:Remove()
		inst.rackfx2:Remove()
		inst.rackfx1 = nil
		inst.rackfx2 = nil
		if inst._hassmallbuild then
			inst.AnimState:ClearOverrideBuild("woby_rack")
			for i = 1, 3 do
				inst.AnimState:ClearOverrideSymbol("rope"..tostring(i))
				inst.AnimState:ClearOverrideSymbol("swap_dried"..tostring(i))
			end
		end
	end
end

local function OnPreLoad(inst, data, newents)
	if data and data.wobyrack then
		EnableRack(inst, true, false)
	end
end

-------------------------------------------------------------------------------

local function TriggerTransformation(inst)
    if inst.sg.currentstate.name ~= "transform" and not inst.transforming then
        inst.persists = false
        inst:AddTag("NOCLICK")
        inst.transforming = true

        inst.components.rideable.canride = false

        if inst.components.container:IsOpen() then
            inst.components.container:Close()
        end

        if inst.components.rideable:IsBeingRidden() then
            --SG won't handle "transformation" event while we're being ridden
            --SG is forced into transformation state AFTER dismounting (OnRiderChanged)
            inst.components.rideable:Buck(true)
        else
            inst:PushEvent("transform")
        end
    end
end

local function IsLunarPowered(inst)
	return inst._canbelunarpowered and (
		(not inst._isincave and TheWorld.state.isnight and not TheWorld.state.isnewmoon) or
		(inst._playerlink and inst._playerlink.components.sanity and inst._playerlink.components.sanity:IsLunacyMode())
	) or false
end

local function HasEndurance(inst)
	return inst._playerlink
		and inst._playerlink.components.skilltreeupdater
		and inst._playerlink.components.skilltreeupdater:IsActivated("walter_woby_endurance")
		or false
end

local function SetRunSpeed(inst, speed)
    inst.components.locomotor.runspeed = speed

    local rider = inst.components.rideable:GetRider()
    if rider and rider.player_classified ~= nil then
        rider.player_classified.riderrunspeed:set(speed)
    end
end

local function SetBaseRunSpeed(inst, speed)
	if HasEndurance(inst) then
		speed = speed + TUNING.SKILLS.WALTER.WOBY_BIG_ENDURANCE_SPEED_BONUS
	end
	SetRunSpeed(inst, speed)
end

local function SetBaseRunSpeedFromHunger(inst, pct)
	SetBaseRunSpeed(inst,
		(pct >= 0.7 and TUNING.WOBY_BIG_SPEED.FAST) or
		(pct >= 0.33 and TUNING.WOBY_BIG_SPEED.MEDIUM) or
		TUNING.WOBY_BIG_SPEED.SLOW)
end

local function OnHungerDelta(inst, data)
	if not inst._issprinting then
		SetBaseRunSpeedFromHunger(inst, data.newpercent)
	end
end

local function CustomFoodStatsMod(inst, health_delta, hunger_delta, sanity_delta, food, feeder)
	if food and food.prefab == "woby_treat" and hunger_delta and hunger_delta > 0 then
		hunger_delta = hunger_delta * 3
	end
	return health_delta, hunger_delta, sanity_delta
end

local function ClearSprintHungerBurn(inst)
	inst.components.hunger.burnratemodifiers:RemoveModifier(inst, "sprinting")
	if inst.pet_hunger_classified then
		inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.SPRINT_DRAIN, false)
	end
end

local function UpdateSprintHungerBurn(inst)
	if IsLunarPowered(inst) then
		ClearSprintHungerBurn(inst)
	else
		inst.components.hunger.burnratemodifiers:SetModifier(inst, TUNING.SKILLS.WALTER.WOBY_BIG_SPRINT_HUNGER_RATE_MOD, "sprinting")
		if inst.pet_hunger_classified then
			inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.SPRINT_DRAIN, true)
		end
	end
end

local function CheckLunarPower(inst)
	if inst._issprinting then
		UpdateSprintHungerBurn(inst)
	end
end

local function StartWatchingLunarPower(inst)
	if not inst._canbelunarpowered then
		inst._canbelunarpowered = true
		if not inst._isincave then
			inst:WatchWorldState("isnight", CheckLunarPower)
			inst:WatchWorldState("isnewmoon", CheckLunarPower)
		end
		assert(inst._playerlink)
		inst._onsanitymodechanged = function() CheckLunarPower(inst) end
		inst:ListenForEvent("sanitymodechanged", inst._onsanitymodechanged, inst._playerlink)
		CheckLunarPower(inst)
	end
end

local function StopWatchingLunarPower(inst)
	if inst._canbelunarpowered then
		inst._canbelunarpowered = nil
		if not inst._isincave then
			inst:StopWatchingWorldState("isnight", CheckLunarPower)
			inst:StopWatchingWorldState("isnewmoon", CheckLunarPower)
		end
		if inst._playerlink then
			--if playerlink is nil, it would've been from removal, and the listener would've cleared itself
			inst:ListenForEvent("sanitymodechanged", inst._onsanitymodechanged, inst._playerlink)
		end
		inst._onsanitymodechanged = nil
		CheckLunarPower(inst)
	end
end

local function SetSprinting(inst, issprinting, isturbo)
	if issprinting then
		if not inst._issprinting then
			inst._issprinting = true
			inst._isturbo = isturbo or false
			UpdateSprintHungerBurn(inst)
			SetBaseRunSpeed(inst, isturbo and TUNING.SKILLS.WALTER.WOBY_BIG_TURBO_SPEED or TUNING.SKILLS.WALTER.WOBY_BIG_SPRINT_SPEED)
		elseif isturbo then
			if not inst._isturbo then
				inst._isturbo = true
				SetBaseRunSpeed(inst, TUNING.SKILLS.WALTER.WOBY_BIG_TURBO_SPEED)
			end
		elseif inst._isturbo then
			inst._isturbo = false
			SetBaseRunSpeed(inst, TUNING.SKILLS.WALTER.WOBY_BIG_SPRINT_SPEED)
		end
	elseif inst._issprinting then
		inst._issprinting = false
		ClearSprintHungerBurn(inst)
		SetBaseRunSpeedFromHunger(inst, inst.components.hunger:GetPercent())
	end
end

local function OnStarving(inst)
    TriggerTransformation(inst)
end

local function DoRiderSleep(inst, sleepiness, sleeptime)
    inst._ridersleeptask = nil
end

local function OnRiderChanged(inst, data)
	SetSprinting(inst, false)

    if inst._ridersleeptask ~= nil then
        inst._ridersleeptask:Cancel()
        inst._ridersleeptask = nil
    end

    if inst.components.sleeper:IsAsleep() then
        inst.components.sleeper:WakeUp()
    end

	if inst.transforming or inst.components.hunger:IsStarving() then
        if inst.sg.currentstate.name ~= "transform" then
            -- The SG won't listen for the event right now, so we wait a frame
            inst:DoTaskInTime(0, function() inst:PushEvent("transform") end)
        end
    end

	if inst.components.container then
		inst.components.container:Close()
	end

	if inst.components.wobyrack then
		SetRackFxOwner(inst, data and data.newrider or nil)
	end

	inst:UpdateOwnerNewStateListener(inst._playerlink)
end

local function OnRiderSleep(inst, data)
    inst._ridersleep = inst.components.rideable:IsBeingRidden() and {
        time = GetTime(),
        sleepiness = data.sleepiness,
        sleeptime = data.sleeptime,
    } or nil
end

local function OnDash(inst, data)
	local cost =
		(data and data.shadow and TUNING.SKILLS.WALTER.WOBY_BIG_SHADOW_DASH_HUNGER) or
		(IsLunarPowered(inst) and 0) or
		TUNING.SKILLS.WALTER.WOBY_BIG_DASH_HUNGER

	if cost > 0 then
		if HasEndurance(inst) then
			cost = cost * TUNING.SKILLS.WALTER.WOBY_ENDURANCE_HUNGER_RATE_MOD
		end
		inst.components.hunger:DoDelta(-cost)
	end
end

----------------------------------------------------------------------------------------------------------------------------

-- Please note the forager queueing code is also at prefabs/wobysmall.lua for now.

local function TimeoutForageTarget(inst, target)
	inst:RemoveForagerTarget(target)
end

local function IsAllowedToQueueForaging(inst, target)
	if inst.woby_commands_classified == nil or not inst.woby_commands_classified:ShouldForage() then
		return false
	end

	if inst.woby_commands_classified:ShouldSit() or inst.components.rideable:IsBeingRidden() then
		return false
	end

	if inst.woby_commands_classified:IsRecalled() then
		return inst._playerlink ~= nil and inst._playerlink:IsNear(target, TUNING.SKILLS.WALTER.FORAGER_MAX_DISTANCE)
	end

	return true
end

local function OnPlayerNewState(inst, player, data)
	local buffaction = player.bufferedaction -- No locomotor action, server wouldn't know it.

	if buffaction ~= nil and buffaction.target ~= nil and buffaction.action == ACTIONS.PICK then
		if not IsFoodSourcePickable(buffaction.target) or buffaction.target.components.pickable.quickpick then
			return -- Woby is not interested :P
		end

		if not IsAllowedToQueueForaging(inst, buffaction.target) then
			return
		end

		inst:QueueForagerTarget(buffaction.target)

		player:PushEvent("tellwobyforage", inst)
	else
		local lasttarget = inst._forager_targets[#inst._forager_targets]

		if lasttarget ~= nil and lasttarget.components.pickable ~= nil and lasttarget.components.pickable:CanBePicked() then
			-- If it can be picked, Walter didn't finish it!
			inst:RemoveForagerTarget(lasttarget)
		end
	end

	inst:PushEvent("playernewstate", data)
end

local MAX_FORAGING_TARGETS = 5
local FORAGE_TARGET_TIMEOUT = 15

local function QueueForagerTarget(inst, target)
	if table.contains(inst._forager_targets, target) then
		return
	end

	table.insert(inst._forager_targets, target)

	inst._forager_timeout_tasks[target] = inst:DoTaskInTime(FORAGE_TARGET_TIMEOUT, TimeoutForageTarget, target)

	inst:ListenForEvent("onremove", inst._onforagertargetremoved, target)

	if #inst._forager_targets > MAX_FORAGING_TARGETS then
		inst:RemoveCurrentForagerTarget()
	end
end

local function RemoveForagerTarget(inst, target)
	table.removearrayvalue(inst._forager_targets, target)

	inst:RemoveEventCallback("onremove", inst._onforagertargetremoved, target)

	if inst._forager_timeout_tasks[target] ~= nil then
		inst._forager_timeout_tasks[target]:Cancel()
		inst._forager_timeout_tasks[target] = nil
	end
end

local function RemoveCurrentForagerTarget(inst)
	inst:RemoveForagerTarget(inst._forager_targets[1])
end

local function GetForagerTarget(inst)
	local targets = shallowcopy(inst._forager_targets)

	for i, target in ipairs(targets) do
		if inst._playerlink ~= nil and not inst._playerlink:IsNear(target, TUNING.SKILLS.WALTER.FORAGER_MAX_DISTANCE) then
			inst:RemoveForagerTarget(target) -- Drop far away targets.
		else
			return target
		end
	end
end

local function UpdateOwnerNewStateListener(inst, player)
	local skilltreeupdater = player ~= nil and player.components.skilltreeupdater or nil
	local ridden = inst.components.rideable:IsBeingRidden()

	if not ridden and skilltreeupdater ~= nil and skilltreeupdater:IsActivated("walter_woby_foraging") then
		inst:ListenForEvent("newstate", inst._onplayernewstate, player)
	else
		if player ~= nil then
			inst:RemoveEventCallback("newstate", inst._onplayernewstate, player)
		end

		inst:ClearForagerQueue()
	end
end

local function ClearForagerQueue(inst)
	for i, target in ipairs(inst._forager_targets) do
		inst:RemoveEventCallback("onremove", inst._onforagertargetremoved, target)

		if inst._forager_timeout_tasks[target] ~= nil then
			inst._forager_timeout_tasks[target]:Cancel()
			inst._forager_timeout_tasks[target] = nil
		end
	end

	inst._forager_targets = {}
end

-------------------------------------------------------------------------------

local function OnSuccessfulPraisableAction(inst)
	if inst._playerlink ~= nil then
		inst._playerlink:PushEvent("praisewoby", inst)
	end
end

-------------------------------------------------------------------------------

local function RefreshAttunedSkills(inst, player, data)
	--NOTE: could be activate or deactivate
	--      data can be nil when called from LinkToPlayer or _onlostplayerlink
	--      player can be nil when called from _onlostplayerlink

	local skilltreeupdater = player and player.components.skilltreeupdater

	if data == nil or data.skill == "walter_woby_endurance" then
		local hasendurance = skilltreeupdater ~= nil and skilltreeupdater:IsActivated("walter_woby_endurance")
		if player then
			--if player is nil (from _onlostplayerlink), these modifiers will already remove themselves
			if hasendurance then
				inst.components.hunger.burnratemodifiers:SetModifier(player, TUNING.SKILLS.WALTER.WOBY_ENDURANCE_HUNGER_RATE_MOD, "walter_woby_endurance")
			else
				inst.components.hunger.burnratemodifiers:RemoveModifier(player, "walter_woby_endurance")
			end
		end
		if inst.pet_hunger_classified then
			inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.ENDURANCE, hasendurance)
		end

		--refresh run speed as well
		if inst._issprinting then
			SetBaseRunSpeed(inst, inst._isturbo and TUNING.SKILLS.WALTER.WOBY_BIG_TURBO_SPEED or TUNING.SKILLS.WALTER.WOBY_BIG_SPRINT_SPEED)
		else
			SetBaseRunSpeedFromHunger(inst, inst.components.hunger:GetPercent())
		end
	end

	if data == nil or data.skill == "walter_woby_lunar" then
		if skilltreeupdater and skilltreeupdater:IsActivated("walter_woby_lunar") then
			StartWatchingLunarPower(inst)
		else
			StopWatchingLunarPower(inst)
		end
	end

	if player and (data == nil or data.skill == "walter_woby_lunar" or data.skill == "walter_woby_shadow") then
		--if player is nil (from _onlostplayerlink), don't update woby's alignment since she is likely being despawned as well
		local alignment = skilltreeupdater and (
				(skilltreeupdater:IsActivated("walter_woby_lunar") and "lunar") or
				(skilltreeupdater:IsActivated("walter_woby_shadow") and "shadow")
			) or nil
		local showfx = data ~= nil and player._PostActivateHandshakeState_Server == POSTACTIVATEHANDSHAKE.READY
		SetAlignmentBuild(inst, alignment, showfx)
	end

	if player and (data == nil or data.skill == "walter_camp_wobyholder") then
		--if player is nil (from _onlostplayerlink), don't update woby's rack since she is likely being despawned as well
		local showanim = data ~= nil and player._PostActivateHandshakeState_Server == POSTACTIVATEHANDSHAKE.READY
		EnableRack(inst, skilltreeupdater ~= nil and skilltreeupdater:IsActivated("walter_camp_wobyholder"), showanim)
	end

	if player and (data == nil or data.skill == "walter_woby_foraging") then
		inst:UpdateOwnerNewStateListener(player)
	end

	WobyCommon.RefreshCommands(inst, player)
end

local function LinkToPlayer(inst, player, containerrestrictedoverride)
    inst._playerlink = player
    inst.components.follower:SetLeader(player)

	if inst.pet_hunger_classified == nil then
		inst.pet_hunger_classified = SpawnPrefab("pet_hunger_classified")
		inst.pet_hunger_classified:InitializePetInst(inst)
		inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.BIG, true)
		inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.SPRINT_DRAIN, inst._issprinting or false)
		inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.ENDURANCE, HasEndurance(inst))
		inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.LUNAR, inst.alignment == "lunar")
		inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.SHADOW, inst.alignment == "shadow")
		local skin_build = inst:GetSkinBuild()
		if skin_build then
			inst.pet_hunger_classified:SetBuild(skin_build:gsub("woby_big", "status_woby"):gsub("_shadow", ""):gsub("_lunar", ""))
		end
		inst.pet_hunger_classified:AttachClassifiedToPetOwner(player)
	else
		assert(inst.pet_hunger_classified._parent == player)
	end

	if inst.woby_commands_classified == nil then
		inst.woby_commands_classified = SpawnPrefab("woby_commands_classified")
		inst.woby_commands_classified:InitializePetInst(inst)
		inst.woby_commands_classified:AttachClassifiedToPetOwner(player)
	else
		assert(inst.woby_commands_classified._parent == player)
	end

	if containerrestrictedoverride ~= nil then --could be true or false
		WobyCommon.RestrictContainer(inst, containerrestrictedoverride)
	else
		WobyCommon.RestrictContainer(inst, inst.woby_commands_classified:ShouldLockBag())
	end

	inst:ListenForEvent("onactivateskill_server", inst._onskillrefresh, player)
	inst:ListenForEvent("ondeactivateskill_server", inst._onskillrefresh, player)

	if player._PostActivateHandshakeState_Server == POSTACTIVATEHANDSHAKE.READY then
		RefreshAttunedSkills(inst, player, nil)
	else
		inst:ListenForEvent("ms_skilltreeinitialized", inst._onskilltreeinitialized, player)
	end

    inst:ListenForEvent("onremove", inst._onlostplayerlink, player)
end

local function OnPlayerLinkDespawn(inst, forcedrop)
	if inst.components.container ~= nil then
		inst.components.container:Close()
		inst.components.container.canbeopened = false

		if forcedrop or GetGameModeProperty("drop_everything_on_despawn") then
			inst.components.container:DropEverything()
		else
			inst.components.container:DropEverythingWithTag("irreplaceable")
		end
	end

	if inst.components.wobyrack then
		if forcedrop or GetGameModeProperty("drop_everything_on_despawn") then
			inst.components.wobyrack:GetContainer():DropEverything()
		else
			inst.components.wobyrack:GetContainer():DropEverythingWithTag("irreplaceable")
		end
	end

	if inst.components.drownable ~= nil then
		inst.components.drownable.enabled = false
	end

	local fx = SpawnPrefab(inst.spawnfx)
	fx.entity:SetParent(inst.entity)

	inst.components.colourtweener:StartTween({ 0, 0, 0, 1 }, 13 * FRAMES, inst.Remove)

	if not inst.sg:HasStateTag("busy") then
		inst.sg:GoToState("despawn")
	end
end

local function FinishTransformation(inst)
	local x, y, z = inst.Transform:GetWorldPosition()

	local items = {}
	local numslots = inst.components.container:GetNumSlots()
	for i = 1, numslots do
		items[i] = inst.components.container:RemoveItemBySlot(i)
	end

	local rackitems, racknumslots, dryinginfo
	if inst.components.wobyrack then
		local container = inst.components.wobyrack:GetContainer()
		dryinginfo = inst.components.wobyrack:GetDryingInfoSnapshot()
		rackitems = {}
		racknumslots = container:GetNumSlots()
		for i = 1, racknumslots do
			rackitems[i] = container:RemoveItemBySlot(i)
		end
	end

	local wascontainerrestricted = inst.components.container.restrictedtag ~= nil

	local player = inst._playerlink
    local skin_build = inst:GetSkinBuild()
    if skin_build then
        skin_build = skin_build:gsub("woby_big", "pupington_woby")
    end

	if inst.pet_hunger_classified then
		inst.pet_hunger_classified:DetachClassifiedFromPet(inst)
	end
	if inst.woby_commands_classified then
		inst.woby_commands_classified:DetachClassifiedFromPet(inst)
	end

	local rot = inst.Transform:GetRotation()
	local hungerpct = inst.components.hunger:GetPercent() --transfer hunger too since we can now force transformation
    local new_woby = ReplacePrefab(inst, "wobysmall", skin_build, inst.skin_id)
	new_woby.Transform:SetRotation(rot)
	new_woby.components.hunger:SetPercent(math.min(0.94999, hungerpct), true) --make sure we're below 95%
	if new_woby.sg.currentstate.name == "idle" and new_woby.AnimState:IsCurrentAnimation("idle_loop") then
		new_woby.sg.mem.recentlytransformed = true
		new_woby.sg:GoToState("idle")
	else
		new_woby.AnimState:MakeFacingDirty() -- Not needed for clients.
	end

	--transfer pet_hunger_classified to the new prefab
	if inst.pet_hunger_classified then
		new_woby.pet_hunger_classified = inst.pet_hunger_classified
		new_woby.pet_hunger_classified:InitializePetInst(new_woby)
		new_woby.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.BIG, false)
	end
	--transfer woby_commands_classified to the new prefab
	if inst.woby_commands_classified then
		new_woby.woby_commands_classified = inst.woby_commands_classified
		new_woby.woby_commands_classified:InitializePetInst(new_woby)
	end

	for i = 1, numslots do
		local item = items[i]
		if item then
			item.prevcontainer = nil
			item.prevslot = nil

			if not new_woby.components.container:GiveItem(item, i, nil, false) then
				item.Transform:SetPosition(x, y, z)
				if item.components.inventoryitem then
					item.components.inventoryitem:OnDropped(true)
				end
			end
		end
    end

    if inst.components.timer ~= nil then
        inst.components.timer:TransferComponent(new_woby)
    end

	if player ~= nil then
		new_woby:LinkToPlayer(player, wascontainerrestricted)
	    player:OnWobyTransformed(new_woby)
	end

	if rackitems then
		local container = new_woby.components.wobyrack and new_woby.components.wobyrack:GetContainer() or nil
		for i = 1, racknumslots do
			local item = rackitems[i]
			if item then
				item.prevcontainer = nil
				item.prevslot = nil

				if not (container and container:GiveItem(item, i, nil, false)) then
					item.Transform:SetPosition(x, y, z)
					if item.components.inventoryitem then
						item.components.inventoryitem:OnDropped(true)
					end
				end
			end
		end
		if dryinginfo and new_woby.components.wobyrack then
			new_woby.components.wobyrack:ApplyDryingInfoSnapshot(dryinginfo)
		end
	end
end

local WAKE_TO_FOLLOW_DISTANCE = 6
local SLEEP_NEAR_LEADER_DISTANCE = 5

local function IsLeaderSleeping(inst)
    return inst.components.follower.leader and inst.components.follower.leader:HasTag("sleeping")
end

local function IsLeaderTellingStory(inst)
    local leader = inst.components.follower.leader
    return leader and leader.components.storyteller and leader.components.storyteller:IsTellingStory()
end

local function ShouldWakeUp(inst)
    return not (IsLeaderSleeping(inst) or IsLeaderTellingStory(inst)) or not inst.components.follower:IsNearLeader(WAKE_TO_FOLLOW_DISTANCE)
end

local function ShouldSleep(inst)
    return (IsLeaderSleeping(inst) or IsLeaderTellingStory(inst)) and inst.components.follower:IsNearLeader(SLEEP_NEAR_LEADER_DISTANCE)
end

local function OnEat(inst, food, feeder)
	if food:HasTag("pet_treat") then
		feeder:PushEvent("praisewoby")
	end
end

local function RestoreCharacterCollisions(inst)
	inst.Physics:CollidesWith(COLLISION.CHARACTERS)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("wobybig.png")
    inst.MiniMapEntity:SetCanUseCache(false)

    MakeCharacterPhysics(inst, 100, .5)

    inst.DynamicShadow:SetSize(5, 2)
    inst.Transform:SetSixFaced()

    inst.AnimState:SetBank("wobybig")
    inst.AnimState:SetBuild("woby_big_build")
    inst.AnimState:PlayAnimation("idle_loop", true)
    inst.AnimState:Hide("HEAT")

	inst.AnimState:OverrideSymbol("fx_wipe", "wilson_fx", "fx_wipe")

    inst:AddTag("animal")
    inst:AddTag("largecreature")
    inst:AddTag("woby")
    inst:AddTag("handfed")
    inst:AddTag("fedbyall")
    inst:AddTag("dogrider_only")
    inst:AddTag("peacefulmount")

    inst:AddTag("companion")

    inst:AddTag("NOBLOCK")

	--Sneak these into pristine state for optimization
	inst:AddTag("_hunger")

    inst:AddComponent("spawnfader")

	--V2C: matches beefalo's sound table, but for Woby, this is only used for mounted emotes
	inst.sounds = sounds_for_mounted_emotes

	WobyCommon.SetupCommandWheel(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
		--@V2C: #HACK during transformation, replacing prefab collides with itself, causing flicker
		inst.Physics:ClearCollidesWith(COLLISION.CHARACTERS)
		inst:DoStaticTaskInTime(0, RestoreCharacterCollisions)

        return inst
    end

	inst._isincave = TheWorld:HasTag("cave") --cache this, we need it a lot, and it can't change

	--Remove these tags so that they can be added properly when replicating components below
	inst:RemoveTag("_hunger")

    inst:AddComponent("eater")
    inst.components.eater:SetDiet({ FOODTYPE.MONSTER }, { FOODTYPE.MONSTER })
	inst.components.eater.custom_stats_mod_fn = CustomFoodStatsMod
	inst.components.eater:SetOnEatFn(OnEat)

    inst:AddComponent("inspectable")
    inst:AddComponent("timer")

    inst:AddComponent("follower")
    inst.components.follower.keepdeadleader = true
    inst.components.follower.keepleaderduringminigame = true

    inst:AddComponent("rideable")
    inst.components.rideable:SetShouldSave(false)
    inst.components.rideable.canride = true

    inst:AddComponent("sleeper")
    inst.components.sleeper:SetResistance(3)
    inst.components.sleeper.sleeptestfn = ShouldSleep
    inst.components.sleeper.waketestfn = ShouldWakeUp

    inst:AddComponent("hunger")
    inst.components.hunger:SetMax(TUNING.WOBY_BIG_HUNGER)
    inst.components.hunger:SetRate(TUNING.WOBY_BIG_HUNGER_RATE)
    inst.components.hunger:SetOverrideStarveFn(OnStarving)

    MakeLargeBurnableCharacter(inst, "beefalo_body")
    MakeLargeFreezableCharacter(inst, "beefalo_body")

    inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    inst.components.locomotor.walkspeed = TUNING.WOBY_BIG_WALK_SPEED
    SetRunSpeed(inst, TUNING.WOBY_BIG_SPEED.FAST)
    inst.components.locomotor:SetAllowPlatformHopping(true)

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("wobybig")

    inst:AddComponent("embarker")
    inst:AddComponent("drownable")

	inst:AddComponent("colourtweener")
	inst:AddComponent("colouradder")

    MakeHauntablePanic(inst)

    inst:SetBrain(brain)
    inst:SetStateGraph("SGwobybig")

    inst.persists = false

	inst.spawnfx = "spawn_fx_medium"

    inst:ListenForEvent("riderchanged", OnRiderChanged)
    inst:ListenForEvent("hungerdelta", OnHungerDelta)
    inst:ListenForEvent("ridersleep", OnRiderSleep)
	inst:ListenForEvent("ondash_woby", OnDash)

    inst.LinkToPlayer = LinkToPlayer
	inst.OnPlayerLinkDespawn = OnPlayerLinkDespawn
	inst._onlostplayerlink = function(player)
		WobyCommon.RestrictContainer(inst, false)
		inst._playerlink = nil
		RefreshAttunedSkills(inst, nil, nil)
	end
	inst._onskillrefresh = function(player, data)
		RefreshAttunedSkills(inst, player, data)
	end
	inst._onskilltreeinitialized = function(player)
		inst:RemoveEventCallback("ms_skilltreeinitialized", inst._onskilltreeinitialized, player)
		RefreshAttunedSkills(inst, player)
	end
	inst._onplayernewstate = function(player, data)
		OnPlayerNewState(inst, player, data)
	end
	inst._onforagertargetremoved = function(ent)
		table.removearrayvalue(inst._forager_targets, ent)

		if inst._forager_timeout_tasks[ent] ~= nil then
			inst._forager_timeout_tasks[ent]:Cancel()
			inst._forager_timeout_tasks[ent] = nil
		end
	end
	inst._onsuccessfulpraisableaction = function()
		OnSuccessfulPraisableAction(inst)
	end

	inst._forager_targets = {}
	inst._forager_timeout_tasks = {}

	inst.SetSprinting = SetSprinting
	inst.TriggerTransformation = TriggerTransformation
    inst.FinishTransformation = FinishTransformation
	inst.HasEndurance = HasEndurance
	inst.GetForagerTarget = GetForagerTarget
	inst.QueueForagerTarget = QueueForagerTarget
	inst.ClearForagerQueue = ClearForagerQueue
	inst.RemoveForagerTarget = RemoveForagerTarget
	inst.RemoveCurrentForagerTarget = RemoveCurrentForagerTarget
	inst.UpdateOwnerNewStateListener = UpdateOwnerNewStateListener

	inst.ApplySmallBuildOverrides = ApplySmallBuildOverrides
	inst.OnWobySkinChanged = OnWobySkinChanged
    inst.ReskinToolFilterFn = WobyCommon.ReskinToolFilterFn
    inst.ApplyBuildOverrides = ApplyBuildOverrides
    inst.ClearBuildOverrides = ClearBuildOverrides

	inst.OnPreLoad = OnPreLoad

    return inst
end

return Prefab("wobybig", fn, assets, prefabs)