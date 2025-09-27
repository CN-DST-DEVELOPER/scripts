local prefabs = {
    "globalmapicon",
}

--------------------------------------------------------------------------
--[[ Dependencies ]]
--------------------------------------------------------------------------

local WobyCommon = require("prefabs/wobycommon")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local TIMEOUT = 2

local SKILL_TO_PROP =
{
	["walter_woby_itemfetcher"] = "pickup",
	["walter_woby_foraging"] = "foraging",
	["walter_woby_taskaid"] = "working",
	["walter_woby_sprint"] = "sprinting",
	["walter_woby_shadow"] = "shadowdash",
}

local PROP_TO_SKILL = {}
for k, v in pairs(SKILL_TO_PROP) do
	PROP_TO_SKILL[v] = k
end

local LOCKWOBY_USERCMD =
{
	prettyname = nil, --default to STRINGS.UI.BUILTINCOMMANDS.RESCUE.PRETTYNAME
	desc = nil, --default to STRINGS.UI.BUILTINCOMMANDS.RESCUE.DESC
	permission = COMMAND_PERMISSION.USER,
	slash = true,
	usermenu = false,
	servermenu = true,
	menusort = 0,
	params = {},
	vote = false,
	localfn = function(params, caller)
		if caller.woby_commands_classified then
			caller.woby_commands_classified:ExecuteCommand(WobyCommon.COMMANDS.LOCKBAG)
			Profile:SetWobyIsLocked(true)
		end
	end,
}

local UNLOCKWOBY_USERCMD =
{
	prettyname = nil, --default to STRINGS.UI.BUILTINCOMMANDS.RESCUE.PRETTYNAME
	desc = nil, --default to STRINGS.UI.BUILTINCOMMANDS.RESCUE.DESC
	permission = COMMAND_PERMISSION.USER,
	slash = true,
	usermenu = false,
	servermenu = true,
	menusort = 0,
	params = {},
	vote = false,
	localfn = function(params, caller)
		if caller.woby_commands_classified then
			caller.woby_commands_classified:ExecuteCommand(WobyCommon.COMMANDS.UNLOCKBAG)
			Profile:SetWobyIsLocked(false)
		end
	end,
}

--------------------------------------------------------------------------
--Common helpers
--------------------------------------------------------------------------

local function HasSkillFor(inst, prop)
	local skill = PROP_TO_SKILL[prop]
	return skill == nil
		or (inst._parent ~= nil and
			inst._parent.components.skilltreeupdater ~= nil and
			inst._parent.components.skilltreeupdater:IsActivated(skill))
end

local function CancelTurboSprint(inst)
	if inst._parent and inst._parent.sg then
		inst._parent.sg.mem.turbowoby = nil
	end
end

local function ClearBagLockUserCommand(inst)
	if inst.hasbaglockusercmd then
		RemoveUserCommand("lockwoby")
		RemoveUserCommand("unlockwoby")
	end
end

local function DebugPrintBagLock(inst, locked, msg)
	print(string.format("%s %sWoby%s", locked and "Locking" or "Unlocking", msg and (msg.." ") or "", inst._parent and (" for "..tostring(inst._parent)) or "."))
end

local function SetupBagLockUserCommand(inst)
	ClearBagLockUserCommand(inst)
	if inst.baglock:value() then
		AddUserCommand("unlockwoby", UNLOCKWOBY_USERCMD)
	else
		AddUserCommand("lockwoby", LOCKWOBY_USERCMD)
	end
	inst.hasbaglockusercmd = true
end

local function OnBagLockDirty(inst)
	if inst._parent then
		local locked = inst.baglock:value()
		if not inst.skipnextbaglockmsg then
			DebugPrintBagLock(inst, locked)
		end
		if inst._parent.HUD then
			SetupBagLockUserCommand(inst)
			Profile:SetWobyIsLocked(locked)
			if inst.skipnextbaglockmsg then
				inst.skipnextbaglockmsg = nil
			else
				ChatHistory:SendCommandResponse(locked and STRINGS.UI.BUILTINCOMMANDS.LOCKWOBY.NOTIFY or STRINGS.UI.BUILTINCOMMANDS.UNLOCKWOBY.NOTIFY)
			end
		end
	end
end

--------------------------------------------------------------------------
--Server interface
--------------------------------------------------------------------------

local function SetDirty(netvar, val)
	--Forces a netvar to be dirty regardless of value
	netvar:set_local(val)
	netvar:set(val)
end

local function IsBusy_Server(inst)
	return inst._task ~= nil
		or inst._parent == nil
		or inst._parent._PostActivateHandshakeState_Server ~= POSTACTIVATEHANDSHAKE.READY
		or inst:IsOutForDelivery()
end

local function OnActivateSkill(inst, skill)
	if inst.load_data_pending then
		return
	end
	local prop = SKILL_TO_PROP[skill]
	if prop then
		inst[prop]:set(true)
	end
end

local function OnDeactivateSkill(inst, skill)
	local prop = SKILL_TO_PROP[skill]
	if prop then
		inst[prop]:set(false)
	end
end

