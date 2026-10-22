require("worldsettingsutil")
local easing = require("easing")

local assets =
{
    Asset("ANIM", "anim/atrium_gate.zip"),
    Asset("ANIM", "anim/atrium_gate_shrouden.zip"),
    Asset("ANIM", "anim/atrium_gate_build.zip"),
    Asset("ANIM", "anim/atrium_floor.zip"),
    Asset("ANIM", "anim/atrium_ritual.zip"),
    Asset("MINIMAP_IMAGE", "atrium_gate_active"),
    Asset("MINIMAP_IMAGE", "atrium_gate_fixed"),
    Asset("MINIMAP_IMAGE", "atrium_gate_fixed_active"),
    Asset("MINIMAP_IMAGE", "atrium_gate_keystone"), -- fixed + keystone!
    Asset("MINIMAP_IMAGE", "atrium_gate_keystone_active"), -- fixed + keystone + original key!
}

local prefabs =
{
    "atrium_key",
    "atrium_gate_activatedfx",
    "atrium_gate_pulsesfx",
    "atrium_gate_explodesfx",
    "atrium_ritual_marking",
    "charlie_hand",
    "charlie_hand_keystone",
    "charlie_circle_spawn_fx",
    "charlie_circle_spawn_ground_fx",

    "king_cane",
    "queen_torch",
    "mask_charlie_bosshat",
}

local RITUAL_STATES =
{
    DISABLED = 0,
    ENABLED = 1,
    ACTIVE = 2, -- ritual has all 3 pieces
    SUMMONING = 3, -- we're summoning shrouden
    SUMMONED = 4, -- summoned, tentacles pop out, room morphs, charlie taken
    -- then reset back to ENABLED? or we need another state here?
}

local EXPLOSION_ANIM_LEN = 86 * FRAMES

local NUM_RITUAL_MARKINGS = 3

--------------------------------------------------------------------------

local ATRIUM_ARENA_SIZE = 14.55

local function IsObjectInAtriumArena(inst, obj)
    if obj == nil then
        return false
    end
    local obj_x, _, obj_z = obj.Transform:GetWorldPosition()
    local inst_x, _, inst_z = inst.Transform:GetWorldPosition()
    return math.abs(obj_x - inst_x) < ATRIUM_ARENA_SIZE
        and math.abs(obj_z - inst_z) < ATRIUM_ARENA_SIZE
end

--------------------------------------------------------------------------

local function OnFocusCamera(inst)
    if inst._camerafocusvalue > FRAMES then
        inst._camerafocusvalue = inst._camerafocusvalue - FRAMES
        local k = math.min(1, inst._camerafocusvalue) / 1
        local offset = (inst.ritual_state:value() >= RITUAL_STATES.SUMMONING and Vector3(0, 2.75)) or nil
        TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 10 * k, 28 * k, 4, nil, offset)
    else
        inst._camerafocustask:Cancel()
        inst._camerafocustask = nil
        inst._camerafocusvalue = nil
        TheFocalPoint.components.focalpoint:StopFocusSource(inst)
    end
end

local function OnCameraFocusDirty(inst)
    if inst._camerafocus:value() > 0 then
        if inst._camerafocus:value() <= 1 then
            inst._camerafocusvalue = math.huge
            if inst._camerafocustask == nil then
                inst._camerafocustask = inst:DoPeriodicTask(0, OnFocusCamera)
                OnFocusCamera(inst)
            end
        elseif inst._camerafocustask ~= nil then
            inst._camerafocusvalue = 3
            OnFocusCamera(inst)
        end
    elseif inst._camerafocustask ~= nil then
        inst._camerafocustask:Cancel()
        inst._camerafocustask = nil
        inst._camerafocusvalue = nil
        TheFocalPoint.components.focalpoint:StopFocusSource(inst)
    end
end

local function SetCameraFocus(inst, level)
    if level ~= inst._camerafocus:value() then
        inst._camerafocus:set(level)
        if not TheNet:IsDedicated() then
            OnCameraFocusDirty(inst)
        end
    end
end

local function EnablePickable(inst, enabled)
    if not enabled then
        inst:AddTag("intense")
        inst.components.pickable:SetStuck(true)
    elseif inst.components.pickable:IsStuck() then
        inst:RemoveTag("intense")
        inst.components.pickable:SetStuck(false)
    end
end

--------------------------------------------------------------------------

local SUPPRESS_SHADOWS_RANGE = math.ceil(ATRIUM_ARENA_SIZE + 5)
local SUPPRESS_SHADOWS_MUST_TAGS = { "_health" }
local SUPPRESS_SHADOWS_ONEOF_TAGS = { "stalkerminion", "shadowcreature" }

local function OnSuppressShadows(inst, x, z, range)
    for i, v in ipairs(TheSim:FindEntities(x, 0, z, range, SUPPRESS_SHADOWS_MUST_TAGS, nil, SUPPRESS_SHADOWS_ONEOF_TAGS)) do
        if not v.components.health:IsDead() then
            local x1, y1, z1 = v.Transform:GetWorldPosition()
            if math.abs(x1 - x) < SUPPRESS_SHADOWS_RANGE and
                math.abs(z1 - z) < SUPPRESS_SHADOWS_RANGE then
                if v.components.lootdropper ~= nil then
                    v.components.lootdropper:SetLoot(nil)
                    v.components.lootdropper:SetChanceLootTable(nil)
                end
                v.components.health:Kill()
            end
        end
    end
end

local function EnableShadowSuppression(inst, enable)
    if enable then
        if inst._shadowsuppressiontask == nil then
            local x, y, z = inst.Transform:GetWorldPosition()
            local range = math.sqrt(SUPPRESS_SHADOWS_RANGE * SUPPRESS_SHADOWS_RANGE * 2)
            inst._shadowsuppressiontask = inst:DoPeriodicTask(1, OnSuppressShadows, nil, x, z, range)
            OnSuppressShadows(inst, x, z, range)
        end
    elseif inst._shadowsuppressiontask ~= nil then
        inst._shadowsuppressiontask:Cancel()
        inst._shadowsuppressiontask = nil
    end
end

--------------------------------------------------------------------------

local function IsDestabilizing(inst)
    return inst.components.worldsettingstimer:ActiveTimerExists("destabilizing")
end

local function ShowFx(inst, state)
    if inst._gatefx == nil then
        inst._gatefx = SpawnPrefab("atrium_gate_activatedfx")
        inst._gatefx.entity:SetParent(inst.entity)
        table.insert(inst.highlightchildren, inst._gatefx)
    end

    inst._gatefx:SetFX(state)
end

local function HideFx(inst)
    if inst._gatefx ~= nil then
        inst._gatefx:KillFX()
        inst._gatefx = nil
    end
end

local function ItemTradeTest(inst, item)
    if item == nil then
        return false
    elseif item.prefab == "vault_key" then
        return false, "CANTSOCKETVAULTKEY"
    elseif item.prefab ~= "atrium_key" then
        return false, "NOTATRIUMKEY"
    end
    return true
end

