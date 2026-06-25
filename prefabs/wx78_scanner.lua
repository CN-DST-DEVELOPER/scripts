local assets =
{
    Asset("ANIM", "anim/wx_scanner.zip"),
    Asset("ANIM", "anim/wx_scanner_ring_fx.zip"),
    Asset("INV_IMAGE", "wx78_scanner_item_on"),
    Asset("MINIMAP_IMAGE", "wx78_scanner_item"),
}

local item_prefabs =
{
    "scandata",
    "wx78_scanner",
}

local scanner_prefabs =
{
    "wx78_scanner_fx",
    "wx78_scanner_succeeded",
	"globalmapiconunderfog",
}

local GetCreatureScanData = require("wx78_moduledefs").GetCreatureScanDataDefinition

local brain = require "brains/wx78_scannerbrain"

local RING_FX =
{
    NONE = 0,
    SCANNING = 1,
    FAILED = 2,
    SUCCESS = 3,
}

local function GetScannerScanDistance(inst)
    local numboost = inst._radarboosters:value()
    if inst._hassignalbooster:value() then
        numboost = numboost + TUNING.SKILLS.WX78.WX78_SCANNER_RANGE_BONUS
    end
    return TUNING.WX78_SCANNER_SCANDIST + (numboost * TUNING.SKILLS.WX78.RADAR_WX78_SCANNER_SCANDIST)
end

local function GetScannerPlayerProximityDistance(inst)
    local numboost = inst._radarboosters:value()
    if inst._hassignalbooster:value() then
        numboost = numboost + TUNING.SKILLS.WX78.WX78_SCANNER_RANGE_BONUS
    end
    return TUNING.WX78_SCANNER_PLAYER_PROX + (numboost * TUNING.SKILLS.WX78.RADAR_WX78_SCANNER_PLAYER_PROX)
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Scanner Ring Non-networked FX

local CIRCLE_RADIUS_SCALE = 3201.5 / 150 / 2 -- Source art size / anim_scale / 2 (halved to get radius).
local function RingFX_UpdateRadius(inst, scanner)
    local dist = TUNING.WX78_SCANNER_PLAYER_PROX
    if scanner ~= nil and scanner:IsValid() then
        dist = scanner:GetScannerPlayerProximityDistance()
    end

    local scale = dist / CIRCLE_RADIUS_SCALE
    inst.AnimState:SetScale(scale, scale)
end

local function CreateRingFX(scanner)
    local inst = CreateEntity()

    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("DECOR")
    inst:AddTag("NOCLICK")

    inst.AnimState:SetBank("wx_scanner_ring_fx")
    inst.AnimState:SetBuild("wx_scanner_ring_fx")
    inst.AnimState:PlayAnimation("scan_loop", true)

    inst.AnimState:Hide("inner")

    inst.AnimState:SetLightOverride(1)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(1)

    inst.UpdateRadius = RingFX_UpdateRadius
    inst:UpdateRadius(scanner)

    inst:AddComponent("fader")

    return inst
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- The proximity scanning template is used by both the inventoryitem and prop version of the scanner.

local SCAN_CAN = {"animal", "character", "largecreature", "monster", "smallcreature", "firefly", "cage", "trap", "wagstaff_machine", "junk_pile_big", "wagpunk_workstation"}
local SCAN_CANT = {"DECOR", "FX", "INLIMBO", "NOCLICK"}
local function GetCreatureRecipeScan(inst, owner, scandata)
    if scandata.recipename then
        return FunctionOrValue(scandata.recipename, owner)
    else
        return "wx78module_"..scandata.module
    end
end