local function RefreshAttunedSkills(inst, player)
	assert(player == inst._parent)
	local skilltreeupdater = player and player.components.skilltreeupdater or nil
	if inst.load_data_pending then
		for k, v in pairs(SKILL_TO_PROP) do
			if not (skilltreeupdater and skilltreeupdater:IsActivated(k)) then
				inst[v]:set(false)
			end
		end
		inst.load_data_pending = nil
	else
		for k, v in pairs(SKILL_TO_PROP) do
			inst[v]:set(skilltreeupdater ~= nil and skilltreeupdater:IsActivated(k))
		end
	end
end

local function InitializePetInst(inst, pet)
	assert(pet and inst._pet == nil)
	inst._pet = pet
	inst.woby:set(pet)
	inst:ListenForEvent("onremove", inst._onremovepet, pet)
	inst:ListenForEvent("riderchanged", inst._onriderchanged, pet)
	--Already has parent when transfering to another prefab, ie. pets that switch prefabs when transforming
	if inst._parent == nil then
		inst.entity:SetParent(pet.entity)
		inst.Network:SetClassifiedTarget(inst)
	end
    if inst.sit:value() then
        inst._pet.components.follower:DisableLeashing()
        inst:MakeMinimapIcon()
    end
end

local function OnRemovePet(inst, pet)
	assert(pet == inst._pet)
	local player = inst._parent
	if player then
		assert(player.woby_commands_classified == inst)
		ClearBagLockUserCommand(inst)
		inst:RemoveEventCallback("onremove", inst._onremoveplayer, player)
		inst:RemoveEventCallback("onactivateskill_server", inst._onactivateskill, player)
		inst:RemoveEventCallback("ondeactivateskill_server", inst._ondeactivateskill, player)
		player.woby_commands_classified = nil
		inst._parent = nil
		inst:Remove()
	end
end

local function OnRiderChanged(inst, pet, data)
	inst:RecallWoby(true)
end

local function NetworkWobyCourier(player)
    if player.components.wobycourier then
        player.components.wobycourier:NetworkLocation()
    end
end

local function AttachClassifiedToPetOwner(inst, player)
	assert(inst._pet)
	assert(inst._parent == nil)
	assert(player.woby_commands_classified == nil)
	inst._parent = player
	player.woby_commands_classified = inst
	inst.entity:SetParent(player.entity)
	inst.Network:SetClassifiedTarget(player)
	inst:ListenForEvent("onremove", inst._onremoveplayer, player)
	inst:ListenForEvent("onactivateskill_server", inst._onactivateskill, player)
	inst:ListenForEvent("ondeactivateskill_server", inst._ondeactivateskill, player)
	if player._PostActivateHandshakeState_Server == POSTACTIVATEHANDSHAKE.READY then
		RefreshAttunedSkills(inst, player)
	else
		inst:ListenForEvent("ms_skilltreeinitialized", inst._onskilltreeinitialized, player)
	end
	if player.baglock ~= nil then --can be true or false if set
		--This was already set, are we respawning Woby mid-game?
		inst.isnewspawn:set(false)
		inst.baglock:set(player.baglock)
		DebugPrintBagLock(inst, player.baglock, "restored")
	else
		player.baglock = inst.baglock:value()
	end
	inst.skipnextbaglockmsg = true
	OnBagLockDirty(inst)
	inst.skipnextbaglockmsg = nil
    player:DoTaskInTime(0, NetworkWobyCourier) -- Delay a frame for the classified to sync.
end

--This is for transfering to another prefab, ie. pets that switch prefabs when transforming
local function DetachClassifiedFromPet(inst, pet)
	assert(pet and pet == inst._pet)
	inst._pet = nil
	inst.woby:set(nil)
	inst:RemoveEventCallback("onremove", inst._onremovepet, pet)
	inst:RemoveEventCallback("riderchanged", inst._onriderchanged, pet)
	if inst._parent == nil then
		inst.entity:SetParent(nil)
	end
end

local function OnRemovePlayer(inst, player)
	if inst._parent == nil then
		--Already cleared, probably got here after OnRemovePet
		assert(not inst:IsValid())
		return
	end
	assert(player == inst._parent)
	assert(player.woby_commands_classified == inst)
	player.woby_commands_classified = nil
	inst._parent = nil
	inst.entity:SetParent(inst._pet.entity)
	inst.Network:SetClassifiedTarget(inst)
	RefreshAttunedSkills(inst, nil)
	ClearBagLockUserCommand(inst)
end

local function DoAction_Server(inst, action)
	if inst._parent and inst._parent.components.playercontroller then
		local buffaction = BufferedAction(inst._parent, inst._pet, action)
		inst._parent.components.playercontroller:DoAction(buffaction)
		return true
	end
	return false
end

local function ToggleSkillCommand_Server(inst, name)
	if HasSkillFor(inst, name) then
		inst[name]:set(not inst[name]:value())
		return true
	end
	return false
end

local function NotifyWheelIsOpen_Server(inst, open)
	if open then
		if not inst.isclientwheelopen then
			inst.isclientwheelopen = true
			inst:SendCourierWoby(nil) --so she doens't auto-recall
			--but don't restrict containers yet
			if inst._pet.brain then
				inst._pet.brain:ForceUpdate()
			end
		end
		inst.recall = false
	elseif inst.isclientwheelopen then
		inst.isclientwheelopen = false
	end
