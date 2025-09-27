local WobyCommon = require("prefabs/wobycommon")

local assets =
{
	Asset("ANIM", "anim/woby_big_shadow_build.zip"),
	Asset("ANIM", "anim/pupington_basic.zip"),
	Asset("ANIM", "anim/pupington_emotes.zip"),
	Asset("ANIM", "anim/pupington_traits.zip"),
	Asset("ANIM", "anim/pupington_jump.zip"),
	Asset("ANIM", "anim/pupington_action.zip"),

	Asset("ANIM", "anim/pupington_woby_build.zip"),
	Asset("ANIM", "anim/pupington_woby_lunar_build.zip"),
	Asset("ANIM", "anim/pupington_woby_shadow_build.zip"),
	Asset("ANIM", "anim/pupington_transform.zip"),
	Asset("ANIM", "anim/woby_big_build.zip"),
	Asset("ANIM", "anim/woby_big_lunar_build.zip"),
	Asset("ANIM", "anim/woby_big_shadow_build.zip"),

	Asset("ANIM", "anim/spell_icons_woby.zip"),
	Asset("ANIM", "anim/ui_woby_3x3.zip"),

	Asset("ANIM", "anim/woby_rack.zip"),
	Asset("ANIM", "anim/wilson_fx.zip"),

	Asset("SCRIPT", "scripts/prefabs/wobycommon.lua"),
}

local prefabs =
{
	"wobybig",
	"woby_rack_container",
	"pet_hunger_classified",
	"woby_commands_classified",
}

local brain = require("brains/wobysmallbrain")

-------------------------------------------------------------------------------

--This applies wobysmall alignment build or overrides
local function _ApplyAlignmentOverrides_Internal(inst, alignment, skin_build)
	local base_name = "pupington_woby"
	if alignment then
		base_name = base_name.."_"..alignment
	end
	local base_build = base_name.."_build"
	if skin_build then
		if alignment then
			for _, symbol in ipairs(WobyCommon.SMALL_SYMBOLS) do
				inst.AnimState:OverrideItemSkinSymbol(symbol, skin_build, symbol, inst.GUID, base_build)
			end
		else
			--Lunar/shadow builds have the same symbols as the base build
			inst.AnimState:ClearOverrideBuild(base_build)
		end
	else
        inst.AnimState:ClearOverrideBuild(base_build)
		inst.AnimState:SetBuild(base_build)
	end
end

--This applies wobybig normal/alignment overrides
local function _ApplyBigBuildOverrides_Internal(inst, alignment, skin_build)
	local base_name = "woby_big"
	if alignment then
		base_name = base_name.."_"..alignment
	end
	local base_build = base_name.."_build"
	if skin_build then
		skin_build = skin_build:gsub("pupington_woby", "woby_big")
		for _, symbol in ipairs(WobyCommon.BIG_SYMBOLS) do
			inst.AnimState:OverrideItemSkinSymbol(symbol, skin_build, symbol, inst.GUID, base_build)
		end
	else
		inst.AnimState:AddOverrideBuild(base_build)
	end
end

local function ShowRackItem(inst, slot, name, build)
	inst.AnimState:OverrideSymbol("swap_dried"..tostring(slot), build, name)
	inst.AnimState:OverrideSymbol("rope"..tostring(slot), "woby_rack", "rope")
end

local function HideRackItem(inst, slot)
	inst.AnimState:ClearOverrideSymbol("swap_dried"..tostring(slot))
	inst.AnimState:OverrideSymbol("rope"..tostring(slot), "woby_rack", "rope_empty")
end

--Used by sg: this applies wobybig normal/alignment overrides during transform state
local function ApplyBigBuildOverrides(inst)
	if not inst._hasbigbuild then
		_ApplyBigBuildOverrides_Internal(inst, inst.alignment, inst:GetSkinBuild())
		if inst.components.wobyrack then
			inst.components.wobyrack:SetShowItemFn(ShowRackItem)
			inst.components.wobyrack:SetHideItemFn(HideRackItem)
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
		inst._hasbigbuild = true
	end
end

--Used by prefabskin.lua
local function OnWobySkinChanged(inst, skin_build)
	if inst._hasbigbuild then
		_ApplyBigBuildOverrides_Internal(inst, inst.alignment, skin_build)
	end
	_ApplyAlignmentOverrides_Internal(inst, inst.alignment, skin_build)

	if inst.pet_hunger_classified then
		inst.pet_hunger_classified:SetBuild(skin_build and skin_build:gsub("pupington_woby", "status_woby"):gsub("_shadow", ""):gsub("_lunar", "") or nil)
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