local function proximityscan(inst, dt)
    local owner = inst:OwnerFn()
    if owner and owner.components.upgrademoduleowner ~= nil and
            (owner.components.health ~= nil and not owner.components.health:IsDead()) then
        local x,y,z = inst.Transform:GetWorldPosition()

        -- We add a buffer to the search distance to account for physics radii
        local SCAN_DIST = TUNING.WX78_SCANNER_DISTANCES[#TUNING.WX78_SCANNER_DISTANCES].maxdist + 5
        local owner_has_builder = (owner.components.builder ~= nil)

        local ents = TheSim:FindEntities(x,y,z, SCAN_DIST, nil, SCAN_CANT, SCAN_CAN)
        local new_target = nil
        if owner_has_builder then
            for i, ent in ipairs(ents) do
                local ent_scandata = GetCreatureScanData(ent)
                if ent_scandata ~= nil then
                    local recipename = GetCreatureRecipeScan(inst, owner, ent_scandata)
                    if recipename ~= nil and not owner.components.builder:KnowsRecipe(recipename) then
                        new_target = ent
                    end
                end
            end
        end

        if new_target ~= nil then
            local distsq = inst:GetDistanceSqToInst(new_target)
            local nextpingtime = TUNING.WX78_SCANNER_DISTANCES[#TUNING.WX78_SCANNER_DISTANCES].pingtime
			local sfxproximity = #TUNING.WX78_SCANNER_DISTANCES + 1
			for i, v in ipairs(TUNING.WX78_SCANNER_DISTANCES) do
                if v.maxdist*v.maxdist >= distsq then
                    nextpingtime = v.pingtime
					sfxproximity = i
                    break
                end
            end

            inst._ping_time_last = inst._ping_time_last or GetTime()
            inst._ping_time_current = (inst._ping_time_current ~= nil and inst._ping_time_current + dt)
                or GetTime()

            if (inst._ping_time_current - inst._ping_time_last) > nextpingtime then
				--[[sfxproximity =
					(sfxproximity == 1 and 0.8) or
					(sfxproximity == 2 and 0.5) or
					0.2

				inst.SoundEmitter:PlaySoundWithParams("WX_rework/scanner/ping", { proximity = sfxproximity })]]
                inst.SoundEmitter:PlaySound("WX_rework/scanner/ping")
                inst:LoopFn(new_target)

                inst.components.entitytracker:ForgetEntity("currentscanlock")
                inst.components.entitytracker:TrackEntity("currentscanlock", new_target)

                inst._ping_time_last = nil
                inst._ping_time_current = nil
            end
        else
            inst.components.entitytracker:ForgetEntity("currentscanlock")

            inst._ping_time_last = nil
            inst._ping_time_current = nil
        end
    end
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

local function CanDeploy(inst, pt, mouseover, deployer, rot)
    return (deployer.components.upgrademoduleowner ~= nil and inst.components.deployable:IsDeployable(deployer))
end

local function UpdateScannerRadarBoosters(inst)
    local owner = inst:OwnerFn()
    if owner ~= nil then
        if owner.components.skilltreeupdater ~= nil then
            inst._hassignalbooster:set(owner.components.skilltreeupdater:IsActivated("wx78_extradronerange"))

            if owner.GetModuleTypeCount ~= nil and owner.components.skilltreeupdater:IsActivated("wx78_circuitry_betabuffs_1") then
                inst._radarboosters:set(owner:GetModuleTypeCount("radar"))
            else
                inst._radarboosters:set(0)
            end
        end
    end
    if inst.prox_range ~= nil then
        inst.prox_range:UpdateRadius(inst)
    end
end

local function OnChangedLeader(inst, new_leader, old_leader)
    if old_leader ~= nil then
        inst:RemoveEventCallback("onactivateskill_server", inst._onrangerefresh, old_leader)
        inst:RemoveEventCallback("ondeactivateskill_server", inst._onrangerefresh, old_leader)
        inst:RemoveEventCallback("rangecircuitupdate", inst._onrangerefresh, old_leader)
    end

    if not inst._donescanning and new_leader == nil and old_leader ~= nil then
        inst:StopAllScanning("fail")
        inst:PushEvent("turn_off", { changetoitem=true })
    end

    if new_leader ~= nil then
        inst:ListenForEvent("onactivateskill_server", inst._onrangerefresh, new_leader)
		inst:ListenForEvent("ondeactivateskill_server", inst._onrangerefresh, new_leader)
        inst:ListenForEvent("rangecircuitupdate", inst._onrangerefresh, new_leader)
    end
    UpdateScannerRadarBoosters(inst)
end

local function OnScannerDeployed(inst, pt, deployer)
    local scanner = SpawnPrefab("wx78_scanner", inst.linked_skinname, inst.skin_id)
    if scanner ~= nil then
        scanner.Physics:SetCollides(false)
        scanner.Physics:Teleport(pt.x, 0, pt.z)
        scanner.Physics:SetCollides(true)

        scanner.components.follower:SetLeader(deployer)

        scanner:PushEventImmediate("deployed")

        inst:Remove()
    end
end

---------------------------------------------------------------------------------------------------

local function item_owner_fn(inst)
    return (inst.components.inventoryitem ~= nil and inst.components.inventoryitem:GetGrandOwner()) or nil
end

local function image_on(inst)
    inst.components.inventoryitem:ChangeImageName((inst.linked_skinname or "wx78_scanner") .. "_item_on")
end

local function image_off(inst)
    inst.components.inventoryitem:ChangeImageName((inst.linked_skinname or "wx78_scanner") .. "_item")
end

local function item_loop_fn(inst, target)
    local owner = inst:OwnerFn()
    if owner then
        inst:DoTaskInTime(0.1, image_on)
        inst:DoTaskInTime(0.6, image_off)

        local current_scan_lock = inst.components.entitytracker:GetEntity("currentscanlock")
        if (current_scan_lock == nil or current_scan_lock ~= target) and
                not owner.components.timer:TimerExists("ANNOUNCE_WX_SCANNER_NEW_FOUND") then
            owner.components.talker:Say(GetString(owner,"ANNOUNCE_WX_SCANNER_NEW_FOUND"))
            owner.components.timer:StartTimer("ANNOUNCE_WX_SCANNER_NEW_FOUND", 15)

			--[[local distsq = owner:GetDistanceSqToInst(target)
			local sfxproximity = #TUNING.WX78_SCANNER_DISTANCES + 1
			for i, v in ipairs(TUNING.WX78_SCANNER_DISTANCES) do
				if v.maxdist * v.maxdist >= distsq then
					sfxproximity = i
					break
				end
			end

			sfxproximity =
				(sfxproximity == 1 and 0.8) or
				(sfxproximity == 2 and 0.5) or
				0.2

			owner.SoundEmitter:PlaySoundWithParams("WX_rework/scanner/ping", { proximity = sfxproximity })]]
            owner.SoundEmitter:PlaySound("WX_rework/scanner/ping")
        end
    end
end

local ITEM_FLOATER_SCALE = {0.8, 1.0, 1.0}
local function itemfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.Transform:SetFourFaced()

    inst.MiniMapEntity:SetIcon("wx78_scanner_item.png")

    inst.AnimState:SetBank("scanner")
    inst.AnimState:SetBuild("wx_scanner")
    inst.AnimState:PlayAnimation("turn_off_idle")

    inst.AnimState:Hide("top_light")
    inst.AnimState:Hide("bottom_light")

    MakeInventoryFloatable(inst, nil, 0.15, ITEM_FLOATER_SCALE)

    inst:AddTag("usedeploystring")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_specialinfo = "WX78SCANNER"
    inst.scrapbook_hide = { "top_light", "bottom_light" }

    inst.scrapbook_animoffsetx = 10
    inst.scrapbook_animoffsety = -10

    -------------------------------------------------------------------
    inst:AddComponent("inspectable")

    -------------------------------------------------------------------
    inst:AddComponent("inventoryitem")

    -------------------------------------------------------------------
    inst:AddComponent("entitytracker")

    -------------------------------------------------------------------
    inst:AddComponent("updatelooper")

    -------------------------------------------------------------------
    inst.OwnerFn = item_owner_fn
    inst.LoopFn = item_loop_fn
    inst.components.updatelooper:AddOnUpdateFn(proximityscan)

    -------------------------------------------------------------------
    inst:AddComponent("deployable")
    inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM) -- use inst._custom_candeploy_fn
    inst.components.deployable.ondeploy = OnScannerDeployed
    inst.components.deployable.restrictedtag = "upgrademoduleowner"
    inst._custom_candeploy_fn = CanDeploy

    -------------------------------------------------------------------
    MakeHauntableLaunch(inst)

    return inst
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- PROP

---------------------------------------------------------------------------------------------------

local function scanner_owner_fn(inst)
    return inst.components.follower and inst.components.follower:GetLeader()
end

local function scanner_loop_fn(inst, target)
    inst:DoTaskInTime(0.1,function() inst.AnimState:Show("bottom_light") end)
    inst:DoTaskInTime(0.6, function() inst.AnimState:Hide("bottom_light") end)
end

local function StartProximityScan(inst)
    if not inst._turned_off then
        inst.components.updatelooper:AddOnUpdateFn(proximityscan)
    end
end

---------------------------------------------------------------------------------------------------

local function hide_top_light(inst)
    inst.AnimState:Hide("top_light")
end

local MAX_FLASH_TIME = 2
local MIN_FLASH_TIME = 0.15
local TOP_LIGHT_FLASH_TIMERNAME = "toplightflash_tick"
local function top_light_flash(inst)
    if inst._scantime then
        local calctime = math.max(
            Remap(inst._scantime, 0, TUNING.WX78_SCANNER_MODULETARGETSCANTIME-1, MAX_FLASH_TIME, MIN_FLASH_TIME),
            MIN_FLASH_TIME
        )

        inst.AnimState:Show("top_light")
        inst:DoTaskInTime(math.min(calctime-0.1, 0.3), hide_top_light)

        inst.components.timer:StartTimer(TOP_LIGHT_FLASH_TIMERNAME, calctime)
    else
        hide_top_light(inst)
    end
end

local function can_scan_target(inst)
    local target = inst.components.entitytracker:GetEntity("scantarget")
    local pos = target:GetPosition()
    local scandist = inst:GetScannerScanDistance()
    local DSQ = scandist * scandist

    if inst:GetDistanceSqToPoint(pos) < DSQ then
        -- WX is prevented from scanning things that have the "noattack" tag, unless they also have the "canwxscan" tag.
        -- See moles as an example.
        return target.sg == nil
            or not target.sg:HasStateTag("noattack")
            or target.sg:HasStateTag("canwxscan")
    else
        return false
    end
end

local function OnUpdateScanCheck(inst, dt)
    if inst._donescanning or inst._scantime == nil then
        return nil
    end

    local target = inst.components.entitytracker:GetEntity("scantarget")
    if target ~= nil then
        local owner = inst.components.follower and inst.components.follower:GetLeader()
        local ent_scandata = GetCreatureScanData(target)
        local recipename = ent_scandata ~= nil and GetCreatureRecipeScan(inst, owner, ent_scandata)
        if owner == nil or not target:IsValid() or target:HasAnyTag("INLIMBO", "NOCLICK") or
                (target.components.health ~= nil and target.components.health:IsDead()) or
                (   owner.components.dataanalyzer:GetData(target) <= 0 and
                    (   ent_scandata == nil or
                        recipename == nil or
                        owner.components.builder:KnowsRecipe(recipename)
                    )
                ) then
            inst:StopScanFX()
            inst:OnScanFailed()
        elseif can_scan_target(inst) then
            inst._scantime = inst._scantime + dt

            inst:StartScanFX(target)

            local target_time = (target:HasTag("epic") and TUNING.WX78_SCANNER_MODULETARGETSCANTIME_EPIC)
                or TUNING.WX78_SCANNER_MODULETARGETSCANTIME
            if inst._scantime > target_time then
                inst:OnSuccessfulScan()
                inst:StopScanFX()
            end
        else
            inst:StopScanFX()
        end
    end
end

local function OnScanFailed(inst)
    inst:StopAllScanning("fail")
    StartProximityScan(inst)
end

local function OnTargetFound(inst, scan_target)
    if scan_target ~= nil then
        inst.SoundEmitter:PlaySound(inst.skin_sound and inst.skin_sound.locked_on or "WX_rework/scanner/locked_on")

        inst.AnimState:Hide("bottom_light")
        inst.components.updatelooper:RemoveOnUpdateFn(proximityscan)

        inst._showringfx:set(RING_FX.SCANNING)

        inst.components.entitytracker:TrackEntity("scantarget", scan_target)
        inst:ListenForEvent("onremove", inst._OnScanTargetRemoved, scan_target)

        inst._scantime = 0

        inst.components.timer:StartTimer(TOP_LIGHT_FLASH_TIMERNAME, MAX_FLASH_TIME)

        inst.components.updatelooper:AddOnUpdateFn(inst.IsInRangeOfPlayer)
        inst.components.updatelooper:AddOnUpdateFn(OnUpdateScanCheck)
    end
end

local function TryFindTarget(inst)
    if inst._donescanning then
        return nil
    end

    local owner = inst.components.follower and inst.components.follower:GetLeader()
    if not owner then
        return nil
    end

    if not inst:IsInRangeOfPlayer() then
        return nil
    end

    local px, py, pz = inst.Transform:GetWorldPosition()
    local potential_scans = TheSim:FindEntities(px, py, pz, TUNING.WX78_SCANNER_RANGE, nil, SCAN_CANT, SCAN_CAN)

    if #potential_scans == 0 then
        return nil
    end

    local blueprintable_things = nil
    local thing_but_no_data = false
    local owner_has_builder = (owner.components.builder ~= nil)

    for i=#potential_scans,1,-1 do
        local thing = potential_scans[i]
        local keep = false
        local thing_scandata = GetCreatureScanData(thing)
        if thing_scandata ~= nil then
            if owner.components.dataanalyzer:GetData(thing) > 0 then
                keep = true
            else
                thing_but_no_data = true
            end

            local recipename = GetCreatureRecipeScan(inst, owner, thing_scandata)
            if not recipename then
                keep = false
            end

            if owner_has_builder and recipename ~= nil and
                    not owner.components.builder:KnowsRecipe(recipename) then
                if blueprintable_things == nil then
                    blueprintable_things = {}
                end
                table.insert(blueprintable_things, thing)
            end
        end

        if not keep then
            table.remove(potential_scans, i)
        end
    end

    if blueprintable_things ~= nil and #blueprintable_things > 0 then
        potential_scans = blueprintable_things
    elseif thing_but_no_data and #potential_scans <= 0 and
            not owner.components.timer:TimerExists("ANNOUNCE_WX_SCANNER_FOUND_NO_DATA") then

        owner:DoTaskInTime(2, function()
            owner.components.talker:Say(GetString(owner,"ANNOUNCE_WX_SCANNER_FOUND_NO_DATA"))
        end)
        owner.components.timer:StartTimer("ANNOUNCE_WX_SCANNER_FOUND_NO_DATA", 15)
    end

    for _, potential_scan in ipairs(potential_scans) do
        if potential_scan then
            OnTargetFound(inst, potential_scan)
            break
        end
    end

    return nil
end

local function StartScanFX(inst, target)
    if inst.scan_fx == nil and target ~= nil then
        inst.SoundEmitter:PlaySound("WX_rework/scanner/telemetry_lp", "telemetry_lp")

        inst.scan_fx = SpawnPrefab("wx78_scanner_fx")
        target:AddChild(inst.scan_fx)

        local scale = Remap(target:GetPhysicsRadius() or 0, 0, 5, 0.5, 8)
        inst.scan_fx.Transform:SetScale(scale, scale, scale)
    end
end

local function StopScanFX(inst)
    if inst.scan_fx then
        inst.scan_fx:goAway()
        inst.scan_fx = nil
    end
    inst.SoundEmitter:KillSound("telemetry_lp")
end

local function OnSuccessfulScan(inst)
    inst._donescanning = true
    inst.components.activatable.inactive = false

    local owner = inst.components.follower and inst.components.follower:GetLeader()
    local target = inst.components.entitytracker:GetEntity("scantarget")
    if target ~= nil then
        local target_scandata, scan_id = GetCreatureScanData(target)
        if target_scandata ~= nil then
            inst._module_recipe_to_teach = GetCreatureRecipeScan(inst, owner, target_scandata)
        end
        inst._scanned_id = scan_id

        inst:RemoveEventCallback("onremove", inst._OnScanTargetRemoved, target)
        inst.components.entitytracker:ForgetEntity("scantarget")
    end

    inst:StopAllScanning("succeed")
end

local function OnReturnedAfterSuccessfulScan(inst)
    inst:PushEventImmediate("scan_success")
end

local function StopAllScanning(inst, status)
    inst.components.updatelooper:RemoveOnUpdateFn(inst.IsInRangeOfPlayer)
    inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateScanCheck)

    local target = inst.components.entitytracker:GetEntity("scantarget")
    if target ~= nil then
        inst:RemoveEventCallback("onremove", inst._OnScanTargetRemoved, target)
        inst.components.entitytracker:ForgetEntity("scantarget")
    end

    inst._scantime = nil

    inst.components.timer:StopTimer(TOP_LIGHT_FLASH_TIMERNAME)

    local ringfx_type = (status == "fail" and RING_FX.FAILED) or
        (status == "succeed" and RING_FX.SUCCESS) or
        RING_FX.NONE
    inst._showringfx:set(ringfx_type)

    inst.AnimState:Hide("top_light")
    inst.AnimState:Hide("bottom_light")

    inst:StopScanFX()