end

local function IsClientWheelOpen(inst)
	if inst.isclientwheelopen and not (inst._parent and inst._pet:IsNear(inst._parent, 30)) then
		--In case we failed to receive client close wheel RPC
		inst.isclientwheelopen = false
	end
	return inst.isclientwheelopen
end

local function ClearBrainActions(inst)
	if inst._pet.components.locomotor and inst._pet.components.locomotor.bufferedaction then
		inst._pet.components.locomotor:Stop()
		inst._pet.components.locomotor:Clear()
	end

	inst._pet:ClearForagerQueue()

	if inst._pet.brain then
		inst._pet.brain:ForceUpdate()
	end
end

local function SetBagLock(inst, locked)
	inst.baglock:set(locked)
	OnBagLockDirty(inst)
	if inst._parent then
		inst._parent.baglock = locked or false
	end
end

local CmdFns_Server =
{
	[WobyCommon.COMMANDS.PET] =			function(inst) return DoAction_Server(inst, ACTIONS.PET) end,
	[WobyCommon.COMMANDS.MOUNT] =		function(inst) return DoAction_Server(inst, ACTIONS.MOUNT) end,
	[WobyCommon.COMMANDS.SHRINK] = function(inst)
		if inst._pet.TriggerTransformation then
			inst._pet:TriggerTransformation()
			return true
		end
		return false
	end,
	[WobyCommon.COMMANDS.SIT] = function(inst)
		if ToggleSkillCommand_Server(inst, "sit") then
            inst:SendCourierWoby(nil)
			WobyCommon.RestrictContainer(inst._pet, inst:ShouldLockBag())
			if inst.sit:value() then
                inst._pet.components.follower:DisableLeashing()
                inst:MakeMinimapIcon()
				if inst._parent then
					inst._parent:PushEvent("tellwobysit", inst._pet)
				end
				ClearBrainActions(inst)
			else
                inst._pet.components.follower:EnableLeashing()
                inst:ClearMinimapIcon()
				if inst._parent then
					inst._parent:PushEvent("tellwobyfollow", inst._pet)
				end
				if inst._pet.sg and inst._pet.sg:HasStateTag("sitting") then
					inst._pet.sg.currentstate:HandleEvent(inst._pet.sg, "stop_sitting")
				end
			end
			return true
		end
		return false
	end,
	[WobyCommon.COMMANDS.PICKUP] =		function(inst) return ToggleSkillCommand_Server(inst, "pickup") end,
	[WobyCommon.COMMANDS.FORAGING] =	function(inst) return ToggleSkillCommand_Server(inst, "foraging") end,
	[WobyCommon.COMMANDS.WORKING] =		function(inst) return ToggleSkillCommand_Server(inst, "working") end,
	[WobyCommon.COMMANDS.SPRINTING] = function(inst)
		if ToggleSkillCommand_Server(inst, "sprinting") then
			if not inst.sprinting:value() then
				CancelTurboSprint(inst)
			end
			return true
		end
		return false
	end,
	[WobyCommon.COMMANDS.SHADOWDASH] =	function(inst) return ToggleSkillCommand_Server(inst, "shadowdash") end,
	[WobyCommon.COMMANDS.REMEMBERCHEST] = function(inst)
        if inst._parent and inst._pet and
            inst._parent.components.skilltreeupdater and inst._parent.components.skilltreeupdater:IsActivated("walter_camp_wobycourier") and
            inst._parent.components.wobycourier then
            local cx, cy, cz = inst._pet.Transform:GetWorldPosition()
			if inst._parent and inst._parent.HUD and inst._parent.TempFocusRememberChest then
				inst._parent:TempFocusRememberChest(cx, cz)
			end
			if not inst._parent.components.wobycourier:StoreXZ(cx, cz) then
				inst.chest_pos_failed:push()
				if inst._parent then
					if inst._parent.HUD and inst._parent.CancelTempFocusRememberChest then
						inst._parent:CancelTempFocusRememberChest()
					end
					if inst._parent.components.talker then
						inst._parent.components.talker:Say(GetString(inst._parent, "ANNOUNCE_WOBY_REMEMBERCHEST_FAIL"))
					end
				end
			end
			return true --silent UI fail to match client; triggers fail speech instead
        end
        return false
	end,

	--Notification that client has opened/closed spell wheel
	[WobyCommon.COMMANDS.OPENWHEEL] =	function(inst) NotifyWheelIsOpen_Server(inst, true) end,
	[WobyCommon.COMMANDS.CLOSEWHEEL] =	function(inst) NotifyWheelIsOpen_Server(inst, false) end,

	--Other
	[WobyCommon.COMMANDS.LOCKBAG] = function(inst)
		if not inst.baglock:value() then
			SetBagLock(inst, true)
			WobyCommon.RestrictContainer(inst._pet, true)
		end
		return true
	end,
	[WobyCommon.COMMANDS.UNLOCKBAG] = function(inst)
		if inst.baglock:value() then
			SetBagLock(inst, false)
			WobyCommon.RestrictContainer(inst._pet, false)
		end
		return true
	end,
}