local function OnKeyGiven(inst, giver, pushanim)
    WORLDSTATETAGS.SetTagEnabled("ATRIUM_KEY_FOUND", true)
    --Disable trading, enable picking.
    inst.components.trader:Disable()
    inst.components.pickable:SetUp("atrium_key", 1000000)
    inst.components.pickable:Pause()
    inst.components.pickable.caninteractwith = true

    if pushanim then
        inst.AnimState:PushAnimation("idle_active")
    else
        inst.AnimState:PlayAnimation("idle_active")
    end

    local vaultkeyin = inst:IsVaultKeySocketed()
    local repaired = inst.components.charliecutscene:IsGateRepaired()
    inst.MiniMapEntity:SetIcon(vaultkeyin and "atrium_gate_keystone_active.png" or repaired and "atrium_gate_fixed_active.png" or "atrium_gate_active.png")

    TheWorld:PushEvent("atriumpowered", true)
    TheWorld:PushEvent("ms_locknightmarephase", "wild")
    TheWorld:PushEvent("pausequakes", { source = inst })
    TheWorld:PushEvent("pausehounded", { source = inst })

    if giver ~= nil then
        inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium_gate/key_in")

--      if giver.components.talker ~= nil then
--          giver.components.talker:Say(GetString(giver, "ANNOUNCE_GATE_ON"))
--      end
    end
end

local function OnKeyTaken(inst)
    --Disable picking, enable trading.
    inst.components.trader:Enable()
    inst.components.pickable.caninteractwith = false
    EnablePickable(inst, true)

    inst.SoundEmitter:KillSound("loop")

    inst.AnimState:PlayAnimation("idle")

    local vaultkeyin = inst:IsVaultKeySocketed()
    local repaired = inst.components.charliecutscene:IsGateRepaired()
    inst.MiniMapEntity:SetIcon(vaultkeyin and "atrium_gate_keystone.png" or repaired and "atrium_gate_fixed.png" or "atrium_gate.png")

    HideFx(inst)

    TheWorld:PushEvent("atriumpowered", false)
    TheWorld:PushEvent("ms_locknightmarephase", nil)
    TheWorld:PushEvent("unpausequakes", { source = inst })
    TheWorld:PushEvent("unpausehounded", { source = inst })
end

local function SocketVaultKey(inst, loading)
    WORLDSTATETAGS.SetTagEnabled("VAULT_KEY_FOUND", true)
    inst.vault_key_socketed = true
    inst.AnimState:Show("KEY")

    local active = inst.components.pickable.caninteractwith or inst.components.worldsettingstimer:ActiveTimerExists("destabilizedelay")
    inst.MiniMapEntity:SetIcon(active and "atrium_gate_keystone_active.png" or "atrium_gate_keystone.png")

    if not loading then
        -- kill off cooldown timer if it exists
        inst.components.worldsettingstimer:StopTimer("cooldown")
        inst.SoundEmitter:KillSound("loop")

        local placing_both_keys = not inst.components.pickable.caninteractwith
        if placing_both_keys then
            inst.AnimState:PlayAnimation("place_both_keys")
            -- save load case handled in charliecutscene:LoadPostPass
            inst:DoTaskInTime(109 * FRAMES, OnKeyGiven, nil, true) -- For the original key
        else
            inst.AnimState:PlayAnimation("place_vault_key")
            inst.AnimState:PushAnimation("idle_active", true)

        end
        inst.SoundEmitter:PlaySoundWithParams("rifts8/charlie_ritual/keys", { key_amt = placing_both_keys and .5 or 0 })
    end
end

local function DestroyVaultKey(inst)
    inst.vault_key_socketed = nil
    inst.AnimState:Hide("KEY")
    WORLDSTATETAGS.SetTagEnabled("VAULT_KEY_FOUND", false)

    local active = inst.components.pickable.caninteractwith or inst.components.worldsettingstimer:ActiveTimerExists("destabilizedelay")
    inst.MiniMapEntity:SetIcon(active and "atrium_gate_fixed_active.png" or "atrium_gate_fixed.png")
end

local function IsVaultKeySocketed(inst)
    return inst.vault_key_socketed
end

local function DoPlayerWarning(inst, player)
    if player:IsValid() then
        player.components.talker:Say(GetString(player, "ANNOUNCE_ATRIUM_DESTABILIZING"))
    end
end

local function OnDestabilizingPulse(inst)
    inst.talkertick = inst.talkertick ~= nil and inst.talkertick + 1 or 0

    if not inst:IsDestabilizing() then
        inst.destabilizingnotificationtask:Cancel()
        inst.destabilizingnotificationtask = nil
        return
    end

    for i, player in ipairs(AllPlayers) do
        if player.components.areaaware:CurrentlyInTag("Nightmare") then
            if not IsObjectInAtriumArena(inst, player) then
                player:ShakeCamera(CAMERASHAKE.SIDE, 1, .02, .25)
                if (inst.talkertick % 2) == (i % 2) then
                    inst:DoTaskInTime(1, DoPlayerWarning, player)
                end
            else
                player:ShakeCamera(CAMERASHAKE.SIDE, 2, .06, .25)
                inst:DoTaskInTime(1, DoPlayerWarning, player)
            end
        end
    end

    SpawnPrefab("atrium_gate_pulsesfx").Transform:SetPosition(inst.Transform:GetWorldPosition())

    inst.AnimState:PlayAnimation("overload_pulse")
    inst.AnimState:PushAnimation("overload_loop")
end

local function StartDestabilizing(inst, onload)
    WORLDSTATETAGS.SetTagEnabled("ATRIUM_KEY_FOUND", true)
    inst.components.trader:Disable()
    inst.components.pickable.caninteractwith = false
    EnablePickable(inst, true)
    SetCameraFocus(inst, 2)
    EnableShadowSuppression(inst, true)

    if not inst.components.worldsettingstimer:ActiveTimerExists("destabilizing") then
        inst.components.worldsettingstimer:StartTimer("destabilizing", TUNING.ATRIUM_GATE_DESTABILIZE_TIME)
    end

    if not onload then
        TheWorld:PushEvent("atriumpowered", false)
        inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium_gate/shadow_pulse")
    end

    ShowFx(inst, "overload")
    if inst._disablelighttask ~= nil then
        inst._disablelighttask:Cancel()
        inst._disablelighttask = nil
    end
    if inst._launchkeytask ~= nil then
        inst._launchkeytask:Cancel()
        inst._launchkeytask = nil
    end
    inst.Light:Enable(true)
    inst.SoundEmitter:KillSound("loop")
    inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium_gate/destabilize_LP", "loop")
    inst.AnimState:PlayAnimation("overload_pre")
    inst.AnimState:PushAnimation("overload_loop", true)

    inst.destabilizingnotificationtask = inst:DoPeriodicTask(TUNING.ATRIUM_GATE_DESTABILIZE_WARNING_TIME, OnDestabilizingPulse, TUNING.ATRIUM_GATE_DESTABILIZE_WARNING_INITIAL_TIME)
end

