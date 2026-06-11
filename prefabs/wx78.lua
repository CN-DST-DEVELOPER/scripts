local MakePlayerCharacter = require("prefabs/player_common")
local PlayerCommonExtensions = require("prefabs/player_common_extensions")
local WX78Common = require("prefabs/wx78_common")
local WX78MoistureMeter = require("widgets/wx78moisturemeter")
local easing = require("easing")

local assets = JoinArrays({
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    Asset("SCRIPT", "scripts/prefabs/wx78_common.lua"),

    Asset("SOUND", "sound/wx78.fsb"),

    Asset("ANIM", "anim/player_idles_wx.zip"),
    Asset("ANIM", "anim/wx_upgrade.zip"),
    Asset("ANIM", "anim/player_wx78_actions.zip"),
    Asset("ANIM", "anim/player_mount_wx78_actions.zip"),
    Asset("ANIM", "anim/player_wx78_defense.zip"),
    Asset("ANIM", "anim/player_mount_wx78_upgrade.zip"),
    Asset("ANIM", "anim/wx_fx.zip"),
	Asset("ANIM", "anim/wx_chassis.zip"),
	Asset("ANIM", "anim/wx_overlay.zip"),
	Asset("ANIM", "anim/wx_drone_zap_use.zip"),
	Asset("ANIM", "anim/wx_mount_drone_zap_use.zip"),

    Asset("SCRIPT", "scripts/prefabs/skilltree_wx78.lua"),
}, WX78Common.DEPENDENCIES.assets)

local prefabs = JoinArrays({
    "cracklehitfx",
    "gears",
    "sparks",
    "wx78_moduleremover",
    "wx78_scanner_item",
    -- Meta 6
    "wx78_abilitycooldown",
    "wx78_backupbody",
    "wx78_possessedbody",
}, WX78Common.DEPENDENCIES.prefabs)

local WX78ModuleDefinitionFile = require("wx78_moduledefs")

local WX78ModuleDefinitions = WX78ModuleDefinitionFile.module_definitions
for mdindex, module_def in ipairs(WX78ModuleDefinitions) do
    table.insert(prefabs, "wx78module_"..module_def.name)
end

local start_inv = {}
for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
	start_inv[string.lower(k)] = v.WX78
end

prefabs = FlattenTree({ prefabs, start_inv }, true)

local function SpawnBigSpark(inst)
    SpawnPrefab("wx78_big_spark"):AlignToTarget(inst)
end

local function COMMON_GetShieldPenetrationThreshold(inst)
    if inst.components.wx78_shield ~= nil then
        return inst.components.wx78_shield:GetPenetrationThreshold()
    elseif inst.wx78_classified ~= nil then
        return inst.wx78_classified.shieldpenetrationthreshold:value()
    else
        return 15
    end
end

local function COMMON_GetCurrentShield(inst)
    if inst.components.wx78_shield ~= nil then
        return inst.components.wx78_shield:GetCurrent()
    elseif inst.wx78_classified ~= nil then
        return inst.wx78_classified.currentshield:value()
    else
        return 0
    end
end

local function COMMON_GetMaxShield(inst)
    if inst.components.wx78_shield ~= nil then
        return inst.components.wx78_shield:GetMax()
    elseif inst.wx78_classified ~= nil then
        return inst.wx78_classified.maxshield:value()
    else
        return 1
    end
end

local function COMMON_GetCanShieldCharge(inst)
    if inst.components.wx78_shield ~= nil then
        return inst.components.wx78_shield:GetCanShieldCharge()
    elseif inst.wx78_classified ~= nil then
        return inst.wx78_classified.canshieldcharge:value()
    else
        return false
    end
end

local function COMMON_StopUsingDrone(inst)
	if inst.components.inventory then
		local item = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		if item and
			item:HasTag("wx_remotecontroller") and
			item.components.useableequippeditem and
			item.components.useableequippeditem:IsInUse()
		then
			item.components.useableequippeditem:StopUsingItem(inst)
		end
	else
		SendRPCToServer(RPC.StopUsingDrone)
	end
end

local function COMMON_StopInspectingModules(inst)
    if inst.components.upgrademoduleowner then
        inst:PushEventImmediate("stopinspectingmodule")
    else
        SendRPCToServer(RPC.StopInspectingModules)
    end