end

-------------------------------------------------------------------------------------------------------
-- NET_VAR FUNCTIONS 

local function OnShowRingFXDirty(inst)
    local show_ring_fx_value = inst._showringfx:value()

    if show_ring_fx_value == RING_FX.NONE then
        if inst.prox_range ~= nil and inst.prox_range:IsValid() then
            inst.prox_range:Remove()
        end
        inst.prox_range = nil
    elseif show_ring_fx_value == RING_FX.SCANNING then
        if inst.prox_range == nil then
            inst.prox_range = CreateRingFX(inst)
            inst.prox_range.AnimState:PlayAnimation("scan_pre")
            inst.prox_range.AnimState:PushAnimation("scan_loop", true)
        end
        inst:AddChild(inst.prox_range)
    elseif show_ring_fx_value == RING_FX.FAILED then
        local fail_prox_range = CreateRingFX(inst)
        fail_prox_range.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fail_prox_range.AnimState:PlayAnimation("scan_fail")
        fail_prox_range:ListenForEvent("animover", fail_prox_range.Remove)

        if inst.prox_range ~= nil and inst.prox_range:IsValid() then
            fail_prox_range.Transform:SetRotation(inst.prox_range.Transform:GetRotation())
            inst.prox_range:Remove()
        end

        inst.prox_range = nil
        inst._showringfx:set_local(0)
    elseif show_ring_fx_value == RING_FX.SUCCESS then
        local success_prox_range = CreateRingFX(inst)
        success_prox_range.Transform:SetPosition(inst.Transform:GetWorldPosition())
        success_prox_range.AnimState:PlayAnimation("scan_success")
        success_prox_range:ListenForEvent("animover", success_prox_range.Remove)

        if inst.prox_range ~= nil and inst.prox_range:IsValid() then
            success_prox_range.Transform:SetRotation(inst.prox_range.Transform:GetRotation())
            inst.prox_range:Remove()
        end
        inst.prox_range = nil
        inst._showringfx:set_local(0)
    end