local function OnQueueDestabilize(inst, onload)
    if onload then
        ShowFx(inst, "idle")
        inst.AnimState:PlayAnimation("idle_fight", true)
        inst.SoundEmitter:KillSound("loop")
        inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium_gate/active_LP", "loop")
    end

    inst.components.trader:Disable()
    inst.components.pickable.caninteractwith = false
    EnablePickable(inst, true)
    SetCameraFocus(inst, 1)
    EnableShadowSuppression(inst, true)

    if inst.components.worldsettingstimer:ActiveTimerExists("destabilizedelay") then
        inst.components.worldsettingstimer:StopTimer("destabilizedelay")
    end

    inst.components.worldsettingstimer:StartTimer("destabilizedelay", TUNING.ATRIUM_GATE_DESTABILIZE_DELAY)
end

local function Destabilize(inst, failed)
    if inst.components.pickable.caninteractwith then
        if not failed then
            OnQueueDestabilize(inst)
        else
            local key = SpawnPrefab("atrium_key")
            LaunchAt(key, inst, nil, 1.5, 1, 1)

            OnKeyTaken(inst)
        end
    end
end

local function DisableLight(inst)
    inst._disablelighttask = nil
    inst.Light:Enable(false)
end

local function LaunchKey(inst)
    local key = SpawnPrefab("atrium_key")
    LaunchAt(key, inst, nil, 1.5, 1, 1)
    inst._launchkeytask = nil
end

local function OnDestabilizeExplode(inst)
    SetCameraFocus(inst, 0)
    EnableShadowSuppression(inst, false)
    inst.AnimState:PlayAnimation("overload_pst", false)
    SpawnPrefab("atrium_gate_explodesfx").Transform:SetPosition(inst.Transform:GetWorldPosition())
    HideFx(inst)
    if inst._disablelighttask ~= nil then
        inst._disablelighttask:Cancel()
    end
    if inst._launchkeytask ~= nil then
        inst._launchkeytask:Cancel()
    end
    inst._disablelighttask = inst:DoTaskInTime(1.75, DisableLight)
    inst._launchkeytask = inst:DoTaskInTime(47 * FRAMES, LaunchKey)

    inst:StartCooldown(false)

    TheWorld:PushEvent("resetruins")
    if TheWorld.components.charlie_tracker:IsCharlieDefeated() then -- we've beat shrouden once
        TheWorld:PushEvent("resetvault") -- defeating shrouden also resets vault
    end

    for _, player in ipairs(AllPlayers) do
        player.components.talker:Say(GetString(player, "ANNOUNCE_RUINS_RESET"))
        player:ShakeCamera(CAMERASHAKE.SIDE, 2, .06, .25)
    end
end

local function ForceDestabilizeExplode(inst)
    -- returns true if a destabilization was actually forced
    if inst:IsDestabilizing() then
        -- Force the atrium gate to finish its destabilization process.
        if inst.components.worldsettingstimer:ActiveTimerExists("destabilizing") then
            inst.components.worldsettingstimer:StopTimer("destabilizing")
        end
        OnDestabilizeExplode(inst)

        return true
    end

    return false
end

local function OnCooldown(inst)
    if inst.components.worldsettingstimer:ActiveTimerExists("cooldown") then
        inst.AnimState:PlayAnimation("cooldown", true)
        inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium_gate/cooldown_LP", "loop")
    end
end

local function StartCooldown(inst, immediate)
    if inst.components.worldsettingstimer:ActiveTimerExists("destabilizing") then
        inst.components.worldsettingstimer:StopTimer("destabilizing")
        OnDestabilizeExplode(inst)
    end

    SetCameraFocus(inst, 0)
    EnableShadowSuppression(inst, false)
    EnablePickable(inst, true)
    inst.components.pickable.caninteractwith = false
    inst.components.trader:Disable()
    inst.SoundEmitter:KillSound("loop")
    TheWorld:PushEvent("ms_locknightmarephase", nil)
    TheWorld:PushEvent("unpausequakes", { source = inst })
    TheWorld:PushEvent("unpausehounded", { source = inst })

    if immediate then
        inst.AnimState:PlayAnimation("cooldown", true)
        inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium_gate/cooldown_LP", "loop")
    else
        inst:DoTaskInTime(EXPLOSION_ANIM_LEN, OnCooldown)
    end

    if not inst.components.worldsettingstimer:ActiveTimerExists("cooldown") then
        inst.components.worldsettingstimer:StartTimer("cooldown", TUNING.ATRIUM_GATE_COOLDOWN)
    end
end

local function OnTrackStalker(inst, stalker)
    if stalker.components.health ~= nil and not stalker.components.health:IsDead() then
        inst:ListenForEvent("onremove", inst._onremovestalker, stalker)
        inst:ListenForEvent("death", inst._onstalkerdeath, stalker)
        EnablePickable(inst, false)
        SetCameraFocus(inst, 0)
        EnableShadowSuppression(inst, false)
        ShowFx(inst, "idle")
        inst.AnimState:PlayAnimation("idle_fight", true)
        inst.SoundEmitter:KillSound("loop")
        inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium_gate/active_LP", "loop")

        for i = 1, NUM_RITUAL_MARKINGS do
            local marking = inst.components.entitytracker:GetEntity("ritualmarking"..tostring(i))
            if marking and marking.item then
                marking.item:SetItem()
            end
        end
    else
        --cleanup bad state, shouldn't reach here normally
        --but possible with corrupt or tampering save data
        inst.components.entitytracker:ForgetEntity("stalker")
    end
end

local function TrackStalker(inst, stalker)
    local old = inst.components.entitytracker:GetEntity("stalker")
    if old ~= stalker then
        if old ~= nil then
            inst.components.entitytracker:ForgetEntity("stalker")
            inst:RemoveEventCallback("onremove", inst._onremovestalker, old)
            inst:RemoveEventCallback("death", inst._onstalkerdeath, old)
        end
        inst.components.entitytracker:TrackEntity("stalker", stalker)

        if not inst.components.pickable.caninteractwith then
            OnKeyGiven(inst)
        end

        OnTrackStalker(inst, stalker)
    end
end

local function ontimer(inst, data)
    if data.name == "destabilizedelay" then
        StartDestabilizing(inst)
    elseif data.name == "destabilizing" then
        OnDestabilizeExplode(inst)
    elseif data.name == "cooldown" then
        inst.AnimState:PlayAnimation("idle")
        inst.components.trader:Enable()
        inst.SoundEmitter:KillSound("loop")
    end
end

local function getstatus(inst)
    return (inst:IsRitualSummoning() and "RITUAL_SUMMONING")
        or (inst:IsDestabilizing() and "DESTABILIZING")
        or (inst.components.worldsettingstimer:ActiveTimerExists("cooldown") and "COOLDOWN")
        or ((inst:HasTag("intense") or inst.components.worldsettingstimer:ActiveTimerExists("destabilizedelay")) and "CHARGING")
        -- or (inst:IsVaultKeySocketed() and "ON_VAULT")
        or (inst.components.pickable.caninteractwith and "ON")
        or "OFF"
end

local function IsGateOn(inst)
    local status = getstatus(inst)
    return status == "ON" or status == "ON_VAULT"
end