end

----------------------------------------------------------------------------------------

local CHARGEREGEN_TIMERNAME = "chargeregenupdate"
local MOISTURETRACK_TIMERNAME = "moisturetrackingupdate"
local HUNGERDRAIN_TIMERNAME = "hungerdraintick"

----------------------------------------------------------------------------------------

local function GetChargeRegenTime(inst)
    local mult = 1
    if inst.components.skilltreeupdater:IsActivated("wx78_circuitry_bettercharge") then
        mult = TUNING.SKILLS.WX78.FASTER_CHARGE_MULTIPLIER
    end
    return TUNING.WX78_CHARGE_REGENTIME / mult
end

local function OnSkillTreeInitialized_StartChargeRegenTimer(inst)
    if not inst.components.timer:TimerExists(CHARGEREGEN_TIMERNAME) then
        inst.components.timer:StartTimer(CHARGEREGEN_TIMERNAME, inst:GetChargeRegenTime())
    end
end

local function StartChargeRegenTimer(inst)
	if inst._PostActivateHandshakeState_Server == POSTACTIVATEHANDSHAKE.READY then
		inst.components.timer:StartTimer(CHARGEREGEN_TIMERNAME, inst:GetChargeRegenTime())
	else
		inst:ListenForEvent("ms_skilltreeinitialized", OnSkillTreeInitialized_StartChargeRegenTimer)
	end
end

----------------------------------------------------------------------------------------

local function do_chargeregen_update(inst)
    if not inst.components.upgrademoduleowner:IsRealChargeMaxed() then
        inst.components.upgrademoduleowner:DoDeltaCharge(1)
    end
end

local function OnUpgradeModuleChargeChanged(inst, data)
    -- The regen timer gets reset every time the energy level changes, whether it was by the regen timer or not.
    inst.components.timer:StopTimer(CHARGEREGEN_TIMERNAME)

    if not inst.components.upgrademoduleowner:IsRealChargeMaxed() then
        StartChargeRegenTimer(inst)

        -- If we just got put to 0 from a non-0 value, tell the player.
        if data.old_level ~= 0 and data.new_level == 0 and not data.isloading then
            inst.components.talker:Say(GetString(inst, "ANNOUNCE_DISCHARGE"))
        end
    else
        -- If our charge is maxed (this is a post-assignment callback), and our previous charge was not,
        -- we just hit the max, so tell the player.
        if data.old_level ~= inst.components.upgrademoduleowner.max_charge and not data.isloading then
            inst.components.talker:Say(GetString(inst, "ANNOUNCE_CHARGE"))
        end
    end
end

----------------------------------------------------------------------------------------

local function OnLoad(inst, data)
    if data ~= nil then
        if data.gears_eaten ~= nil then
            inst._gears_eaten = data.gears_eaten
        end

        -- Compatability with pre-refresh WX saves
        if data.level ~= nil then
            inst._gears_eaten = (inst._gears_eaten or 0) + data.level
        end

        -- WX-78 needs to manually save/load health, hunger, and sanity, in case their maxes
        -- were modified by upgrade circuits, because those components only save current,
        -- and that gets overridden by the default max values during construction.
        -- So, if we wait to re-apply them in our OnLoad, we will have them properly
        -- (as entity OnLoad runs after component OnLoads)
        if data._wx78_health then
            inst.components.health:SetCurrentHealth(data._wx78_health)
        end

        if data._wx78_sanity then
            inst.components.sanity.current = data._wx78_sanity
        end

        if data._wx78_hunger then
            inst.components.hunger.current = data._wx78_hunger
        end

        if data._wx78_shield then
            inst.components.wx78_shield.currentshield = data._wx78_shield
        end
    end
    if not inst.is_snapshot_user_session then
        local socketholder = inst.components.socketholder
        socketholder.isloading = true -- HACK.
        WX78Common.RefreshShadowSocketBuffs(inst, nil)
        socketholder.isloading = nil -- HACK.
    end
end