local function ExecuteCommand_Server(inst, cmd)
	local fn = CmdFns_Server[cmd]
	if fn then
		return fn(inst)
	end
	print("Unsupported Woby command:", cmd)
	return false
end

local function IsRecalled(inst)
	return inst.recall
end

local function RecallWoby(inst, silent)
	inst.recall = true
    inst:SendCourierWoby(nil)
	WobyCommon.RestrictContainer(inst._pet, inst:ShouldLockBag())
	if inst.sit:value() then
		inst.sit:set(false)
        inst._pet.components.follower:EnableLeashing()
        inst:ClearMinimapIcon()
		if inst._pet.sg and inst._pet.sg:HasStateTag("sitting") then
			inst._pet.sg.currentstate:HandleEvent(inst._pet.sg, "stop_sitting")
		end
	else
		ClearBrainActions(inst)
	end
	if not silent and inst._parent then
		inst._parent:PushEvent("callwoby", inst._pet)
	end
end

local function CancelRecall(inst)
	inst.recall = false
end

local function GetCourierData(inst)
    return inst.courierdata
end

local WOBYCOURIER_TICK_PERIOD = 1 -- For math.
local function CourierWobyIsStuck(_pet, courierdata)
    if not _pet.sg:HasStateTag("moving") then
        courierdata.stuckcounter = nil -- Not moving so reset counter.
        return false
    end

    local distance_from_last = (courierdata.currentpos - courierdata.lastpos):Length()
    local speed = distance_from_last / WOBYCOURIER_TICK_PERIOD
    if speed < 1 then
        courierdata.stuckcounter = (courierdata.stuckcounter or 0) + 1
        if courierdata.stuckcounter >= 3 then
            courierdata.stuckcounter = nil
            return true
        end
    end

    return false
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end
local function CourierWobyDoTeleport(_pet, courierdata, distance_from_dest)
    if courierdata.onspawnfaderout then
        _pet:RemoveEventCallback("spawnfaderout", courierdata.onspawnfaderout)
        _pet:RemoveEventCallback("transform", courierdata.onspawnfaderout)
        courierdata.onspawnfaderout = nil
    end
    local pt = courierdata.destpos
    local distance_adjustment = 0
    if IsAnyPlayerInRange(pt.x, pt.y, pt.z, 64) then
        local radians_from_point = (_pet:GetAngleToPoint(pt.x, pt.y, pt.z) + 180) * DEGREES
        for radius = TUNING.SKILLS.WALTER.COURIER_FADE_DIST, 4, -4 do
            local offset = FindWalkableOffset(pt, radians_from_point, radius, math.floor(radius * 0.25), false, true, NoHoles)
            if offset ~= nil then
                offset.x = offset.x + pt.x
                offset.z = offset.z + pt.z
                if IsAnyPlayerInRange(offset.x, pt.y, offset.z, 64) then
                    distance_adjustment = radius
                    pt = offset
                    break
                end
            end
        end
    end
    _pet.Transform:SetPosition(pt.x, pt.y, pt.z)

    local runspeed = math.max(_pet.components.locomotor:GetRunSpeed() or 1, 1)
    local time_to_travel = (distance_from_dest - distance_adjustment) / runspeed
    if time_to_travel > 0 then
        courierdata.teleporttimetoarrive = time_to_travel
        courierdata.removed = true
        _pet:RemoveFromScene()
    else
        _pet.components.spawnfader:FadeIn()
    end
end

local function CourierWobyShouldTeleport(_pet, courierdata)
    if _pet:IsAsleep() then
        return true, true
    end

    if CourierWobyIsStuck(_pet, courierdata) then
        return true, false
    end

    if courierdata.dofades then
        local distance_from_start = (courierdata.currentpos - courierdata.startpos):Length()
        if distance_from_start > TUNING.SKILLS.WALTER.COURIER_FADE_DIST then
            return true, false
        end
    end

    return false, false
end