local function EnableRack(inst, enable, showanim)
	if enable then
		if inst.components.wobyrack == nil then
			inst:AddComponent("wobyrack")
			inst.components.container.onanyopenfn = OnAnyOpen
			inst.components.container.onanyclosefn = OnAnyClose
			inst.AnimState:OverrideSymbol("swap_rack", "woby_rack", "swap_rack")
			if inst._hasbigbuild then
				inst.AnimState:AddOverrideBuild("woby_rack")
				for i = 1, 3 do
					inst.AnimState:OverrideSymbol("rope"..tostring(i), "woby_rack", "rope_empty")
				end
				inst.components.wobyrack:SetShowItemFn(ShowRackItem)
				inst.components.wobyrack:SetHideItemFn(HideRackItem)
			end
			if inst.components.container:IsOpenedBy(inst._playerlink) then
				inst.components.wobyrack:GetContainer():Open(inst._playerlink)
			end
			if showanim then
				inst.sg:HandleEvent("showrack")
			end
		end
	elseif inst.components.wobyrack then
		inst.components.container.onanyopenfn = nil
		inst.components.container.onanyclosefn = nil
		inst:RemoveComponent("wobyrack")
		inst.AnimState:ClearOverrideSymbol("swap_rack")
		if inst._hasbigbuild then
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

local WAKE_TO_FOLLOW_DISTANCE = 6
local SLEEP_NEAR_LEADER_DISTANCE = 5

local HUNGRY_PERISH_PERCENT = 0.5 -- matches stale tag
local STARVING_PERISH_PERCENT = 0.2 -- matches spoiked tag

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

-------------------------------------------------------------------------------
local function GetPeepChance(inst)
    local hunger_percent = inst.components.hunger:GetPercent()
    if hunger_percent <= 0 then
        return 0.01
    end

    return 0
end

local function IsAffectionate(inst)
    return true
end

local function IsPlayful(inst)
	return true
end

local function IsSuperCute(inst)
	return true
end

local function HasEndurance(inst)
	return inst._playerlink ~= nil
		and inst._playerlink.components.skilltreeupdater ~= nil
		and inst._playerlink.components.skilltreeupdater:IsActivated("walter_woby_endurance")
end

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
		inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.BIG, false)
		inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.SPRINT_DRAIN, false)
		inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.ENDURANCE, HasEndurance(inst))
		inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.LUNAR, inst.alignment == "lunar")
		inst.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.SHADOW, inst.alignment == "shadow")
		local skin_build = inst:GetSkinBuild()
		if skin_build then
			inst.pet_hunger_classified:SetBuild(skin_build:gsub("pupington_woby", "status_woby"):gsub("_shadow", ""):gsub("_lunar", ""))
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
        skin_build = skin_build:gsub("pupington_woby", "woby_big")
    end

	if inst.pet_hunger_classified then
		inst.pet_hunger_classified:DetachClassifiedFromPet(inst)
	end
	if inst.woby_commands_classified then
		inst.woby_commands_classified:DetachClassifiedFromPet(inst)
	end

	local rot = inst.Transform:GetRotation()
    local new_woby = ReplacePrefab(inst, "wobybig", skin_build, inst.skin_id)
	new_woby.Transform:SetRotation(rot)
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
		new_woby.pet_hunger_classified:SetFlagBit(WobyCommon.FLAGBITS.BIG, true)
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

local function OnStarving(inst)
    -- Critters don't have the health component, so we override the starvefn to prevent a crash
end

local function TriggerTransformation(inst)
    if inst.sg.currentstate.name ~= "transform" then
        inst.persists = false

        if inst.components.container:IsOpen() then
            inst.components.container:Close()
        end

        inst:AddTag("NOCLICK")
        inst:PushEvent("transform")
    end
end

local function OnHungerDelta(inst, data)
    if data.newpercent >= 0.95 then
        TriggerTransformation(inst)
    end
end

local function CustomFoodStatsMod(inst, health_delta, hunger_delta, sanity_delta, food, feeder)
	if food and food.prefab == "woby_treat" and hunger_delta and hunger_delta > 0 then
		hunger_delta = hunger_delta * 3
	end
	return health_delta, hunger_delta, sanity_delta
end

----------------------------------------------------------------------------------------------------------

-- Please note the forager queueing code is also at prefabs/wobybig.lua for now.

local function TimeoutForageTarget(inst, target)
	inst:RemoveForagerTarget(target)
end

local function IsAllowedToQueueForaging(inst, target)
	if inst.woby_commands_classified == nil or not inst.woby_commands_classified:ShouldForage() then
		return false
	end

	if inst.woby_commands_classified:ShouldSit() then
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

	if skilltreeupdater ~= nil and skilltreeupdater:IsActivated("walter_woby_foraging") then
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

----------------------------------------------------------------------------------------------------------------------

local function OnSuccessfulPraisableAction(inst)
	if inst._playerlink ~= nil then
		inst._playerlink:PushEvent("praisewoby", inst)
	end
end

----------------------------------------------------------------------------------------------------------------------

local function OnEat(inst, food, feeder)
	if food:HasTag("pet_treat") then
		feeder:PushEvent("treatwoby", inst)
	end
end

local function OnPet(inst, petter)
	if petter then
		petter:PushEvent("treatwoby", inst)
	end