local function OnSave(inst, data)
    data.gears_eaten = inst._gears_eaten

    -- WX-78 needs to manually save/load health, hunger, and sanity, in case their maxes
    -- were modified by upgrade circuits, because those components only save current,
    -- and that gets overridden by the default max values during construction.
    -- So, if we wait to re-apply them in our OnLoad, we will have them properly
    -- (as entity OnLoad runs after component OnLoads)
    data._wx78_health = inst.components.health.currenthealth
    data._wx78_sanity = inst.components.sanity.current
    data._wx78_hunger = inst.components.hunger.current
    data._wx78_shield = inst.components.wx78_shield.currentshield
end

----------------------------------------------------------------------------------------

local function OnLightningStrike(inst)
    if inst.components.health ~= nil and not (inst.components.health:IsDead() or inst.components.health:IsInvincible()) then
        if inst.components.inventory:IsInsulated() then
            inst:PushEvent("lightningdamageavoided")
        else
            inst.components.health:DoDelta(TUNING.HEALING_SUPERHUGE, false, "lightning")
            inst.components.sanity:DoDelta(-TUNING.SANITY_LARGE)

            inst.components.upgrademoduleowner:DoDeltaCharge(1)
        end
    end
end

----------------------------------------------------------------------------------------
-- Wetness/Moisture/Rain ---------------------------------------------------------------

local function COMMON_GetMinimumAcceptableMoisture(inst)
    return TUNING.WX78_MINACCEPTABLEMOISTURE
end

local function initiate_moisture_update(inst)
    if not inst.components.timer:TimerExists(MOISTURETRACK_TIMERNAME) then
        inst.components.timer:StartTimer(MOISTURETRACK_TIMERNAME, TUNING.WX78_MOISTUREUPDATERATE*FRAMES)
    end
end

local function stop_moisturetracking(inst)
    inst.components.timer:StopTimer(MOISTURETRACK_TIMERNAME)
    inst._moisture_steps = 0
end

local function moisturetrack_update(inst)
    local minacceptablemoisture = inst:GetMinimumAcceptableMoisture()
    local current_moisture = inst.components.moisture:GetMoisture()
    if current_moisture > minacceptablemoisture then
        -- The update will loop until it is stopped by going under the acceptable moisture level.
        initiate_moisture_update(inst)
    end

	if inst.components.moisture:IsForceDry() then
        return
    end

    inst._moisture_steps = inst._moisture_steps + 1

    local x, y, z = inst.Transform:GetWorldPosition()
    SpawnPrefab("sparks").Transform:SetPosition(x, y + 1 + math.random() * 1.5, z)

    if inst._moisture_steps >= TUNING.WX78_MOISTURESTEPTRIGGER then
        local damage_per_second = easing.inSine(
                current_moisture - minacceptablemoisture,
                TUNING.WX78_MIN_MOISTURE_DAMAGE,
                TUNING.WX78_PERCENT_MOISTURE_DAMAGE,
                inst.components.moisture:GetMaxMoisture() - minacceptablemoisture
        )
        local seconds_per_update = TUNING.WX78_MOISTUREUPDATERATE / 30

        inst.components.health:DoDelta(inst._moisture_steps * seconds_per_update * damage_per_second, false, "water")
        inst.components.upgrademoduleowner:DoDeltaCharge(-1)
        inst.components.wx78_shield:SetCurrent(0)
        inst._moisture_steps = 0

		if not inst.sg:HasStateTag("invisible") and inst.entity:IsVisible() then
			SpawnBigSpark(inst)
		end
		inst:PushEventImmediate("wx78_spark")
    end

    -- Send a message for the UI.
    inst:PushEvent("do_robot_spark")
    if inst.wx78_classified ~= nil then
        inst.wx78_classified.uirobotsparksevent:push()
    end
end

local function OnWetnessChanged(inst, data)
    if not (inst.components.health ~= nil and inst.components.health:IsDead()) then
        local minacceptablemoisture = inst:GetMinimumAcceptableMoisture()
        if data.new >= TUNING.WX78_COLD_ICEMOISTURE and inst.components.upgrademoduleowner:GetModuleTypeCount("cold") > 0 then
            inst.components.moisture:SetMoistureLevel(0)

            local x, y, z = inst.Transform:GetWorldPosition()
            for i = 1, TUNING.WX78_COLD_ICECOUNT do
                local ice = SpawnPrefab("ice")
                ice.Transform:SetPosition(x, y, z)
                Launch(ice, inst)
            end

            stop_moisturetracking(inst)
        elseif data.new > minacceptablemoisture and data.old <= minacceptablemoisture then
            initiate_moisture_update(inst)
        elseif data.new <= minacceptablemoisture and data.old > minacceptablemoisture then
            stop_moisturetracking(inst)
        end
    end