local function CourierWobyTick(inst)
    local _pet, courierdata = inst._pet, inst.courierdata
    if courierdata.teleporttimetoarrive then
        courierdata.teleporttimetoarrive = courierdata.teleporttimetoarrive - WOBYCOURIER_TICK_PERIOD
        if courierdata.teleporttimetoarrive > 0 then
            return -- Still traveling.
        end
        courierdata.teleporttimetoarrive = nil
        courierdata.removed = nil
        _pet:ReturnToScene()
        _pet.components.spawnfader:FadeIn()
    end

    courierdata.currentpos = _pet:GetPosition()
    local distance_from_dest = (courierdata.currentpos - courierdata.destpos):Length()
    if distance_from_dest < TUNING.SKILLS.WALTER.COURIER_CHEST_DETECTION_RADIUS then
        -- We have arrived.
        courierdata.teleported = true
        if courierdata.ischest then
            if _pet.woby_commands_classified.outfordelivery:value() and _pet:IsAsleep() then
                if courierdata.deliverypausedtime then
                    courierdata.deliverypausedtime = courierdata.deliverypausedtime - WOBYCOURIER_TICK_PERIOD
                    if courierdata.deliverypausedtime < 0 then
                        courierdata.deliverypausedtime = nil
                    end
                end
                if not courierdata.deliverypausedtime then
                    WobyCommon.WobyCourier_ForceDelivery(_pet, 1)
                    if _pet.woby_commands_classified.outfordelivery:value() then
                        courierdata.deliverypausedtime = 2
                    end
                end
            end
            if not _pet.woby_commands_classified.outfordelivery:value() then
                courierdata.deliveredreturncounter = (courierdata.deliveredreturncounter or 0) + 1
                if courierdata.deliveredreturncounter >= 5 then
                    courierdata.deliveredreturncounter = nil
                    -- Finished delivering and should return.
					_pet.woby_commands_classified:RecallWoby(true) -- Clears courierdata link.
                    return
                end
            end
        else
            -- Arrived at person do nothing and wait for Walter to call back.
			_pet.woby_commands_classified.outfordelivery:set(false)

			-- Make her container unrestricted
			WobyCommon.RestrictContainer(_pet, false)
        end
    else
        if not courierdata.teleported then
            local shouldteleport, shouldteleportinstantly = CourierWobyShouldTeleport(_pet, courierdata)
            if courierdata.doimmediatefadeteleport then
                shouldteleport, shouldteleportinstantly = true, false
                courierdata.doimmediatefadeteleport = nil
            end
            if shouldteleport then
                courierdata.teleported = true
                if shouldteleportinstantly then
                    CourierWobyDoTeleport(_pet, courierdata, distance_from_dest)
                else
                    courierdata.onspawnfaderout = function()
                        CourierWobyDoTeleport(_pet, courierdata, distance_from_dest)
                    end
                    _pet:ListenForEvent("spawnfaderout", courierdata.onspawnfaderout)
                    _pet:ListenForEvent("transform", courierdata.onspawnfaderout)
                    _pet.components.spawnfader:FadeOut()
                end
            end
        elseif courierdata.onspawnfaderout and _pet:IsAsleep() then
            CourierWobyDoTeleport(_pet, courierdata, distance_from_dest)
        end
    end
    courierdata.lastpos = courierdata.currentpos
end

local function SendCourierWoby(inst, data)
    if inst.couriertask ~= nil then
        inst.couriertask:Cancel()
        inst.couriertask = nil
    end
    if inst.courierdata then
        if inst.courierdata.onspawnfaderout then
            inst._pet:RemoveEventCallback("spawnfaderout", inst.courierdata.onspawnfaderout)
            inst._pet:RemoveEventCallback("transform", inst.courierdata.onspawnfaderout)
            inst.courierdata.onspawnfaderout = nil
            inst._pet.components.spawnfader:FadeIn()
        end
        if inst.courierdata.removed and data == nil then
            inst.courierdata.removed = nil
            inst._pet:ReturnToScene()
            inst._pet.components.spawnfader:FadeIn()
        end
    end
    inst.courierdata = data
    if inst.courierdata then
        inst.courierdata.startpos = inst._pet:GetPosition()
        inst.courierdata.currentpos = inst.courierdata.startpos
        inst.courierdata.lastpos = inst.courierdata.startpos
        local distance = (inst.courierdata.startpos - inst.courierdata.destpos):Length()
        if distance > TUNING.SKILLS.WALTER.COURIER_FADE_DIST * 2 then
            inst.courierdata.dofades = true
        end
        if inst._pet:GetCurrentPlatform() ~= nil then
            inst.courierdata.doimmediatefadeteleport = true
        end
        inst.couriertask = inst:DoPeriodicTask(WOBYCOURIER_TICK_PERIOD, inst.CourierWobyTick)
        inst.sit:set(true)
        inst._pet.components.follower:DisableLeashing()
        inst:MakeMinimapIcon()
        ClearBrainActions(inst)
        if distance > TUNING.SKILLS.WALTER.COURIER_CHEST_DETECTION_RADIUS then
            if inst._pet.sg and inst._pet.sg:HasStateTag("sitting") then
                inst._pet.sg.currentstate:HandleEvent(inst._pet.sg, "stop_sitting")
            end
        end
		inst.outfordelivery:set(true)
		if inst._parent then
			inst._parent:PushEvent("tellwobycourier", inst._pet)
		end
	else
		inst.outfordelivery:set(false)
    end
end

local function MakeMinimapIcon(inst)
    if inst.wobyicon then
        if inst.wobyicon:IsValid() then
            inst.wobyicon:Remove()
        end
        inst.wobyicon = nil
    end
    if inst._parent and inst._parent.userid and inst._parent.userid ~= "" then
        inst.wobyicon = SpawnPrefab("globalmapicon")
        inst.wobyicon.MiniMapEntity:SetPriority(10)
        inst.wobyicon.MiniMapEntity:SetRestriction("player_" .. inst._parent.userid)
        inst.wobyicon:TrackEntity(inst._pet) -- Handles deleting wobyicon if inst._pet removes.
    end
end