end

local function OnRadarBoostersDirty(inst)
    if inst.prox_range ~= nil then
        inst.prox_range:UpdateRadius(inst)
    end
end

local function OnSignalBoosterSkillDirty(inst)
    if inst.prox_range ~= nil then
        inst.prox_range:UpdateRadius(inst)
    end
end

---------------------------------------------------------------------------------------------------------------
-- HELPER FUNCTIONS

local function on_scanner_timer_done(inst, data)
    if data.name == "startproximityscan" then
        StartProximityScan(inst)
    elseif data.name == TOP_LIGHT_FLASH_TIMERNAME then
        top_light_flash(inst)
    end
end

local function CanDoerActivate(inst, doer)
    local leader = inst.components.follower ~= nil and inst.components.follower:GetLeader()
    return (doer == nil) or (leader == nil) or (leader == doer)
end

local function OnActivateFn(inst, doer)
    if inst._donescanning then
        -- If we got stuck after finishing a scan, and the player turned us off,
        -- go ahead and act like we succeeded as expected. Our data should be set up,
        -- just stuck because of a quirk of how buffered actions are handled.
        --      NOTE: this bug of jimmy getting stuck shouldn't happen anymore.
        inst:OnReturnedAfterSuccessfulScan()
    else
        inst:StopAllScanning()
        inst:PushEventImmediate("turn_off", { changetoitem = true, hit = not doer.isplayer })
    end