local function IsWaitingForStalker(inst)
    return IsGateOn(inst) and (inst:GetRitualState() < RITUAL_STATES.ACTIVE)
end

local function OnEntitySleep(inst)
    if inst._sleeptask ~= nil then
        inst._sleeptask:Cancel()
    end
    inst._sleeptask = IsGateOn(inst) and inst:DoTaskInTime(10, function() if IsGateOn(inst) then Destabilize(inst, true) end end) or nil
end

local function OnEntityWake(inst)
    if inst._sleeptask ~= nil then
        inst._sleeptask:Cancel()
        inst._sleeptask = nil
    end
end

local function OnSave(inst, data)
    data.vault_key_socketed = inst:IsVaultKeySocketed()
    data.ritual_state = inst.ritual_state:value()
    if inst._launchkeytask ~= nil then
        data.launch_key = true
    end
end

local function OnLoad(inst, data)
    if data ~= nil then
        if data.vault_key_socketed then
            inst:SocketVaultKey(true)
        end
        if data.launch_key then
            local key = SpawnPrefab("atrium_key")
            LaunchAt(key, inst, nil, 1.5, 1, 1)
        end
    end
end

local function OnLoadPostPass(inst, ents, data)
    -- Repair the gate automatically if shadow rifts are always on, otherwise the shadow hand never arrives
    if TheWorld.topology.overrides ~= nil and TheWorld.topology.overrides.rifts_enabled_cave == "always" and not inst.components.charliecutscene:IsGateRepaired() then
        inst.components.charliecutscene:RepairGate()
    end
    if data then
        if inst._runningkeysocket--[[from charliecutscene:LoadPostPass]] then
            inst:EnableRitual(true)
            inst._runningkeysocket = nil
        elseif data.ritual_state then
            inst:SetRitualState(data.ritual_state)
        end
    end
    if inst:IsDestabilizing() then
        StartDestabilizing(inst, true)
    elseif inst.components.worldsettingstimer:ActiveTimerExists("cooldown") then
        StartCooldown(inst, true)
    elseif inst.components.pickable.caninteractwith or inst.components.worldsettingstimer:ActiveTimerExists("destabilizedelay") then
        OnKeyGiven(inst)

        local stalker = inst.components.entitytracker:GetEntity("stalker")
        if stalker ~= nil then
            OnTrackStalker(inst, stalker)
        end

        if inst.components.worldsettingstimer:ActiveTimerExists("destabilizedelay") then
            OnQueueDestabilize(inst, true)
        end
    end
end

local function InitializePathFinding(inst)
    local x, _, z = inst.Transform:GetWorldPosition()
    TheWorld.Pathfinder:AddWall(x - 0.5, 0, z - 0.5)
    TheWorld.Pathfinder:AddWall(x - 0.5, 0, z + 0.5)
    TheWorld.Pathfinder:AddWall(x + 0.5, 0, z - 0.5)
    TheWorld.Pathfinder:AddWall(x + 0.5, 0, z + 0.5)
end

local function OnRemove(inst)
    local x, _, z = inst.Transform:GetWorldPosition()
    TheWorld.Pathfinder:RemoveWall(x - 0.5, 0, z - 0.5)
    TheWorld.Pathfinder:RemoveWall(x - 0.5, 0, z + 0.5)
    TheWorld.Pathfinder:RemoveWall(x + 0.5, 0, z - 0.5)
    TheWorld.Pathfinder:RemoveWall(x + 0.5, 0, z + 0.5)
end

--------------------------------------------------------------------------

local KEYSTONE_MUST_TAGS = { "irreplaceable" }
local KEYSTONE_RADIUS = math.ceil(ATRIUM_ARENA_SIZE + 3)

local function FindKeyStone(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, KEYSTONE_RADIUS, KEYSTONE_MUST_TAGS)
    for i, v in ipairs(ents) do
        if v ~= inst and v.prefab == "vault_key" then
            return v
        end
    end

    return nil
end

local function UpdateCharlieHandKeyStone(inst)
    local charliehand = inst.components.entitytracker:GetEntity("charlie_hand")
    local canspawn = inst.components.charliecutscene:IsGateRepaired()
        and not inst:IsVaultKeySocketed()
        and not inst:HasTag("intense")
        and not inst.AnimState:IsCurrentAnimation("idle_fight")
        and not inst.components.worldsettingstimer:ActiveTimerExists("destabilizing")

    if charliehand == nil and canspawn then
        local keystone = FindKeyStone(inst)
        if keystone ~= nil then
            inst.components.charliecutscene:SpawnCharlieHandKeyStone()
        end
    elseif charliehand ~= nil and charliehand.prefab == "charlie_hand_keystone" and charliehand.persists then
        local despawn = FindKeyStone(inst) == nil or not canspawn
        if despawn then
            charliehand.persists = false
            charliehand:RunAway()
        end
    end
end

local function OnPlayerNear(inst, player)
    inst.players = inst.players or {}
    inst.players[player] = true

    UpdateCharlieHandKeyStone(inst)
    if inst.charlie_hand_keystone_task == nil then
        inst.charlie_hand_keystone_task = inst:DoPeriodicTask(1, UpdateCharlieHandKeyStone)
    end
end

local function OnPlayerFar(inst, player)
    inst.players[player] = nil
    if next(inst.players) == nil then
        local charliehand = inst.components.entitytracker:GetEntity("charlie_hand")
        if charliehand and charliehand.prefab == "charlie_hand_keystone" and charliehand.persists then
            charliehand.persists = false
            charliehand:RunAway()
        end

        inst.players = nil
        if inst.charlie_hand_keystone_task ~= nil then
            inst.charlie_hand_keystone_task:Cancel()
            inst.charlie_hand_keystone_task = nil
        end
    end
end

--------------------------------------------------------------------------