local function ClearMinimapIcon(inst)
    if inst.wobyicon then
        if inst.wobyicon:IsValid() then
            inst.wobyicon:Remove()
        end
        inst.wobyicon = nil
    end
end

local function OnSave(inst)
	return
	{
		sit = inst.sit:value() or nil,
		pickup = inst.pickup:value() or nil,
		foraging = inst.foraging:value() or nil,
		working = inst.working:value() or nil,
		sprinting = inst.sprinting:value() or nil,
		shadowdash = inst.shadowdash:value() or nil,
		bagunlock = not inst.baglock:value() or nil,
	}
end

local function OnLoad(inst, data)
	inst.isnewspawn:set(false)
	DebugPrintBagLock(inst, not (data and data.bagunlock), "loaded")
	if data == nil then
		return
	end
	if inst._parent == nil or inst._parent._PostActivateHandshakeState_Server ~= POSTACTIVATEHANDSHAKE.READY then
		inst.load_data_pending = true
	end
	inst.pickup:set(data.pickup or false)
	inst.foraging:set(data.foraging or false)
	inst.working:set(data.working or false)
	inst.sprinting:set(data.sprinting or false)
	inst.shadowdash:set(data.shadowdash or false)
	if data.sit and inst.courierdata == nil and not inst.sit:value() then
		inst.sit:set(true)
		inst._pet.components.follower:DisableLeashing()
        inst:MakeMinimapIcon()
		ClearBrainActions(inst)
	end
	if data.bagunlock then
		inst.skipnextbaglockmsg = true
		SetBagLock(inst, false)
		inst.skipnextbaglockmsg = nil
	end
	if inst.courierdata == nil or inst.courierdata.ischest then
		WobyCommon.RestrictContainer(inst._pet, inst.baglock:value())
	end
end

--------------------------------------------------------------------------
--Client interface
--------------------------------------------------------------------------

local function IsBusy_Client(inst)
	return inst._task ~= nil
		or inst._parent == nil
		or inst._parent._PostActivateHandshakeState_Client ~= POSTACTIVATEHANDSHAKE.READY
		or inst:IsOutForDelivery()
end

local function ResetPreview(inst)
	inst._task = nil
	for k, v in pairs(inst._preview) do
		inst._preview[k] = nil
	end
end

local function DoAction_Client(inst, action, cmd)
	if inst._parent and inst._parent.components.playercontroller and inst.woby:value() then
		local buffaction = BufferedAction(inst._parent, inst.woby:value(), action)
		if inst._parent.components.locomotor == nil then
			buffaction.non_preview_cb = function()
				SendRPCToServer(RPC.WobyCommand, cmd)
			end
		elseif inst._parent.components.playercontroller:CanLocomote() then
			buffaction.preview_cb = function()
				SendRPCToServer(RPC.WobyCommand, cmd)
			end
		else
			return false
		end
		inst._parent.components.playercontroller:DoAction(buffaction)
		return true
	end
	return false
end

local function ToggleSkillCommand_Client(inst, name, cmd)
	if HasSkillFor(inst, name) then
		inst._preview[name] = not inst[name]:value()
		inst._task = inst:DoStaticTaskInTime(TIMEOUT, ResetPreview)
		SendRPCToServer(RPC.WobyCommand, cmd)
		return true
	end
	return false
end

local function BasicCommand_Client(inst, cmd)
	SendRPCToServer(RPC.WobyCommand, cmd)
	return true
end

local CmdFns_Client =
{
	[WobyCommon.COMMANDS.PET] =			function(inst, cmd) return DoAction_Client(inst, ACTIONS.PET, cmd) end,
	[WobyCommon.COMMANDS.MOUNT] =		function(inst, cmd) return DoAction_Client(inst, ACTIONS.MOUNT, cmd) end,
	[WobyCommon.COMMANDS.SHRINK] =		BasicCommand_Client,
	[WobyCommon.COMMANDS.SIT] =			function(inst, cmd) return ToggleSkillCommand_Client(inst, "sit", cmd) end,
	[WobyCommon.COMMANDS.PICKUP] =		function(inst, cmd) return ToggleSkillCommand_Client(inst, "pickup", cmd) end,
	[WobyCommon.COMMANDS.FORAGING] =	function(inst, cmd) return ToggleSkillCommand_Client(inst, "foraging", cmd) end,
	[WobyCommon.COMMANDS.WORKING] =		function(inst, cmd) return ToggleSkillCommand_Client(inst, "working", cmd) end,
	[WobyCommon.COMMANDS.SPRINTING] =	function(inst, cmd)
		if ToggleSkillCommand_Client(inst, "sprinting", cmd) then
			if not inst:GetValue("sprinting") then
				CancelTurboSprint(inst)
			end
			return true
		end
		return false
	end,
	[WobyCommon.COMMANDS.SHADOWDASH] =	function(inst, cmd) return ToggleSkillCommand_Client(inst, "shadowdash", cmd) end,	
	[WobyCommon.COMMANDS.REMEMBERCHEST] = function(inst, cmd)
		if inst._parent and inst._parent.TempFocusRememberChest and inst.woby:value() then
			local x, y, z = inst.woby:value().Transform:GetWorldPosition()
			inst._parent:TempFocusRememberChest(x, z)
		end
		SendRPCToServer(RPC.WobyCommand, cmd)
		return true
	end,
	[WobyCommon.COMMANDS.LOCKBAG] =			BasicCommand_Client,
	[WobyCommon.COMMANDS.UNLOCKBAG] =		BasicCommand_Client,
}