end

local function GetStatus(inst)
    return inst.components.entitytracker:GetEntity("scantarget") and "HUNTING"
        or inst.components.entitytracker:GetEntity("currentscanlock") and "SCANNING"
        or nil
end

local function IsInRangeOfPlayer(inst)
    local DISTANCE = inst:GetScannerPlayerProximityDistance()

    if inst.components.follower == nil or inst.components.follower:GetLeader() == nil or
            inst:GetDistanceSqToInst(inst.components.follower:GetLeader()) < DISTANCE*DISTANCE then
        return true
    else
        if inst.components.entitytracker:GetEntity("scantarget") then
            inst:OnScanFailed()
        end

        return false
    end
end

local FALL_DELAY = 22 * FRAMES
local function SetScanDataLanded(scandata)
    scandata.components.inventoryitem:SetLanded(true, true)
end

local function SpawnData(inst)
    local owner = inst.components.follower and inst.components.follower:GetLeader()
    if owner and owner.components.dataanalyzer and inst._scanned_id then
        local amount = owner.components.dataanalyzer:SpendData(inst._scanned_id)

        if amount > 0 then
            local scandata = SpawnPrefab("scandata")
            scandata.AnimState:PlayAnimation("fall")
            scandata.AnimState:PushAnimation("idle")

            scandata.components.inventoryitem:SetLanded(false, false)
            scandata:DoTaskInTime(FALL_DELAY, SetScanDataLanded)

            local drop_pos = inst:GetPosition() + Vector3(math.random(), 0, math.random())
            scandata.Transform:SetPosition(drop_pos:Get())

            scandata.components.stackable:SetStackSize(amount)
        end
    end
    inst._scanned_id = nil