end

----------------------------------------------------------------------------------------------------------------------

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

    inst.MiniMapEntity:SetIcon("wobysmall.png")
    inst.MiniMapEntity:SetCanUseCache(false)

    inst.DynamicShadow:SetSize(1.75, 1)
    inst.Transform:SetFourFaced()

    inst.AnimState:SetBank("pupington")
    inst.AnimState:SetBuild("pupington_woby_build")
    inst.AnimState:PlayAnimation("idle_loop")

	inst.AnimState:OverrideSymbol("fx_wipe", "wilson_fx", "fx_wipe")

    MakeCharacterPhysics(inst, 1, .5)

    -- critters dont really go do entitysleep as it triggers a teleport to near the owner, so no point in hitting the physics engine.
	inst.Physics:SetDontRemoveOnSleep(true)

    inst:AddTag("critter")
    inst:AddTag("fedbyall")
    inst:AddTag("companion")
    inst:AddTag("notraptrigger")
    inst:AddTag("noauradamage")
    inst:AddTag("small_livestock")
    inst:AddTag("noabandon")
    inst:AddTag("NOBLOCK")

	--Sneak these into pristine state for optimization
	inst:AddTag("_hunger")

    inst:AddComponent("spawnfader")

	WobyCommon.SetupCommandWheel(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
		--@V2C: #HACK during transformation, replacing prefab collides with itself, causing flicker
		inst.Physics:ClearCollidesWith(COLLISION.CHARACTERS)
		inst:DoStaticTaskInTime(0, RestoreCharacterCollisions)

        return inst
    end

	--Remove these tags so that they can be added properly when replicating components below
	inst:RemoveTag("_hunger")

	inst.favoritefood = "monsterlasagna"

    inst.GetPeepChance = GetPeepChance
    inst.IsAffectionate = IsAffectionate
    inst.IsSuperCute = IsSuperCute
    inst.IsPlayful = IsPlayful

	inst.playmatetags = {"critter"}

    inst:AddComponent("inspectable")

    inst:AddComponent("follower")
    inst.components.follower:KeepLeaderOnAttacked()
    inst.components.follower.keepdeadleader = true
    inst.components.follower.keepleaderduringminigame = true

    inst:AddComponent("knownlocations")

    inst:AddComponent("sleeper")
    inst.components.sleeper:SetResistance(3)
    inst.components.sleeper.testperiod = GetRandomWithVariance(6, 2)
    inst.components.sleeper:SetSleepTest(ShouldSleep)
    inst.components.sleeper:SetWakeTest(ShouldWakeUp)

    inst:AddComponent("eater")
    inst.components.eater:SetDiet({ FOODTYPE.MONSTER }, { FOODTYPE.MONSTER })
	inst.components.eater.custom_stats_mod_fn = CustomFoodStatsMod
	inst.components.eater:SetOnEatFn(OnEat)

    inst:AddComponent("hunger")
    inst.components.hunger:SetMax(TUNING.WOBY_SMALL_HUNGER)
    inst.components.hunger:SetRate(TUNING.WOBY_SMALL_HUNGER_RATE)
    inst.components.hunger:SetOverrideStarveFn(OnStarving)
    inst.components.hunger:SetPercent(0)

    inst:AddComponent("locomotor")
    inst.components.locomotor:EnableGroundSpeedMultiplier(true)
    inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.softstop = true
    inst.components.locomotor.walkspeed = TUNING.CRITTER_WALK_SPEED

    inst.components.locomotor:SetAllowPlatformHopping(true)

    inst:AddComponent("embarker")
    inst.components.embarker.embark_speed = inst.components.locomotor.walkspeed
    inst:AddComponent("drownable")

	inst:AddComponent("colourtweener")

    inst:AddComponent("crittertraits")
    inst.components.crittertraits:SetOnPetFn(OnPet)

    inst:AddComponent("timer")

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("wobysmall")

    inst:SetBrain(brain)
    inst:SetStateGraph("SGwobysmall")

    inst:ListenForEvent("hungerdelta", OnHungerDelta)

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

    inst.FinishTransformation = FinishTransformation
	inst.GetForagerTarget = GetForagerTarget
	inst.QueueForagerTarget = QueueForagerTarget
	inst.ClearForagerQueue = ClearForagerQueue
	inst.RemoveForagerTarget = RemoveForagerTarget
	inst.RemoveCurrentForagerTarget = RemoveCurrentForagerTarget
	inst.UpdateOwnerNewStateListener = UpdateOwnerNewStateListener

	inst.ApplyBigBuildOverrides = ApplyBigBuildOverrides
	inst.OnWobySkinChanged = OnWobySkinChanged
    inst.ReskinToolFilterFn = WobyCommon.ReskinToolFilterFn

	inst.OnPreLoad = OnPreLoad
    inst.persists = false

	inst.spawnfx = "spawn_fx_small"

    return inst
end

return Prefab("wobysmall", fn, assets, prefabs)