local IgnoreBusy_Client =
{
	[WobyCommon.COMMANDS.LOCKBAG] = true,
	[WobyCommon.COMMANDS.UNLOCKBAG] = true,
}

local function ExecuteCommand_Client(inst, cmd)
	if not IgnoreBusy_Client[cmd] and IsBusy_Client(inst) then
		return false
	end
	local fn = CmdFns_Client[cmd]
	if fn then
		return fn(inst, cmd)
	end
	print("Unsupported Woby command:", cmd)
	return false
end

local function NotifyWheelIsOpen_Client(inst, open)
	SendRPCToServer(RPC.WobyCommand, open and WobyCommon.COMMANDS.OPENWHEEL or WobyCommon.COMMANDS.CLOSEWHEEL)
end

local function OnSprintingDirty(inst)
	ResetPreview(inst)
	if not inst:GetValue("sprinting")then
		CancelTurboSprint(inst)
	end
end

local function OnWobyDirty(inst)
	if inst._parent and inst.woby:value() then
		WobyCommon.SetupClientCommandWheelRefreshers(inst.woby:value(), inst._parent)
	end
end

local function OnWobyCourierChestDirty(inst)
    if inst._parent then
        inst._parent:PushEvent("updatewobycourierchesticon")
    end
end

local function OnWobyCourierChestFailed(inst)
	if inst._parent and inst._parent.CancelTempFocusRememberChest then
		inst._parent:CancelTempFocusRememberChest()
	end
end

local function OnEntityReplicated(inst)
	--NOTE: parent is the player; pet inst may not actually be in view of client
	inst._parent = inst.entity:GetParent()
	if inst._parent == nil then
		print("Unable to initialize classified data for Woby commands")
	else
		assert(inst._parent.woby_commands_classified == nil)
		inst._parent.woby_commands_classified = inst
		if inst._parent.HUD then
			SetupBagLockUserCommand(inst)
		end
	end
end

--------------------------------------------------------------------------
--Common interface
--------------------------------------------------------------------------

local function GetWoby(inst)
	return inst.woby:value()
end

local function GetValue(inst, name)
	local val = inst._preview[name]
	if val ~= nil then
		return val
	end
	return inst[name]:value()
end

local function ShouldSit(inst)			return GetValue(inst, "sit")			end
local function ShouldPickup(inst)		return GetValue(inst, "pickup")			end
local function ShouldForage(inst)		return GetValue(inst, "foraging")		end
local function ShouldWork(inst)			return GetValue(inst, "working")		end
local function ShouldSprint(inst)		return GetValue(inst, "sprinting")		end
local function ShouldShadowDash(inst)	return GetValue(inst, "shadowdash")		end
local function ShouldLockBag(inst)		return GetValue(inst, "baglock")		end
local function IsOutForDelivery(inst)	return inst.outfordelivery:value()		end

--------------------------------------------------------------------------

local function RegisterNetListeners(inst)
	inst._task = nil

	if not TheWorld.ismastersim then
		inst:ListenForEvent("isdirty", ResetPreview)
		inst:ListenForEvent("sprintingdirty", OnSprintingDirty)
		inst:ListenForEvent("baglockdirty", OnBagLockDirty)
		inst:ListenForEvent("wobydirty", OnWobyDirty)
        inst:ListenForEvent("chest_posdirty", OnWobyCourierChestDirty)
		inst:ListenForEvent("woby_commands.chest_pos_failed", OnWobyCourierChestFailed)

		if inst.woby:value() then
			OnWobyDirty(inst)
		end
		if not inst.sprinting:value() then
			CancelTurboSprint(inst)
		end
        if inst.chest_posx:value() ~= WOBYCOURIER_NO_CHEST_COORD and inst.chest_posz:value() ~= WOBYCOURIER_NO_CHEST_COORD then
            OnWobyCourierChestDirty(inst)
        end
	end

	if inst._parent then
		if inst._parent.HUD then
			SetupBagLockUserCommand(inst)
			if inst.isnewspawn:value() then
				local lockedpref = Profile:GetWobyIsLocked()
				DebugPrintBagLock(inst, lockedpref, "spawned")
				if not lockedpref then
					inst.skipnextbaglockmsg = true
					inst:ExecuteCommand(WobyCommon.COMMANDS.UNLOCKBAG)
				end
			end
		end
	end
end

local function OnRemoveEntity(inst)
	local player = inst._parent
	if player then
		if player.HUD then
			if player.HUD:GetCurrentOpenSpellBook() and
				player.HUD:GetCurrentOpenSpellBook() == inst.woby:value()
			then
				player.HUD:CloseSpellWheel()
			end
			ClearBagLockUserCommand(inst)
		end
		if not TheWorld.ismastersim then
			assert(player.woby_commands_classified == inst)
			player.woby_commands_classified = nil
			inst._parent = nil
		end
	end