end

local function DoTurnOff(inst)
    if not inst._turned_off then
        -- We use "inactive == true" to indicate that the scanner CAN be turned off. A quirk of activatable.
        inst.components.activatable.inactive = false
        inst:stoploopingsound()

        inst._turned_off = true

        inst:SetBrain(nil)
    end
end

local function ComplainAboutCat(wx)
    if wx.components.talker ~= nil then
        wx.components.talker:Say(GetString(wx, "ANNOUNCE_WX_SCANNER_HITDOWN_BY_CAT"))
    end
end

local DELAY_COMPLAIN_CAT = 0.3
local DELAY_COMPLAIN_CAT_VAR = 0.2
local function OnPlayedFromCat(inst, doer, isairborne)
    if inst.components.activatable.inactive and inst.components.activatable:CanActivate() then -- Don't pass doer to bypass restriction of only wx deactivating
        inst.components.activatable:DoActivate(doer)

        local wx = inst:OwnerFn()
        if wx then
            wx:DoTaskInTime(DELAY_COMPLAIN_CAT + math.random() * DELAY_COMPLAIN_CAT_VAR, ComplainAboutCat)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- SAVE/LOAD

local function on_scanner_save(inst, data)
    if inst._module_recipe_to_teach then
        data.schematic = inst._module_recipe_to_teach
    end

    if inst._turned_off then
        data.turned_off = inst._turned_off
    end

    if inst._scanned_id then
        data.scanned_id = inst._scanned_id
    end
end

local function on_scanner_load(inst, data)
    if data ~= nil then
        inst._module_recipe_to_teach = data.schematic
        inst._scanned_id = data.scanned_id or data.scanned_prefab

        if data.turned_off then
            local turnoff_data = {}
            if inst._module_recipe_to_teach ~= nil then
                turnoff_data.changetosuccess = true
            else
                turnoff_data.changetoitem = true
            end
            inst:PushEventImmediate("turn_off", turnoff_data)
        end
    end
end

-------------------------------------------------------------------------------------------------------------------

local function GetActivateVerb(inst, doer)
    return "DEACTIVATE"
end

-------------------------------------------------------------------------------------------------------------------

local function start_looping_sound(inst)
    if not inst.SoundEmitter:PlayingSound("movement_lp") then
        inst.SoundEmitter:PlaySound("WX_rework/scanner/movement_lp", "movement_lp")
    end
end

local function stop_looping_sound(inst)
    inst.SoundEmitter:KillSound("movement_lp")
end

local function OnRemove(inst)
    stop_looping_sound(inst)
    inst:StopScanFX()
end

-------------------------------------------------------------------------------------------------------------------

local function OnEntityWake(inst)
    start_looping_sound(inst)
end

local function OnEntitySleep(inst)
    stop_looping_sound(inst)
end

-------------------------------------------------------------------------------------------------------------------