end

---------------------------------------------------------------------------------------

local function OnBecameRobot(inst)
    inst.sg.mem.nocorpse = true -- No flesh inside us.
    --Override with overcharge light values
    inst.Light:Enable(false)
    inst.Light:SetRadius(2)
    inst.Light:SetFalloff(0.75)
    inst.Light:SetIntensity(.9)
    inst.Light:SetColour(235 / 255, 121 / 255, 12 / 255)

    if not inst.components.upgrademoduleowner:IsRealChargeMaxed() then
        StartChargeRegenTimer(inst)
    end
end

local function OnBecameGhost(inst)
    stop_moisturetracking(inst)
    inst.components.timer:StopTimer(HUNGERDRAIN_TIMERNAME)
    inst.components.timer:StopTimer(CHARGEREGEN_TIMERNAME)
end

local function DoDeathConsequences(inst)
    inst.components.upgrademoduleowner:PopAllModules()
    inst.components.upgrademoduleowner:SetChargeLevel(0)
end

local function OnDeath(inst)
    if not inst.wx78_backupbody_save then
        DoDeathConsequences(inst)
    end

    stop_moisturetracking(inst)
    inst.components.timer:StopTimer(HUNGERDRAIN_TIMERNAME)
    inst.components.timer:StopTimer(CHARGEREGEN_TIMERNAME)

    WX78Common.DropEatenGears(inst)
end

----------------------------------------------------------------------------------------

local function OnFrozen(inst)
    if inst.components.freezable == nil or not inst.components.freezable:IsFrozen() then
        SpawnBigSpark(inst)

        if not inst.components.upgrademoduleowner:IsChargeEmpty() then
            inst.components.upgrademoduleowner:DoDeltaCharge(-TUNING.WX78_FROZEN_CHARGELOSS)
        end
    end
end

----------------------------------------------------------------------------------------

local function OnUpgradeModuleAdded(inst, moduleent)
    local moduletype = moduleent.components.upgrademodule:GetType()

    inst:PushEvent("upgrademodulesdirty", inst:GetModulesData())
    if inst.wx78_classified ~= nil then
        local newmodule_index = inst.components.upgrademoduleowner:GetNumModules(moduletype)
        inst.wx78_classified.upgrademodulebars[moduletype][newmodule_index]:set(moduleent._netid or 0)
    end
end

local function OnUpgradeModuleRemoved(inst, moduleent)
    -- If the module has 0.5 use left, it's about to be destroyed, so don't return it to the inventory.
    if moduleent.components.finiteuses == nil or moduleent.components.finiteuses:GetUses() > 0.5 then
        if not inst.components.upgrademoduleowner:IsSwapping() and moduleent.components.inventoryitem ~= nil and inst.components.inventory ~= nil then
            -- No pos if we're dead so we don't see the inv icon when we're dying and inventory is hidden
            local pos = not inst.components.health:IsDead() and inst:GetPosition() or nil
            inst.components.inventory:GiveItem(moduleent, nil, pos)
        end
    end
end

local function OnOneUpgradeModulePopped(inst, moduleent, was_activated)
    -- If the module we just popped was charged, use that charge
    -- as the cost of this removal.
    local moduletype = moduleent.components.upgrademodule:GetType()
    local moduleslotcount = moduleent.components.upgrademodule:GetSlots()
    if was_activated then
        local charge_cost = -moduleslotcount
        local skilltreeupdater = inst.components.skilltreeupdater
        if skilltreeupdater and skilltreeupdater:IsActivated("wx78_circuitry_bettercharge") then
            charge_cost = math.min(charge_cost + TUNING.SKILLS.WX78.SAVE_CHARGE_ON_UNPLUG, -1)
        end
        inst.components.upgrademoduleowner:DoDeltaCharge(charge_cost)
    end

    inst:PushEvent("upgrademodulesdirty", inst:GetModulesData())
    if inst.wx78_classified ~= nil then
        for i, netvar in ipairs(inst.wx78_classified.upgrademodulebars[moduletype]) do
            local module = inst.components.upgrademoduleowner:GetModule(moduletype, i)
            netvar:set(module ~= nil and module._netid or 0)
        end
    end