end

--------------------------------------------------------------------------

local function fn()
	local inst = CreateEntity()

	if TheWorld.ismastersim then
		inst.entity:AddTransform() --So we can follow parent's sleep state
	end
	inst.entity:AddNetwork()
	inst.entity:Hide()
	inst:AddTag("CLASSIFIED")

	--Variables for tracking local preview state;
	--Whenever a server sync is received, all local dirty states are reverted
	inst._preview = {}

	inst.woby = net_entity(inst.GUID, "woby_commands.woby", "wobydirty")

	--NOTE: Don't change the name of these properties!
	--      Woby's command wheel uses them to call GetValue.
	inst.sit = net_bool(inst.GUID, "woby_commands.sit", "isdirty")
	inst.pickup = net_bool(inst.GUID, "woby_commands.pickup", "isdirty")
	inst.foraging = net_bool(inst.GUID, "woby_commands.foraging", "isdirty")
	inst.working = net_bool(inst.GUID, "woby_commands.working", "isdirty")
	inst.sprinting = net_bool(inst.GUID, "woby_commands.sprinting", "sprintingdirty") -- attn: special handler!
	inst.shadowdash = net_bool(inst.GUID, "woby_commands.shadowdash", "isdirty")
	inst.outfordelivery = net_bool(inst.GUID, "woby_commands.outfordelivery")
    -- NOTES(JBK): Put the chest position last since this does not change often.
    inst.chest_posx = net_float(inst.GUID, "woby_commands.chest_posx", "chest_posdirty")
    inst.chest_posz = net_float(inst.GUID, "woby_commands.chest_posz", "chest_posdirty")
    inst.chest_posx:set(WOBYCOURIER_NO_CHEST_COORD)
    inst.chest_posz:set(WOBYCOURIER_NO_CHEST_COORD)
	inst.chest_pos_failed = net_event(inst.GUID, "woby_commands.chest_pos_failed")

	inst.baglock = net_bool(inst.GUID, "woby_commands.baglock", "baglockdirty") -- attn: special handler!
    inst.baglock:set(true)
	inst.hasbaglockusercmd = false

	inst.isnewspawn = net_bool(inst.GUID, "woby_commands.isnewspawn")
	inst.isnewspawn:set(true)

	--Delay net listeners until after initial values are deserialized
	inst._task = inst:DoStaticTaskInTime(0, RegisterNetListeners)

	inst.GetWoby = GetWoby
	inst.GetValue = GetValue
	--
	inst.ShouldSit = ShouldSit
	inst.ShouldPickup = ShouldPickup
	inst.ShouldForage = ShouldForage
	inst.ShouldWork = ShouldWork
	inst.ShouldSprint = ShouldSprint
	inst.ShouldShadowDash = ShouldShadowDash
	inst.ShouldLockBag = ShouldLockBag
	inst.IsOutForDelivery = IsOutForDelivery
	--
	inst.OnRemoveEntity = OnRemoveEntity

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		--Client interface
		inst.OnEntityReplicated = OnEntityReplicated
		inst.IsBusy = IsBusy_Client
		inst.ExecuteCommand = ExecuteCommand_Client
		inst.NotifyWheelIsOpen = NotifyWheelIsOpen_Client

		return inst
	end

	inst.isclientwheelopen = false
	inst.recall = false
    --inst.courierdata = nil

	--Server interface
	inst.InitializePetInst = InitializePetInst
	inst.AttachClassifiedToPetOwner = AttachClassifiedToPetOwner
	inst.DetachClassifiedFromPet = DetachClassifiedFromPet
	inst.IsBusy = IsBusy_Server
	inst.ExecuteCommand = ExecuteCommand_Server
	inst.NotifyWheelIsOpen = NotifyWheelIsOpen_Server
	inst.IsClientWheelOpen = IsClientWheelOpen
	inst.IsRecalled = IsRecalled
	inst.RecallWoby = RecallWoby
	inst.CancelRecall = CancelRecall
    inst.GetCourierData = GetCourierData
    inst.SendCourierWoby = SendCourierWoby
    inst.CourierWobyTick = CourierWobyTick
    inst.MakeMinimapIcon = MakeMinimapIcon
    inst.ClearMinimapIcon = ClearMinimapIcon

	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	inst._onremovepet = function(pet) OnRemovePet(inst, pet) end
	inst._onriderchanged = function(pet, data) OnRiderChanged(inst, pet, data) end
	inst._onremoveplayer = function(player) OnRemovePlayer(inst, player) end
	inst._onactivateskill = function(player, data) OnActivateSkill(inst, data and data.skill or nil) end
	inst._ondeactivateskill = function(player, data) OnDeactivateSkill(inst, data and data.skill or nil) end
	inst._onskilltreeinitialized = function(player)
		inst:RemoveEventCallback("ms_skilltreeinitialized", inst._onskilltreeinitialized, player)
		RefreshAttunedSkills(inst, player)
	end

	inst.persists = false

	return inst
end

return Prefab("woby_commands_classified", fn, nil, prefabs)