local PATHCAPS = { allowocean = true, ignorecreep = true, ignorewalls = true }
local function scannerfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeTinyFlyingCharacterPhysics(inst, 1, 0.5)

    inst.Transform:SetFourFaced()

    inst.MiniMapEntity:SetIcon("wx78_scanner_item.png")
    inst.MiniMapEntity:SetCanUseCache(false)

    inst.DynamicShadow:SetSize(1.2, 0.75)

    inst:AddTag("companion")
    inst:AddTag("NOBLOCK")
    inst:AddTag("scarytoprey")
    inst:AddTag("cattoyairborne")
	inst:AddTag("flying")

    inst.AnimState:SetBank("scanner")
    inst.AnimState:SetBuild("wx_scanner")
    inst.AnimState:PlayAnimation("idle")

    inst.AnimState:Hide("top_light")
    inst.AnimState:Hide("bottom_light")

    inst.GetActivateVerb = GetActivateVerb

    inst._showringfx = net_tinybyte(inst.GUID, "showringfx", "showringfxdirty")
    local radarboosters_net_enum = GetIdealUnsignedNetVarForCount(MAX_CIRCUIT_SLOTS)
    inst._radarboosters = radarboosters_net_enum(inst.GUID, "radarboosters", "radarboostersdirty")
    inst._hassignalbooster = net_bool(inst.GUID, "hassignalbooster", "signalboosterdirty")
    if not TheNet:IsDedicated() then
        inst:ListenForEvent("showringfxdirty", OnShowRingFXDirty)
        inst:ListenForEvent("radarboostersdirty", OnRadarBoostersDirty)
        inst:ListenForEvent("signalboosterdirty", OnSignalBoosterSkillDirty)
    end
    inst._showringfx:set_local(0)
    inst._radarboosters:set_local(0)
    inst._hassignalbooster:set_local(false)

    inst.GetScannerScanDistance = GetScannerScanDistance
    inst.GetScannerPlayerProximityDistance = GetScannerPlayerProximityDistance

    MakeInventoryFloatable(inst, nil, 0.15, ITEM_FLOATER_SCALE)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

	inst:AddComponent("maprevealable")
	inst.components.maprevealable:SetIconPrefab("globalmapiconunderfog")

    -------------------------------------------------------------------
    inst:AddComponent("entitytracker")

    -------------------------------------------------------------------
    inst:AddComponent("follower")
    inst.components.follower.OnChangedLeader = OnChangedLeader

    -------------------------------------------------------------------
    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    -------------------------------------------------------------------
    inst:AddComponent("locomotor")
    inst.components.locomotor:EnableGroundSpeedMultiplier(false)
    inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.pathcaps = PATHCAPS
    inst.components.locomotor.walkspeed = 4.25

    -------------------------------------------------------------------
    inst:AddComponent("timer")

    -------------------------------------------------------------------
    inst:AddComponent("activatable")
    inst.components.activatable.CanActivateFn = CanDoerActivate
    inst.components.activatable.OnActivate = OnActivateFn
    inst.components.activatable.quickaction = true
    inst.components.activatable.forcerightclickaction = true
    inst.components.activatable.forcenopickupaction = true

    inst:AddComponent("cattoy")
    inst.components.cattoy:SetOnPlay(OnPlayedFromCat)
    inst.components.cattoy:SetBypassLastAirTime(true)

    -------------------------------------------------------------------
    inst:AddComponent("updatelooper")

    -------------------------------------------------------------------
    inst:ListenForEvent("timerdone", on_scanner_timer_done)
    inst:ListenForEvent("onremove", OnRemove)

    -------------------------------------------------------------------
    inst.startloopingsound = start_looping_sound
    inst.stoploopingsound = stop_looping_sound

    inst.OnEntityWake = OnEntityWake
    inst.OnEntitySleep = OnEntitySleep

    -------------------------------------------------------------------
    inst.StartScanFX = StartScanFX
    inst.StopScanFX = StopScanFX

    inst.StopAllScanning = StopAllScanning
    inst.SpawnData = SpawnData
    inst.IsInRangeOfPlayer = IsInRangeOfPlayer
    inst.OnSuccessfulScan = OnSuccessfulScan
    inst.OnScanFailed = OnScanFailed
    inst.OnReturnedAfterSuccessfulScan = OnReturnedAfterSuccessfulScan

    inst.OwnerFn = scanner_owner_fn
    inst.LoopFn = scanner_loop_fn

    inst.TryFindTarget = TryFindTarget

    inst.DoTurnOff = DoTurnOff

    -------------------------------------------------------------------
    -- For an "onremove" when scan targets get deleted out from under us.
    inst._OnScanTargetRemoved = function(t)
        OnScanFailed(inst)
    end

	inst._onrangerefresh = function(owner)
		UpdateScannerRadarBoosters(inst)
	end

    -------------------------------------------------------------------
    inst:SetStateGraph("SGwx78_scanner")
    inst:SetBrain(brain)
    
    -------------------------------------------------------------------
    inst.OnSave = on_scanner_save
    inst.OnLoad = on_scanner_load

    -------------------------------------------------------------------
    MakeHauntable(inst)

    inst.components.timer:StartTimer("startproximityscan", 0)

    return inst
end

-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
-- Prefab for the "succeeded and waiting to be harvested" state

local SUCCEEDED_FLASH_TIMERNAME = "onsucceeded_flashtick"
local SUCCEEDED_ONSPAWN_TIMERNAME = "onsucceeded_onspawn"
local SUCCEEDED_TIMEOUT_TIMERNAME = "onsucceeded_timeout"

local function OnTeach(inst, learner)
    learner:PushEvent("learnrecipe", { teacher = inst, recipe = inst.components.teacher.recipe })
end

local function on_harvested(inst, picker, produce)
    if picker ~= nil and picker.components.inventory ~= nil then
        if inst._module_recipe ~= nil then
            inst.components.teacher:SetRecipe(inst._module_recipe)
            inst._module_recipe = nil

            inst.components.teacher:Teach(picker)
        end

        local scanner_item = SpawnPrefab("wx78_scanner_item", inst.linked_skinname, inst.skin_id)
        if scanner_item ~= nil then
            picker.components.inventory:GiveItem(scanner_item, nil, inst:GetPosition())
            inst:Remove()
        end
    end
end

local function can_harvest(inst, doer)
    if doer == nil or doer.components.upgrademoduleowner == nil then
        return false, "DOER_ISNT_MODULE_OWNER"
    end

    -- TODO make this a bit more modular
    if doer.components.skilltreeupdater and not doer.components.skilltreeupdater:IsActivated("wx78_zapdrone_1")
        and inst._module_recipe == "wx78_drone_zap_remote" then
        return false, "DOER_DOESNT_HAVE_SKILL"
    end

    return true, nil