local function SpawnShroudenLootSetPiece(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local theta = inst.components.charliecutscene:FindRitualAngle() * DEGREES

    theta = theta - PI/4

    if not (TheWorld.components.charlie_tracker and TheWorld.components.charlie_tracker:IsCharlieDefeated()) then
        local hat = SpawnPrefab("mask_charlie_bosshat")
        hat.Transform:SetPosition(x + math.cos(theta) * 6.75, y, z - math.sin(theta) * 6.75)
        hat:PushCameraFocusForNextLoad()
    end

    theta = theta - PI/16
    SpawnPrefab("king_cane").Transform:SetPosition(x + math.cos(theta) * 7.25, y, z - math.sin(theta) * 7.25)

    theta = theta + PI/16
    theta = theta + PI/16
    SpawnPrefab("queen_torch").Transform:SetPosition(x + math.cos(theta) * 8.75, y, z - math.sin(theta) * 8.75)
end

--------------------------------------------------------------------------

local function GetRitualTime()
    local charlie_tracker = TheWorld.components.charlie_tracker
    return (charlie_tracker and charlie_tracker:IsCharlieDefeated() and TUNING.SHROUDEN_RITUAL_NOCHARLIE_TIME)
        or TUNING.SHROUDEN_RITUAL_TIME
end

local function UpdateShroudenTarget(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ritualtime = GetRitualTime()
    local timeleft = GetTaskRemaining(inst.shrouden_summon_task)
    local charlienpc = inst.components.entitytracker:GetEntity("charlienpc")
    local players = FindPlayersInRange(x, y, z, ATRIUM_ARENA_SIZE + 5, true)
    local targetchoices = {}
    for i, v in ipairs(players) do
        targetchoices[v] = inst.shrouden_target:value() == v and 0 or Remap(easing.linear(1 / (ritualtime/timeleft), 1, -1, 1), 0, 1, 1, 0)
    end
    if charlienpc then
        targetchoices[charlienpc] = (timeleft > 1 and inst.shrouden_target:value() == charlienpc and 0) or .8
    end

    local target = weighted_random_choice(targetchoices)

    inst:SetShroudenTarget(target)
    inst.shrouden_target_task = inst:DoTaskInTime(easing.linear(1 / (ritualtime/timeleft), .5, 1.5, 1), UpdateShroudenTarget)
end

local function DoShroudenSummon(inst)
    inst:SetRitualState(RITUAL_STATES.SUMMONED)
    inst.shrouden_summon_task = nil
end

---

-- keep in sync with charliecutscene.lua
local RITUAL_MARKING_THETA_STEP = 1 / NUM_RITUAL_MARKINGS
local MARKING_RANGE = 725 / 150

local function TryToSpawnCharlieNPC(inst)
    if inst.components.entitytracker:GetEntity("charlienpc") or TheWorld.components.charlie_tracker:IsCharlieDefeated() then
        return nil
    end

    local charlienpc = SpawnPrefab("charlie_npc")
    inst.components.entitytracker:TrackEntity("charlienpc", charlienpc)
end

local function ritualstate_SpawnCharlieNPC(inst, summoning)
    local newspawn = inst.components.entitytracker:GetEntity("charlienpc") == nil
    TryToSpawnCharlieNPC(inst)
    local charlienpc = inst.components.entitytracker:GetEntity("charlienpc")
    if charlienpc then
        charlienpc.scene2 = true
        if newspawn then
            charlienpc.Transform:SetPosition(inst.components.charliecutscene:FindCharlieRitualSpawnPoint():Get())
            charlienpc:ForceFacePoint(inst.Transform:GetWorldPosition())
            charlienpc:PushEventImmediate("spawn")
            charlienpc:EnableCameraFocus(true)
        end
        if not POPULATING then
            if summoning then
                charlienpc.components.npc_talker:ResetQueue()
                charlienpc.components.talker:ShutUp()
                charlienpc.sg.mem.skipdonetalking = true
                charlienpc.components.npc_talker:Chatter("CHARLIE_NPC_RITUAL_BEGUN")
                charlienpc.SoundEmitter:KillSound("loop")
            else
                charlienpc.components.npc_talker:ResetQueue()
                charlienpc.components.talker:ShutUp()
                charlienpc.sg.mem.skipdonetalking = true
                charlienpc.components.npc_talker:Chatter("CHARLIE_NPC_SHROUDEN_TAKES_HOST")
                charlienpc.components.npc_talker:DoNextLine()
                charlienpc.SoundEmitter:KillSound("loop")
                charlienpc:PushEventImmediate("transform", { gate = inst })
            end
        end
    end
end

local function ritualstate_StartShroudenAmbience(inst)
    if not inst.SoundEmitter:PlayingSound("shrouden_amb") then
        inst.SoundEmitter:PlaySound("rifts8/shrouden_portal/ambient_LP", "shrouden_amb")
    end
end

local function ritualstate_StopShroudenAmbience(inst)
    inst.SoundEmitter:KillSound("shrouden_amb")
end

local function ritualstate_OnSummoned(inst, state)
    inst.SoundEmitter:PlaySound("rifts8/shrouden_portal/tentacle_appear")
    ritualstate_StartShroudenAmbience(inst)
    ritualstate_SpawnCharlieNPC(inst, false)
    SetCameraFocus(inst, 1)
    EnablePickable(inst, false)
    inst:SetShroudenTarget(inst.components.entitytracker:GetEntity("charlienpc"))

    TheWorld:PushEvent("ms_charliearena_morphatrium",
    {
        cb = function()
            SpawnShroudenLootSetPiece(inst) -- we actually spawn the loot before boss is defeated
            inst.components.entitytracker:ForgetEntity("charlienpc") -- so we don't hit debug print in component
            SetCameraFocus(inst, 0)
            DestroyVaultKey(inst)
            EnablePickable(inst, true)
            inst:SetRitualState(RITUAL_STATES.ENABLED) -- cycle back
        end,
    })
end

local function ritualstate_OnSummoning(inst, state)
    inst.SoundEmitter:PlaySound("rifts8/shrouden_portal/eye_appear")
    ritualstate_StartShroudenAmbience(inst)

    ritualstate_SpawnCharlieNPC(inst, true)
    SetCameraFocus(inst, 1)
    EnablePickable(inst, false)
    for i = 1, NUM_RITUAL_MARKINGS do
        local marking = inst.components.entitytracker:GetEntity("ritualmarking"..tostring(i))
        if marking then
            marking:ConsumeRitualItem()
        end
    end

    -- 72 frames for the eye to appear
    local ritualtime = GetRitualTime()
    inst.shrouden_target_task = inst:DoTaskInTime(3, UpdateShroudenTarget)
    inst.shrouden_summon_task = inst:DoPeriodicTask(ritualtime, DoShroudenSummon)
end

local function ritualstate_OnEnabled(inst, state)
    ritualstate_StopShroudenAmbience(inst)
    if state == RITUAL_STATES.ACTIVE then
        EnablePickable(inst, false)
        inst.SoundEmitter:PlaySound("rifts8/charlie_ritual/summon")
        for i = 1, NUM_RITUAL_MARKINGS do
            local marking = inst.components.entitytracker:GetEntity("ritualmarking"..tostring(i))
            if marking then
                marking:ConsumeRitualItem()
            end
        end
        inst:DoTaskInTime(0.7, inst.SetRitualState, RITUAL_STATES.SUMMONING)
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local theta = (inst.components.charliecutscene:FindRitualAngle() * DEGREES) -- charliecutscene has data on atrium pillar positions so using that component
    for i = 1, NUM_RITUAL_MARKINGS do
        local marking = inst.components.entitytracker:GetEntity("ritualmarking"..tostring(i))
        if marking == nil then
            marking = SpawnPrefab("atrium_ritual_marking")
            marking.Transform:SetPosition(x + math.cos(theta) * MARKING_RANGE, 0, z - math.sin(theta) * MARKING_RANGE)
            marking.Transform:SetRotation(math.random() * 360)
            marking:Enable(true)
            inst.components.entitytracker:TrackEntity("ritualmarking"..tostring(i), marking)

            if not POPULATING then
                marking:PushEvent("onbuilt")
            end
        end

        marking.gate = inst

        if not marking.atriumlistening then
            marking.atriumlistening = true
            inst:ListenForEvent("updateselectedritualitem", inst._updateritualitemstate, marking)
        end

        theta = theta + (RITUAL_MARKING_THETA_STEP * TWOPI)
    end
end

local function ritualstate_OnDisabled(inst) -- this won't be used probably, but it's supported
    for i = 1, NUM_RITUAL_MARKINGS do
        local marking = inst.components.entitytracker:GetEntity("ritualmarking"..tostring(i))
        if marking then
            marking:Remove()
        end
    end
end

local function SetRitualState(inst, state)
    if inst.ritual_state:value() ~= state then
        inst.ritual_state:set(state)
        inst.components.charliecutscene:FindAndSetCameraSceneAngle()

        if inst.shrouden_target_task then
            inst.shrouden_target_task:Cancel()
            inst.shrouden_target_task = nil
        end
        if inst.morph_room_task then
            inst.morph_room_task:Cancel()
            inst.morph_room_task = nil
        end

        TheWorld:PushEvent("ms_atriumgate_ritualstatechanged", inst)

        if state >= RITUAL_STATES.SUMMONED then
            ritualstate_OnSummoned(inst, state)
        elseif state >= RITUAL_STATES.SUMMONING then
            ritualstate_OnSummoning(inst, state)
        elseif state >= RITUAL_STATES.ENABLED then
            ritualstate_OnEnabled(inst, state)
        else
            ritualstate_OnDisabled(inst)
        end
    end
end

local function GetRitualState(inst)
    return inst.ritual_state:value()
end

local function EnableRitual(inst, enable)
    inst:SetRitualState(enable and RITUAL_STATES.ENABLED or RITUAL_STATES.DISABLED)
end

--------------------------------------------------------------------------

local function SetShroudenTarget(inst, target)
    if target ~= inst.shrouden_target:value() then
        inst.shrouden_target:set(target)

        inst.SoundEmitter:PlaySound("rifts8/shrouden_portal/eye_movement")
    end
end

--------------------------------------------------------------------------

local TERRAFORM_BLOCKER_RADIUS = math.ceil(ATRIUM_ARENA_SIZE / 3)

local function CreateTerraformBlocker(parent)
    local inst = CreateEntity()

    inst:AddTag("FX")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()

    inst:SetTerraformExtraSpacing(TERRAFORM_BLOCKER_RADIUS + 0.01)

    return inst
end

local function AddTerraformBlockers(inst) -- NOTES(JBK): Keep in sync with charlie_boss_trial. [ARTBES]
    local diameter = 2 * TERRAFORM_BLOCKER_RADIUS
    local rowoffset = 3 * TERRAFORM_BLOCKER_RADIUS
    for row = -rowoffset, rowoffset, diameter do
        for col = -diameter, diameter, diameter do
            local blocker = CreateTerraformBlocker(inst)
            blocker.entity:SetParent(inst.entity)
            blocker.Transform:SetPosition(row, 0, col)

            blocker = CreateTerraformBlocker(inst)
            blocker.entity:SetParent(inst.entity)
            blocker.Transform:SetPosition(col, 0, row)
        end
    end
end

--------------------------------------------------------------------------

local function floor_SetRitualState(inst, ritual_state)
    inst.AnimState:PlayAnimation(ritual_state >= RITUAL_STATES.ACTIVE and "idle_active_on" or "idle_active")
end

local function CreateFloor()
    local inst = CreateEntity()

    inst:AddTag("DECOR")
    inst:AddTag("NOCLICK")
    --[[Non-networked entity]]
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("atrium_floor")
    inst.AnimState:SetBuild("atrium_floor")
    inst.AnimState:PlayAnimation("idle_active")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(-3)

    inst.SetRitualState = floor_SetRitualState

    return inst
end

local function ritual_OnParentWake(inst)
    local parent = inst.entity:GetParent()
    local ritual_state = parent and parent.ritual_state:value()
    if ritual_state then
        inst.AnimState:PlayAnimation(ritual_state >= RITUAL_STATES.ACTIVE and "path_active" or "path", true)
    end

    -- end tween
    inst:RemoveComponent("colourtweener")
    inst.AnimState:SetMultColour(1, 1, 1, 1)
    if inst.tween_task then
        inst.tween_task:Cancel()
        inst.tween_task = nil
    end
end

local function ritual_SetRitualState(inst, ritual_state)
    if ritual_state >= RITUAL_STATES.ACTIVE then
        inst.AnimState:PlayAnimation("path_active")
    elseif not inst.AnimState:IsCurrentAnimation("path_appear") then
        inst.AnimState:PlayAnimation("path", true)
    end
end

local REVERT_COLOUR_TIME = 1.4
local function ritual_OnFinishColourTweening(inst)
    inst:RemoveComponent("colourtweener")
end

local function ritual_TweenToNormalColour(inst)
    inst.components.colourtweener:StartTween({1, 1, 1, 1}, REVERT_COLOUR_TIME, ritual_OnFinishColourTweening)
end

local function ritual_RevertToNormalColour(inst)
    inst.tween_task = inst:DoTaskInTime(0.4, ritual_TweenToNormalColour)
end

local function CreateRitualFloor(parent)
    local inst = CreateEntity()

    inst:AddTag("DECOR")
    inst:AddTag("NOCLICK")
    --[[Non-networked entity]]
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("atrium_ritual")
    inst.AnimState:SetBuild("atrium_ritual")
    if parent:GetTimeAlive() >= 1 then -- FIXME bad hack this is so we don't play appear or colour tween again on room transition : (
        inst.AnimState:PlayAnimation("path_appear")
        inst.AnimState:PushAnimation("path", true)
    else
        inst.AnimState:PlayAnimation("path", true)
    end
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(-3)
    inst.AnimState:SetFinalOffset(1)

    if parent:GetTimeAlive() >= 1 then -- FIXME bad hack this is so we don't play appear or colour tween again on room transition : (
        inst:AddComponent("colourtweener")
        inst.components.colourtweener:StartTween({0, 0, 0, 1}, 2 * FRAMES, ritual_RevertToNormalColour)
    end

    inst.OnParentWake = ritual_OnParentWake
    inst.SetRitualState = ritual_SetRitualState

    return inst
end

local function OnPreLoad(inst, data)
    WorldSettings_Timer_PreLoad(inst, data, "destabilizing", TUNING.ATRIUM_GATE_DESTABILIZE_TIME)
    WorldSettings_Timer_PreLoad_Fix(inst, data, "destabilizing", 1)
    WorldSettings_Timer_PreLoad(inst, data, "destabilizedelay", TUNING.ATRIUM_GATE_DESTABILIZE_DELAY)
    WorldSettings_Timer_PreLoad_Fix(inst, data, "destabilizedelay", 1)
    WorldSettings_Timer_PreLoad(inst, data, "cooldown", TUNING.ATRIUM_GATE_COOLDOWN)
    WorldSettings_Timer_PreLoad_Fix(inst, data, "cooldown", 1)
end

--------------------------------------------------------------------------

local function GetPupilDeltaTime(inst)
	local current_time = GetStaticTime()
	local dt = current_time - inst.t
	inst.t = current_time
	return dt
end

local PUPIL_POS_UPDATE_RATE = 5
local function UpdateShroudenPupil(inst)
    local dt = GetPupilDeltaTime(inst)
    local parent = inst.entity:GetParent()
    local target = parent.shrouden_target:value()
    if not inst.entity:IsVisible() then
        return
    end

    local offx, offy = 0, 0 -- original position if no target
    if target then
        local x, y, z = target.Transform:GetWorldPosition()
        y = y + (target.prefab == "charlie_npc" and 2.5 or 1)

        local psx, psy = TheSim:GetScreenPos(x, y, z)
        x, y, z = parent.Transform:GetWorldPosition()
        local sx, sy = TheSim:GetScreenPos(x, y + 4, z)
        local theta = math.atan2(sy - psy, psx - sx)
        local w, h = 70, 70
        local dist = math.sqrt(distsq(psx, psy, sx, sy))

        offx = math.cos(theta) * math.min(dist, w)
        offy = math.sin(theta) * math.min(dist, h)
    end

    local k = math.min(1, dt * PUPIL_POS_UPDATE_RATE)
    local mult = 1 - k
    inst.targetpos.x = offx * k + inst.targetpos.x * mult
    inst.targetpos.y = offy * k + inst.targetpos.y * mult

    inst.Follower:SetOffset(inst.targetpos.x, inst.targetpos.y, 0)
end

local function shrouden_OnParentWake(inst)
    inst.AnimState:PlayAnimation(inst.anim, true)
    if inst.SyncEyeParts then
        inst:SyncEyeParts()
    end
end

local function shrouden_SetRitualState(inst, state)
    if inst.anim == "tentacles_idle" then
        if state == RITUAL_STATES.SUMMONED then
            inst:Show()
            inst.AnimState:PlayAnimation(inst.appearanim)
            inst.AnimState:PushAnimation(inst.queueanim)
            inst.AnimState:PushAnimation(inst.anim, true)
        else
            inst:Hide()
        end
    end
end

local function SyncEyeParts(inst)
    local parent = inst.entity:GetParent()
    local isappearing = inst.AnimState:IsCurrentAnimation("eye_appear")
    local idleframe = inst.AnimState:IsCurrentAnimation("eye_idle") and inst.AnimState:GetCurrentAnimationFrame()
    if not parent or not parent.shrouden_parts then
        return
    end

    for i, v in ipairs(parent.shrouden_parts) do
        if v.synctoeye then
            if isappearing then
                v:Hide()
            else
                v:Show()
            end
            if idleframe then
                v.AnimState:SetFrame(idleframe)
            end
        end
    end
end

local function AddShroudenFollowSymbol(inst, sym, anim, appearanim, synctoeye, queueanim)
	local fx = CreateEntity()

	fx:AddTag("FX")
	--[[Non-networked entity]]
	--fx.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBank("atrium_gate_shrouden")
	fx.AnimState:SetBuild("atrium_gate_shrouden")
    fx.AnimState:SetSymbolLightOverride("red_parts", 1)
    if appearanim then
        fx.AnimState:PlayAnimation(appearanim)
        if queueanim then
            fx.AnimState:PushAnimation(queueanim)
            fx.AnimState:PushAnimation(anim, true)
        else
            fx.AnimState:PushAnimation(anim, true)
        end
        fx.OnParentWake = shrouden_OnParentWake
    else
	    fx.AnimState:PlayAnimation(anim, true)
    end

    fx.anim = anim
    fx.appearanim = appearanim
    fx.queueanim = queueanim
    fx.synctoeye = synctoeye

	fx.entity:SetParent(inst.entity)
	fx.Follower:FollowSymbol(inst.GUID, sym, 0, 0, 0)

    fx.SetRitualState = shrouden_SetRitualState

    if anim == "pupil" then
        fx.t = GetTime()
        fx.targetpos = { x = 0, y = 0 }
        fx:AddComponent("updatelooper")
        fx.components.updatelooper:AddPostUpdateFn(UpdateShroudenPupil)
        fx:Hide()
    elseif anim == "eye_idle" then
        fx:ListenForEvent("animover", SyncEyeParts)
        fx.SyncEyeParts = SyncEyeParts
    end

	return fx
end

local function ConfigureShroudenFX(inst)
    if inst.shrouden_parts then
        return
    end
    inst.shrouden_parts =
    {
        AddShroudenFollowSymbol(inst, "swap_shrouden", "tentacles_idle", "tentacles_appear", nil, "tentacles_grow"),
        AddShroudenFollowSymbol(inst, "swap_shrouden", "eye_idle", "eye_appear"),
        AddShroudenFollowSymbol(inst, "swap_shrouden", "pupil", nil, true),
        AddShroudenFollowSymbol(inst, "swap_shrouden", "eye_shading_idle", nil, true),
        AddShroudenFollowSymbol(inst, "swap_shrouden", "eye_lids_idle", nil, true),
        -- adding another symbol will escape the final offset range, careful
    }
    for i, v in ipairs(inst.shrouden_parts) do
        v.AnimState:SetFinalOffset(i - 2) -- -1 to 3 [final offset]
        table.insert(inst.highlightchildren, v)
        if v.SyncEyeParts then
            v:SyncEyeParts()
        end
    end
end

--------------------------------------------------------------------------

local RITUAL_ROT_OFFSET = 360 / 6
local function OnRitualStateDirty(inst)
    local ritual_state = inst.ritual_state:value()
    inst.atrium_floor:SetRitualState(ritual_state)
    if ritual_state >= RITUAL_STATES.ENABLED then
        if ritual_state == RITUAL_STATES.SUMMONED then
            ConfigureShroudenFX(inst)
            for i, v in ipairs(inst.shrouden_parts) do
                v:SetRitualState(ritual_state)
            end
        elseif ritual_state == RITUAL_STATES.SUMMONING then
            ConfigureShroudenFX(inst)
            for i, v in ipairs(inst.shrouden_parts) do
                v:SetRitualState(ritual_state)
            end
        end
        if inst.ritual_circle == nil then
            inst.ritual_circle = CreateRitualFloor(inst)
            inst.ritual_circle.entity:SetParent(inst.entity)
        end
        inst.ritual_circle:SetRitualState(ritual_state)
        -- using charliecutscene camera angle info to set the ritual circle the right rotation
        local angle = inst.components.charliecutscene:ClientGetCameraAngle()
        inst.ritual_circle.Transform:SetRotation(225-angle+RITUAL_ROT_OFFSET)
    elseif inst.ritual_circle then
        inst.ritual_circle:Remove()
        inst.ritual_circle = nil
    end
end

local function IsRitualSummoning(inst) -- summoning shrouden
    return inst.ritual_state:value() == RITUAL_STATES.SUMMONING
end

local function notdedi_OnEntityWake(inst)
    if inst.ritual_circle then
        inst.ritual_circle:OnParentWake()
    end
    if inst.shrouden_parts then
        for i, v in ipairs(inst.shrouden_parts) do
            if v.OnParentWake then
                v:OnParentWake()
            end
        end
    end
    inst:RemoveEventCallback("entitywake", notdedi_OnEntityWake)
end

--------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 1)

    inst.Light:Enable(false)
    inst.Light:SetRadius(8.0)
    inst.Light:SetFalloff(.9)
    inst.Light:SetIntensity(0.65)
    inst.Light:SetColour(200 / 255, 140 / 255, 140 / 255)

    inst.AnimState:SetBank("atrium_gate")
    inst.AnimState:SetBuild("atrium_gate")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetSymbolLightOverride("dreadstone_patch_red", 1)
    inst.AnimState:Hide("KEY")
    inst.AnimState:SetFinalOffset(-2)

    inst.MiniMapEntity:SetIcon("atrium_gate.png")

    inst:AddTag("gemsocket") -- for "Socket" action string
    inst:AddTag("stargate")
    inst:AddTag("give_dolongaction")

    inst._camerafocus = net_tinybyte(inst.GUID, "atrium_gate._camerafocus", "camerafocusdirty")
    inst._camerafocustask = nil
    inst.ritual_state = net_tinybyte(inst.GUID, "atrium_gate.ritual_state", "ritualstatedirty")
    inst.shrouden_target = net_entity(inst.GUID, "atrium_gate.shrouden_target") -- the entity the pupil is focusing on

    inst.scrapbook_specialinfo = "atriumgate"

    --Dedicated server does not need to spawn the flooring
    if not TheNet:IsDedicated() then
        inst.atrium_floor = CreateFloor()
        inst.atrium_floor.entity:SetParent(inst.entity)

        inst:ListenForEvent("ritualstatedirty", OnRitualStateDirty)
        inst:ListenForEvent("entitywake", notdedi_OnEntityWake)

        inst:AddComponent("pointofinterest")
        inst.components.pointofinterest:SetHeight(20)
    end

	inst.scrapbook_speechstatus = "OFF"

    --Dedicated servers need this too
    AddTerraformBlockers(inst)

    inst:DoTaskInTime(0, InitializePathFinding)
    inst.OnRemoveEntity = OnRemove

    inst.highlightchildren = {}

    -- Server and Client component.
    inst:AddComponent("charliecutscene")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("camerafocusdirty", OnCameraFocusDirty)

        return inst
    end

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("pickable")
    inst.components.pickable.caninteractwith = false
    inst.components.pickable.onpickedfn = OnKeyTaken

    inst:AddComponent("trader")
    inst.components.trader:SetAbleToAcceptTest(ItemTradeTest)
    inst.components.trader.deleteitemonaccept = true
    inst.components.trader.onaccept = OnKeyGiven
    inst.OnKeyGiven = OnKeyGiven -- for charliecutscene

    inst:AddComponent("worldsettingstimer")
    inst.components.worldsettingstimer:AddTimer("destabilizing", TUNING.ATRIUM_GATE_DESTABILIZE_TIME, true)
    inst.components.worldsettingstimer:AddTimer("destabilizedelay", TUNING.ATRIUM_GATE_DESTABILIZE_DELAY, true)
    inst.components.worldsettingstimer:AddTimer("cooldown", TUNING.ATRIUM_GATE_COOLDOWN, true)
    inst:ListenForEvent("timerdone", ontimer)

    inst:AddComponent("entitytracker")
    inst:AddComponent("colourtweener")

    local playerprox = inst:AddComponent("playerprox")
	playerprox:SetTargetMode(playerprox.TargetModes.AllPlayers)
    playerprox:SetOnPlayerNear(OnPlayerNear)
    playerprox:SetOnPlayerFar(OnPlayerFar)
    playerprox:SetDist(ATRIUM_ARENA_SIZE, KEYSTONE_RADIUS)

    MakeHauntableWork(inst)
    MakeRoseTarget_CreateFuel_IncreasedHorror(inst)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnLoadPostPass = OnLoadPostPass
    inst.OnPreLoad = OnPreLoad

    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake

    inst.TrackStalker = TrackStalker
    inst.IsWaitingForStalker = IsWaitingForStalker

    inst.IsDestabilizing = IsDestabilizing
    inst.Destabilize = Destabilize
    inst.StartCooldown = StartCooldown
    inst.ForceDestabilizeExplode = ForceDestabilizeExplode

    inst.SocketVaultKey = SocketVaultKey
    inst.DestroyVaultKey = DestroyVaultKey
    inst.IsVaultKeySocketed = IsVaultKeySocketed
    inst.vault_key_socketed = nil

    inst.EnableRitual = EnableRitual
    inst.GetRitualState = GetRitualState
    inst.SetRitualState = SetRitualState
    inst.IsRitualSummoning = IsRitualSummoning

    inst.SetShroudenTarget = SetShroudenTarget

    inst.IsObjectInAtriumArena = IsObjectInAtriumArena

    inst.RITUAL_STATES = RITUAL_STATES

    inst._onremovestalker = function(stalker)
        local current = inst.components.entitytracker:GetEntity("stalker")
        if current == nil or current == stalker then
            --redundant check in case we're actually tracking another stalker
            --this event should only be reachable by shenanigans in any case
            Destabilize(inst, true)
        end
    end
    inst._onstalkerdeath = function(stalker)
        inst:RemoveEventCallback("onremove", inst._onremovestalker, stalker)
        inst:RemoveEventCallback("death", inst._onstalkerdeath, stalker)
        if inst.components.entitytracker:GetEntity("stalker") == stalker then
            inst.components.entitytracker:ForgetEntity("stalker")
            --IsAtriumDecay means "killed" to reset the fight (off-screen, or moved too far away from gate)
            Destabilize(inst, stalker:IsAtriumDecay())

            if not stalker:IsAtriumDecay()
                and not inst.components.entitytracker:GetEntity("charlie_hand")
            then
                if TUNING.SPAWN_RIFTS == 1
                    and TheWorld.components.riftspawner ~= nil and
                    not TheWorld.components.riftspawner:GetShadowRiftsEnabled() then
                    inst.components.charliecutscene:SpawnCharlieHand()
                end
            end
        end
    end
    inst._updateritualitemstate = function()
        if inst:IsRitualSummoning() or (inst:GetRitualState() == RITUAL_STATES.ACTIVE) then
            return
        end

        if inst.activate_ritual_task then
            inst.activate_ritual_task:Cancel()
            inst.activate_ritual_task = nil
        end
        local ritualitems = {} -- [prefab] = true

        for i = 1, NUM_RITUAL_MARKINGS do
            local marking = inst.components.entitytracker:GetEntity("ritualmarking"..tostring(i))
            if marking and marking.item then
                if ritualitems[marking.item.prefab] then
                    inst:SetRitualState(RITUAL_STATES.ENABLED)
                    return
                end
                ritualitems[marking.item.prefab] = true
            else
                inst:SetRitualState(RITUAL_STATES.ENABLED)
                return
            end
        end

        -- defer to allow for last ritual piece to rise visually
        inst.SoundEmitter:PlaySound("rifts8/charlie_ritual/summon_begin")
        inst.activate_ritual_task = inst:DoTaskInTime(0.5, inst.SetRitualState, RITUAL_STATES.ACTIVE)
    end

    return inst
end

return Prefab("atrium_gate", fn, assets, prefabs)