end

local function OnAllUpgradeModulesRemoved(inst)
    SpawnBigSpark(inst)

    inst:PushEvent("upgrademoduleowner_popallmodules")

    if inst.wx78_classified ~= nil then
        for i, modules in pairs(inst.wx78_classified.upgrademodulebars) do
            for j, netvar in ipairs(modules) do
                netvar:set(0)
            end
        end
    end
end

local function CanUseUpgradeModule(inst, moduleent)
    local moduletype = moduleent.components.upgrademodule:GetType()
    local slots_in_use = inst.components.upgrademoduleowner:GetUsedSlotCount(moduletype)
    local max_charge = inst.components.upgrademoduleowner:GetMaxChargeLevel()
    if max_charge - slots_in_use < moduleent.components.upgrademodule:GetSlots() then
        return false, "NOTENOUGHSLOTS"
    else
        return true
    end
end

----------------------------------------------------------------------------------------

local function OnChargeFromBattery(inst, battery, mult)
    if inst.components.upgrademoduleowner:IsRealChargeMaxed() then
        return false, "CHARGE_FULL"
    end

    inst.components.health:DoDelta(TUNING.HEALING_SMALL, false, "lightning")
    inst.components.sanity:DoDelta(-TUNING.SANITY_SMALL)

    inst.components.upgrademoduleowner:DoDeltaCharge(1)

	--V2C: -switched to stategraph event instead of GoToState
	--     -use Immediate to preserve legacy timing
	inst:PushEventImmediate("electrocute")

    return true
end

----------------------------------------------------------------------------------------

local function CanSleepInBagFn(wx, bed)
    if wx._lightmodule_radius == nil or wx._lightmodule_radius == 0 then
        return true
    else
        return false, "ANNOUNCE_NOSLEEPHASPERMANENTLIGHT"
    end
end

----------------------------------------------------------------------------------------
local function OnStartStarving(inst)
    inst.components.timer:StartTimer(HUNGERDRAIN_TIMERNAME, TUNING.WX78_HUNGRYCHARGEDRAIN_TICKTIME)
end

local function OnStopStarving(inst)
    inst.components.timer:StopTimer(HUNGERDRAIN_TIMERNAME)
end

local function on_hunger_drain_tick(inst)
    if inst.components.health ~= nil and not (inst.components.health:IsDead() or inst.components.health:IsInvincible()) then
        inst.components.upgrademoduleowner:DoDeltaCharge(-1)

		if not inst.sg:HasStateTag("invisible") and inst.entity:IsVisible() then
			SpawnBigSpark(inst)
		end
		inst:PushEventImmediate("wx78_spark")
    end
    inst.components.timer:StartTimer(HUNGERDRAIN_TIMERNAME, TUNING.WX78_HUNGRYCHARGEDRAIN_TICKTIME)
end

----------------------------------------------------------------------------------------