end

local function SetUpFromScanner(inst, scanner)
    inst.Transform:SetPosition(scanner.Transform:GetWorldPosition())
    inst.Transform:SetRotation(scanner.Transform:GetRotation())
    inst.AnimState:MakeFacingDirty() --not needed for clients
    inst._module_recipe = scanner._module_recipe_to_teach
end

local function on_succeeded_save(inst, data)
    if inst._module_recipe then
        data.module_recipe = inst._module_recipe
    end
end

local function on_succeeded_load(inst, data)
    if data ~= nil then
        inst._module_recipe = data.module_recipe
    end
end

local function do_flash_tick(inst)
    inst._flash = not inst._flash

    if inst._flash then
        inst.AnimState:Show("top_light")
    else
        inst.AnimState:Hide("top_light")
    end

    -- This flash loops indefinitely.
    inst.components.timer:StartTimer(SUCCEEDED_FLASH_TIMERNAME, 15*FRAMES)
end

local function on_succeeded_spawned(inst)
    inst:PushEvent("on_landed")
end

local function on_succeeded_timeout(inst)
    -- If we weren't harvested within our timeout, revert to our pure item state.
    -- This is so that worlds will not become cluttered with successful scanners
    -- that other players cannot interact with.
    inst._module_recipe = nil

    local scanner_item = SpawnPrefab("wx78_scanner_item", inst.linked_skinname, inst.skin_id)
    scanner_item.Transform:SetPosition(inst.Transform:GetWorldPosition())
    scanner_item.Transform:SetRotation(inst.Transform:GetRotation())
    scanner_item.AnimState:MakeFacingDirty() --not needed for clients

    inst:Remove()
end

local function on_succeeded_timer_done(inst, data)
    if data.name == SUCCEEDED_FLASH_TIMERNAME then
        do_flash_tick(inst)
    elseif data.name == SUCCEEDED_ONSPAWN_TIMERNAME then
        on_succeeded_spawned(inst)
    elseif data.name == SUCCEEDED_TIMEOUT_TIMERNAME then
        on_succeeded_timeout(inst)
    end
end

local function scannersucceededfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.Transform:SetFourFaced()

    inst.MiniMapEntity:SetIcon("wx78_scanner_item.png")

    inst.AnimState:SetBank("scanner")
    inst.AnimState:SetBuild("wx_scanner")
    inst.AnimState:PlayAnimation("turn_off_idle")

    inst.AnimState:Hide("top_light")
    inst.AnimState:Hide("bottom_light")

    MakeInventoryFloatable(inst, nil, 0.15, ITEM_FLOATER_SCALE)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -------------------------------------------------------------------
    inst:AddComponent("inspectable")

    -------------------------------------------------------------------
    inst:AddComponent("teacher")
    inst.components.teacher.onteach = OnTeach

    -------------------------------------------------------------------
    inst:AddComponent("harvestable")
    inst.components.harvestable:SetOnHarvestFn(on_harvested)
    inst.components.harvestable:SetCanHarvestFn(can_harvest)
    inst.components.harvestable.produce = 1

    -------------------------------------------------------------------
    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", on_succeeded_timer_done)

    -------------------------------------------------------------------
    --inst._module_recipe = nil

    -------------------------------------------------------------------
    inst.SetUpFromScanner = SetUpFromScanner
    inst.OnSave = on_succeeded_save
    inst.OnLoad = on_succeeded_load

    -------------------------------------------------------------------
    MakeHauntable(inst)

    -------------------------------------------------------------------
    inst._flash = true
    inst.components.timer:StartTimer(SUCCEEDED_FLASH_TIMERNAME, 15*FRAMES)

    inst.components.timer:StartTimer(SUCCEEDED_ONSPAWN_TIMERNAME, 0)

    inst.components.timer:StartTimer(SUCCEEDED_TIMEOUT_TIMERNAME, TUNING.WX78_SCANNER_TIMEOUT)

    return inst
end

-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
-- FX

local function goAway(inst)
    inst.AnimState:PlayAnimation("scan_fx_pst")
    inst:ListenForEvent("animover", inst.Remove)
end

local function scanfx_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("scanner")
    inst.AnimState:SetBuild("wx_scanner")
    inst.AnimState:PlayAnimation("scan_fx_pre")
    inst.AnimState:PushAnimation("scan_fx_loop",true)

    inst:AddTag("FX")

    inst.AnimState:SetLayer(LAYER_BACKGROUND)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end
    inst.goAway = goAway

    return inst
end

local function placer_postinit_fn(inst)
    inst.AnimState:Hide("top_light")
    inst.AnimState:Hide("bottom_light")
end

return Prefab("wx78_scanner_item", itemfn, assets, item_prefabs),
    MakePlacer("wx78_scanner_item_placer", "scanner", "wx_scanner", "turn_off_idle", nil, nil, nil, nil, nil, nil, placer_postinit_fn),
    Prefab("wx78_scanner", scannerfn, assets, scanner_prefabs),
    Prefab("wx78_scanner_succeeded", scannersucceededfn, assets),
    Prefab("wx78_scanner_fx", scanfx_fn, assets)