local function RedirectToWxShield(inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
	return inst.components.wx78_shield ~= nil and inst.components.wx78_shield:OnTakeDamage(amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
end

----------------------------------------------------------------------------------------

local function OnTimerFinished(inst, data)
    if data.name == HUNGERDRAIN_TIMERNAME then
        on_hunger_drain_tick(inst)
    elseif data.name == MOISTURETRACK_TIMERNAME then
        moisturetrack_update(inst)
    elseif data.name == CHARGEREGEN_TIMERNAME then
        do_chargeregen_update(inst)
    end
end

----------------------------------------------------------------------------------------

local function CustomCombatDamage(inst, target, weapon, multiplier, mount)
    if mount then
        return 1
    end

    local debuffers = inst.components.petleash:GetPetsWithPrefab("wx78_shadowdrone_debuffer")
    if not debuffers then
        return 1
    end

    local debuffingcount = 0
    for _, debuffer in ipairs(debuffers) do
		if debuffer:IsApplyingDebuffTo(target) then
            debuffingcount = debuffingcount + 1
            debuffer:ApplyUse()
        end
    end

    if debuffingcount == 0 then
        return 1
    end

    return 1 + TUNING.SKILLS.WX78.SHADOWDRONE_DAMAGEMULT_PER_DRONE * debuffingcount
end

----------------------------------------------------------------------------------------

local function OnDroneStartTracking(inst, drone)
    if inst.wx78_classified then
        inst.wx78_classified.numdronescouts:set(inst.wx78_classified.numdronescouts:value() + 1)
        if inst.HUD then
            inst:PushEvent("refreshcrafting")
        end
    end
end
local function OnDroneStopTracking(inst, drone)
    if inst.wx78_classified then
        inst.wx78_classified.numdronescouts:set(inst.wx78_classified.numdronescouts:value() - 1)
        if inst.HUD then
            inst:PushEvent("refreshcrafting")
        end
    end
end

----------------------------------------------------------------------------------------

local function OnDeactivateSkill(inst, data)
	if data then
		if data.skill == "wx78_scoutdrone_1" then
			inst.components.wx78_dronescouttracker:ReleaseAllDrones()
		end
	end
end

local function OnSkillTreeInitialized(inst)
	local skilltreeupdater = inst.components.skilltreeupdater
	if not (skilltreeupdater and skilltreeupdater:IsActivated("wx78_scoutdrone_1")) then
		inst.components.wx78_dronescouttracker:ReleaseAllDrones()
	end
end

----------------------------------------------------------------------------------------

local function CanSpawnBackupBody(inst) -- For death logic, so we know not to become parasited by void masque
    return (inst.wx78_classified and inst.wx78_classified:GetNumFreeBackupBodies() or 0) > 0
end

local function TryToSpawnBackupBody(inst)
    inst.wx78_backupbody_save = nil
    if CanSpawnBackupBody(inst) then
        local x, y, z = inst.Transform:GetWorldPosition()
        local body = SpawnPrefab("wx78_backupbody")
        body._hide_body_skinfx = true
        body.components.upgrademoduleowner:SetChargeLevel(0)
        if inst.components.upgrademoduleowner then
            inst.components.upgrademoduleowner:SetChargeLevel(0)
        end
        body.Transform:SetPosition(x, y, z)
        if not body.components.activatable:CanActivate(inst) then
            body:Remove()
            return false
        end
        if not body.components.activatable:DoActivate(inst) then
            body:Remove()
            return false
        end
        inst.wx78_backupbody_save_inst = body
        body._Light_value = body.Light:IsEnabled() -- HACK flag for default behaviour with Remove and Return to Scene modifying light states.
        body:RemoveFromScene()
        return true
    end
    DoDeathConsequences(inst) -- Only needs to call on fail because all of the modules and energy is transferred into the body.
    return false
end

----------------------------------------------------------------------------------------

local function GetPointSpecialActions(inst, pos, useitem, right)
	local actions = {}

    if right and useitem == nil then
        if inst.checkingmapactions then
			if inst.components.skilltreeupdater then
				if inst.components.skilltreeupdater:IsActivated("wx78_remotebodyswap") then
					table.insert(actions, ACTIONS.SWAPBODIES_MAP)
				end
				if inst.components.skilltreeupdater:IsActivated("wx78_scoutdrone_1") then
					table.insert(actions, ACTIONS.MAPSCOUTSELECT_MAP)
				end
			end
        else
            if inst.components.playercontroller ~= nil and inst.components.playercontroller.isclientcontrollerattached then
                if inst.CollectUpgradeModuleActions then
                    inst:CollectUpgradeModuleActions(actions)
                end
            end
        end
    end

	return actions
end

local function OnSetOwner(inst)
    if inst.components.playeractionpicker ~= nil then
        inst.components.playeractionpicker.pointspecialactionsfn = GetPointSpecialActions
    end
    if TheWorld.ismastersim then
        inst.wx78_classified.Network:SetClassifiedTarget(inst)
    end
end

local function AttachClassified_wx78(inst, classified)
    inst.wx78_classified = classified
    inst.ondetach_wx78_classified = function() inst:DetachClassified_wx78() end
    inst:ListenForEvent("onremove", inst.ondetach_wx78_classified, classified)
end

local function DetachClassified_wx78(inst)
    inst.wx78_classified = nil
    inst.ondetach_wx78_classified = nil
end

----------------------------------------------------------------------------------------

local function OnRemoveEntity(inst)
    if inst.wx78_classified ~= nil then
        if TheWorld.ismastersim then
            inst.wx78_classified:Remove()
            inst.wx78_classified = nil
        else
            inst.wx78_classified._parent = nil
            inst:RemoveEventCallback("onremove", inst.ondetach_wx78_classified, inst.wx78_classified)
            inst:DetachClassified_wx78()
        end
    end
    if inst._OnRemoveEntity ~= nil then
        inst._OnRemoveEntity(inst)
    end
end

local function common_postinit(inst)
    inst:AddTag("electricdamageimmune")
    --electricdamageimmune is for combat and not lightning strikes
    --also used in stategraph for not stomping custom light values

    inst:AddTag("batteryuser")          -- from batteryuser component
    inst:AddTag("chessfriend")
    inst:AddTag("HASHEATER")            -- from heater component
    inst:AddTag("soulless")
    inst:AddTag("upgrademoduleowner")   -- from upgrademoduleowner component
    inst:AddTag("wx78_shield")          -- from wx78_shield component

    if TheNet:GetServerGameMode() == "quagmire" then
        inst:AddTag("quagmire_shopper")
    else
        if not TheNet:IsDedicated() then
            inst.CreateMoistureMeter = WX78MoistureMeter
        end
    end
    inst.AttachClassified_wx78 = AttachClassified_wx78
    inst.DetachClassified_wx78 = DetachClassified_wx78
    inst:ListenForEvent("setowner", OnSetOwner)

    inst.AnimState:AddOverrideBuild("player_wx78_actions")

    inst.components.talker.mod_str_fn = string.utf8upper

    inst.foleysound = "dontstarve/movement/foley/wx78"

    inst:AddComponent("wx78_abilitycooldowns")

	WX78Common.AddHeatSteamFx_Common(inst)
	WX78Common.AddDizzyFx_Common(inst)

    inst.GetMinimumAcceptableMoisture = COMMON_GetMinimumAcceptableMoisture
    inst.GetShieldPenetrationThreshold = COMMON_GetShieldPenetrationThreshold
    inst.GetCurrentShield = COMMON_GetCurrentShield
    inst.GetMaxShield = COMMON_GetMaxShield
    inst.GetCanShieldCharge = COMMON_GetCanShieldCharge
    WX78Common.SetupUpgradeModuleOwnerInstanceFunctions(inst)
	inst.StopUsingDrone = COMMON_StopUsingDrone
    inst.StopInspectingModules = COMMON_StopInspectingModules
    ----------------------------------------------------------------
    inst._OnRemoveEntity = inst.OnRemoveEntity
    inst.OnRemoveEntity = OnRemoveEntity
    WX78Common.Initialize_Common(inst)
end

local function master_postinit(inst)
    inst.refusestobowtoroyalty = true
    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default

	inst.customidlestate = "wx78_funnyidle"

    ----------------------------------------------------------------

    inst.wx78_classified = SpawnPrefab("wx78_classified")
    inst.wx78_classified.entity:SetParent(inst.entity)

    ----------------------------------------------------------------
    inst.components.health:SetMaxHealth(TUNING.WX78_HEALTH)
    inst.components.hunger:SetMax(TUNING.WX78_HUNGER)
    inst.components.sanity:SetMax(TUNING.WX78_SANITY)
    ----------------------------------------------------------------
    inst._moisture_steps = 0

    ----------------------------------------------------------------
    if inst.components.eater ~= nil then
        inst.components.eater:SetIgnoresSpoilage(true)
        inst.components.eater:SetCanEatGears()
        inst.components.eater:SetOnEatFn(WX78Common.OnEat)
    end

    ----------------------------------------------------------------
    if inst.components.freezable ~= nil then
        inst.components.freezable.onfreezefn = OnFrozen
    end

    inst.GetChargeRegenTime = GetChargeRegenTime

    ----------------------------------------------------------------
    inst:AddComponent("upgrademoduleowner")
    inst.components.upgrademoduleowner.onmoduleadded = OnUpgradeModuleAdded
    inst.components.upgrademoduleowner.onmoduleremoved = OnUpgradeModuleRemoved
    inst.components.upgrademoduleowner.ononemodulepopped = OnOneUpgradeModulePopped
    inst.components.upgrademoduleowner.onallmodulespopped = OnAllUpgradeModulesRemoved
    inst.components.upgrademoduleowner.canupgradefn = CanUseUpgradeModule
    inst.components.upgrademoduleowner:SetChargeLevel(3)
    inst.components.upgrademoduleowner:SetMaxCharge(TUNING.WX78_INITIAL_MAXCHARGELEVEL)

    inst:ListenForEvent("energylevelupdate", OnUpgradeModuleChargeChanged)

    ----------------------------------------------------------------
    inst:AddComponent("dataanalyzer")
    inst.components.dataanalyzer:StartDataRegen(TUNING.SEG_TIME)

    ----------------------------------------------------------------
    inst:AddComponent("batteryuser")
	inst.components.batteryuser:SetOnBatteryUsedFn(OnChargeFromBattery)

    ----------------------------------------------------------------

    inst:AddComponent("wx78_shield")
    inst.components.wx78_shield:SetMax(1)
    inst.components.wx78_shield:SetCurrent(0)
    inst.components.health.deltamodifierfn = RedirectToWxShield

	inst:AddComponent("wx78_dronescouttracker")
    inst.components.wx78_dronescouttracker:SetOnStartTrackingFn(OnDroneStartTracking)
    inst.components.wx78_dronescouttracker:SetOnStopTrackingFn(OnDroneStopTracking)
    ----------------------------------------------------------------
    inst.components.foodaffinity:AddPrefabAffinity("butterflymuffin", TUNING.AFFINITY_15_CALORIES_LARGE)

    ----------------------------------------------------------------
    inst.components.sleepingbaguser:SetCanSleepFn(CanSleepInBagFn)

    ----------------------------------------------------------------
    inst:ListenForEvent("ms_respawnedfromghost", OnBecameRobot)
    inst:ListenForEvent("ms_becameghost", OnBecameGhost)
    inst:ListenForEvent("death", OnDeath)
    inst:ListenForEvent("ms_playerreroll", OnDeath)
    inst:ListenForEvent("moisturedelta", OnWetnessChanged)
    inst:ListenForEvent("startstarving", OnStartStarving)
    inst:ListenForEvent("stopstarving", OnStopStarving)
    inst:ListenForEvent("timerdone", OnTimerFinished)
    inst:ListenForEvent("ondeactivateskill_server", OnDeactivateSkill)
    inst:ListenForEvent("ms_skilltreeinitialized", OnSkillTreeInitialized)

    ----------------------------------------------------------------
    inst.components.playerlightningtarget:SetHitChance(TUNING.WX78_LIGHTNING_TARGET_CHANCE)
    inst.components.playerlightningtarget:SetOnStrikeFn(OnLightningStrike)

    ----------------------------------------------------------------
    OnBecameRobot(inst)

    ----------------------------------------------------------------
    inst.AddTemperatureModuleLeaning = WX78Common.AddTemperatureModuleLeaning
    inst.CanSpawnBackupBody = CanSpawnBackupBody
    inst.TryToSpawnBackupBody = TryToSpawnBackupBody

    ----------------------------------------------------------------

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    WX78Common.Initialize_Master(inst)

    ----------------------------------------------------------------
    if TheNet:GetServerGameMode() == "lavaarena" then
        event_server_data("lavaarena", "prefabs/wx78").master_postinit(inst)
    elseif TheNet:GetServerGameMode() == "quagmire" then
        event_server_data("quagmire", "prefabs/wx78").master_postinit(inst)
    else
        inst.components.combat.customdamagemultfn = CustomCombatDamage
    end
end

return MakePlayerCharacter("wx78", prefabs, assets, common_postinit, master_postinit)
