local assets =
{
    Asset("ANIM", "anim/cave_vent.zip"),
    Asset("ANIM", "anim/cave_vent_fx.zip"),
    Asset("MINIMAP_IMAGE", "cave_vent_rock"),
}

local prefabs =
{
    "rocks",
    "rock_break_fx",
    "redgem",
    "bluegem",
    --"sporebomb_projectile",
    "miasma_cloud",
    "cave_vent_ground_fx",
}

local VENT_TYPES = {
    NONE    = 0,
    COLD    = 1,
    HOT     = 2,
    GAS     = 3,
    MIASMA  = 4,
}

local VENT_DATA = {
    [VENT_TYPES.HOT] = {
        spew_time_base = TUNING.CAVE_VENTS.SPEW_TIME.HOT.BASE,
        spew_time_variance = TUNING.CAVE_VENTS.SPEW_TIME.HOT.VARIANCE,
    },
    [VENT_TYPES.MIASMA] = {
        spew_time_base = TUNING.CAVE_VENTS.SPEW_TIME.MIASMA.BASE,
        spew_time_variance = TUNING.CAVE_VENTS.SPEW_TIME.MIASMA.VARIANCE,
    },
    [VENT_TYPES.GAS] = {
        spew_time_base = TUNING.CAVE_VENTS.SPEW_TIME.GAS.BASE,
        spew_time_variance = TUNING.CAVE_VENTS.SPEW_TIME.GAS.VARIANCE,
    },
}

local function GetVentType(inst)
    local riftspawner, toadstoolspawner = TheWorld.components.riftspawner, TheWorld.components.toadstoolspawner
    if riftspawner and riftspawner:IsShadowPortalActive() then
        return VENT_TYPES.MIASMA
    --elseif toadstoolspawner and toadstoolspawner:IsEmittingGas() then
    --    return VENT_TYPES.GAS
    else
        return VENT_TYPES.HOT
    end
end

SetSharedLootTable( 'cave_vent_rock',
{
    {'rocks',       1.00},
    {'rocks',       1.00},
    {'rocks',       1.00},
    {'bluegem',     0.05},
    {'redgem',      0.05},
})

SetSharedLootTable( 'cave_vent_rock_med',
{
    {'rocks',       1.00},
    {'rocks',       1.00},
})

SetSharedLootTable( 'cave_vent_rock_low',
{
    {'rocks',       1.00},
})

----------------------------

local function StopVentingGas(inst)
    if inst._gasdowntask ~= nil then
        inst._gasdowntask:Cancel()
        inst._gasdowntask = nil
    end
end

local function StartVentingGas(inst)
    if inst._gaslevel > 1 then
        inst._gaslevel = inst._gaslevel - 1
    else
        inst._gaslevel = 0
        StopVentingGas(inst)
    end
end

local function StartVentingGas(inst)
    if inst._gaslevel > 0 and inst._gasdowntask == nil then
        inst._gasdowntask = inst:DoPeriodicTask(TUNING.SEG_TIME, StopVentingGas, TUNING.SEG_TIME * (.5 + math.random() * .5))
    end
end

local function TestGasLevel(inst, gaslevel)
    --Trigger with increasing chance from level 50 -> 100
    if gaslevel > 50 and math.random() * 50 < gaslevel - 50 then
        StartVentingGas(inst)
    end
end

local function OnBuildupGas(inst)
    if TheWorld.components.toadstoolspawner:IsEmittingGas() then
        inst._gaslevel = inst._gaslevel + 1
        TestGasLevel(inst, inst._gaslevel)
    elseif inst._gaslevel > 0 then
        inst._gaslevel = math.max(0, inst._gaslevel - 1)
    end
end

local function StopBuildingupGas(inst)
    if inst._gasuptask ~= nil then
        inst._gasuptask:Cancel()
        inst._gasuptask = nil

        StartVentingGas(inst)
    end
end

local function StartBuildingupGas(inst)
    if inst._gasuptask == nil then
        inst._gasuptask = inst:DoPeriodicTask(TUNING.SEG_TIME, OnBuildupGas, TUNING.SEG_TIME * (.5 + math.random() * .5))

        StopVentingGas(inst)
    end
end

-------------------------

local function GetWorkState(inst)
    local workable = inst.components.workable
    return (workable.workleft <= TUNING.CAVE_VENTS.MINE / 3 and "low") or
        (workable.workleft <= TUNING.CAVE_VENTS.MINE * 2 / 3 and "med") or
        "full"
end

local function SetStatePhysicsRadius(inst)
    local state = GetWorkState(inst)
    if state == "med" then
        inst.Physics:SetCapsule(0.5, 2)
    elseif state == "low" then
        inst.Physics:SetCapsule(0.25, 2)
    end
end

local function Work_OnLoad(inst)
    inst.AnimState:PlayAnimation(GetWorkState(inst))
    SetStatePhysicsRadius(inst)
end

local function GetSpewTime(inst)
    local data = VENT_DATA[inst.ventilation_type]
    return GetRandomWithVariance(data.spew_time_base, data.spew_time_variance)
end

local STATES_TO_SOUNDS = {
    ["low"] = "rifts6/creatures/rockspider/spew_1_mite",
    ["med"] = "rifts6/fissure/spew_2",
    ["full"] = "rifts6/fissure/spew_3",
}

local function PlaySpewAnimation(inst)
    if not inst:IsAsleep() then
        local state = GetWorkState(inst)
        inst.AnimState:PlayAnimation(state.."_geyser")
        inst.AnimState:PushAnimation(state)
        inst.SoundEmitter:PlaySound(STATES_TO_SOUNDS[state])
    end
end

local TIMER_NAMES = {
    SPEW_MIASMA = "spew_miasma",
    SPEW_GAS = "spew_gas",
    SPEW_HOT = "spew_hot_air",
}

local function SpewMiasma(inst)
    local miasmamanager = TheWorld.components.miasmamanager
    local x, y, z = inst.Transform:GetWorldPosition()
    local theta = math.random() * TWOPI
    local ox, oz = TILE_SCALE * math.cos(theta), TILE_SCALE * math.sin(theta)
    miasmamanager:CreateMiasmaAtPoint(x + ox, 0, z + oz)

    --MiasmaAction_Enhance
    PlaySpewAnimation(inst)
    inst.components.timer:StartTimer(TIMER_NAMES.SPEW_MIASMA, GetSpewTime(inst))
end

local function SpewHotSteam(inst)
    PlaySpewAnimation(inst)
    inst.components.timer:StartTimer(TIMER_NAMES.SPEW_HOT, GetSpewTime(inst))
end

local vent_type_fns = {
    [VENT_TYPES.NONE] = {},
    [VENT_TYPES.HOT] = {
        on_start_venting = function(inst, populating)
            if not populating then
                PlaySpewAnimation(inst)
            end

            if not inst.components.timer:TimerExists(TIMER_NAMES.SPEW_HOT) then
                inst.components.timer:StartTimer(TIMER_NAMES.SPEW_HOT, GetSpewTime(inst))
            end
        end,
        on_stop_venting = function(inst)
            inst.components.timer:StopTimer(TIMER_NAMES.SPEW_HOT)
        end,
    },
    [VENT_TYPES.MIASMA] = {
        on_start_venting = function(inst, populating)
            inst.AnimState:ShowSymbol("red_vents")
            inst:AddTag("miasma_venter")

            local miasmamanager = TheWorld.components.miasmamanager
            if miasmamanager and not populating then
                local x, y, z = inst.Transform:GetWorldPosition()

                miasmamanager:CreateMiasmaAtPoint(x - TILE_SCALE, 0, z - TILE_SCALE)
                miasmamanager:CreateMiasmaAtPoint(x, 0, z - TILE_SCALE)
                miasmamanager:CreateMiasmaAtPoint(x + TILE_SCALE, 0, z - TILE_SCALE)
                miasmamanager:CreateMiasmaAtPoint(x - TILE_SCALE, 0, z)
                miasmamanager:CreateMiasmaAtPoint(x + TILE_SCALE, 0, z)
                miasmamanager:CreateMiasmaAtPoint(x - TILE_SCALE, 0, z + TILE_SCALE)
                miasmamanager:CreateMiasmaAtPoint(x, 0, z + TILE_SCALE)
                miasmamanager:CreateMiasmaAtPoint(x + TILE_SCALE, 0, z + TILE_SCALE)

                PlaySpewAnimation(inst)
            end

            if not inst.components.timer:TimerExists(TIMER_NAMES.SPEW_MIASMA) then
                inst.components.timer:StartTimer(TIMER_NAMES.SPEW_MIASMA, GetSpewTime(inst))
            end
        end,
        on_stop_venting = function(inst)
            inst.AnimState:HideSymbol("red_vents")
            inst:RemoveTag("miasma_venter")
            inst.components.timer:StopTimer(TIMER_NAMES.SPEW_MIASMA)
        end,
    },

    [VENT_TYPES.COLD] = {},
    [VENT_TYPES.GAS] = {},
}

local function OnWorkCallback(inst, worker, workleft)
    if workleft <= 0 then
        local pos = inst:GetPosition()
        SpawnPrefab("rock_break_fx").Transform:SetPosition(pos:Get())
        inst.components.lootdropper:DropLoot(pos)
        inst:Remove()
    else
        inst.AnimState:PlayAnimation(GetWorkState(inst))
        SetStatePhysicsRadius(inst)
    end
end

local function UpdateVentilation(inst, is_populating, vent_type)
    local old_vent_type = inst.ventilation_type
    inst.ventilation_type = vent_type or GetVentType(inst)

    -- Our vent type changed, do changes
    if (old_vent_type ~= inst.ventilation_type) or is_populating then
        if old_vent_type and vent_type_fns[old_vent_type].on_stop_venting then
            vent_type_fns[old_vent_type].on_stop_venting(inst)
        end

        if vent_type_fns[inst.ventilation_type].on_start_venting then
            vent_type_fns[inst.ventilation_type].on_start_venting(inst, is_populating)
        end
    end
end

local function OnTimerDone(inst, data)
    if data.name == TIMER_NAMES.SPEW_MIASMA then
        SpewMiasma(inst)
    elseif data.name == TIMER_NAMES.SPEW_GAS then
        --SpewToadstoolGas(inst)
    elseif data.name == TIMER_NAMES.SPEW_HOT then
        SpewHotSteam(inst)
    end
end

local function GetHeat(inst)
	if inst.ventilation_type == VENT_TYPES.HOT then
		inst.components.heater:SetThermics(true, false)
		return TUNING.CAVE_VENTS.HEAT.HOT_ACTIVE
    elseif inst.ventilation_type == VENT_TYPES.MIASMA then
        inst.components.heater:SetThermics(true, false)
        return TUNING.CAVE_VENTS.HEAT.MIASMA_ACTIVE
    elseif inst.ventilation_type == VENT_TYPES.COLD then
        inst.components.heater:SetThermics(false, true)
		return TUNING.CAVE_VENTS.HEAT.COLD_ACTIVE
	end
	inst.components.heater:SetThermics(false, false)
	return 0
end

local function GetStatus(inst)
    return inst.ventilation_type == VENT_TYPES.MIASMA   and "MIASMA"
        or inst.ventilation_type == VENT_TYPES.GAS      and "GAS"
        or inst.ventilation_type == VENT_TYPES.HOT      and "HOT"
        or inst.ventilation_type == VENT_TYPES.COLD     and "COLD"
        or nil
end

local function GetVentDebugName(inst)
    return GetStatus(inst)
end

local function OnSave(inst, data)
    data.ventilation_type = inst.ventilation_type

    if inst.set_loot_table then
        data.set_loot_table = inst.set_loot_table
    end
end

local function OnLoad(inst, data)
    if data then
        --No need to do initialization here, task in time will take care of it.
        inst.ventilation_type = data.ventilation_type or VENT_TYPES.NONE

        inst.set_loot_table = data.set_loot_table or nil --This is from world generation
        if inst.set_loot_table then
            inst.components.lootdropper:SetChanceLootTable(inst.set_loot_table)
        end
    end
end

local function ForceSpew(inst)
    for k, name in pairs(TIMER_NAMES) do
        inst.components.timer:SetTimeLeft(name, FRAMES)
    end
end

local function CustomOnHaunt(inst, haunter)
    if math.random() < TUNING.HAUNT_CHANCE_HALF then
        ForceSpew(inst)
        return true
    end
    return false
end

local function OnEntityWake(inst)
    for k, name in pairs(TIMER_NAMES) do
        inst.components.timer:ResumeTimer(name)
    end
end

local function OnEntitySleep(inst) --No need to have the spew timers ticking off screen, pause them to save on scheduler update
    for k, name in pairs(TIMER_NAMES) do
        inst.components.timer:PauseTimer(name)
    end
end

local function rock_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("cave_vent_rock.png")

    MakeObstaclePhysics(inst, 1)
    inst:SetPhysicsRadiusOverride(1)

    inst.AnimState:SetBank("cave_vent")
    inst.AnimState:SetBuild("cave_vent")
    inst.AnimState:PlayAnimation("full")
    inst.AnimState:HideSymbol("red_vents")
    inst.AnimState:SetSymbolLightOverride("red_vents", 1)
    inst.AnimState:AddOverrideBuild("cave_vent_fx")

    inst:SetPrefabNameOverride("cave_vent_rock")

    inst:AddTag("boulder")
    --HASHEATER (from heater component) added to pristine state for optimization
	inst:AddTag("HASHEATER")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim = "full"

    inst.ventilation_type = VENT_TYPES.NONE

    local color = 0.5 + math.random() * 0.5
    inst.AnimState:SetSymbolMultColour("vent_part", color, color, color, 1)

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable('cave_vent_rock')

    inst:AddComponent("heater")
    inst.components.heater:SetShouldFalloff(false)
    inst.components.heater.heatfn = GetHeat
    inst.components.heater.heatrate = 5

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.MINE)
    inst.components.workable:SetWorkLeft(TUNING.CAVE_VENTS.MINE)
    inst.components.workable:SetOnWorkCallback(OnWorkCallback)
    inst.components.workable:SetOnLoadFn(Work_OnLoad)
    inst.components.workable.savestate = true

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnTimerDone)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    inst.OnEntityWake = OnEntityWake
    inst.OnEntitySleep = OnEntitySleep

    inst.UpdateVentilation = UpdateVentilation
    inst.GetVentDebugName = GetVentDebugName
    inst.ForceSpew = ForceSpew

    local function UpdateVentilation_Bridge(_)
        UpdateVentilation(inst)
    end

    local riftspawner, toadstoolspawner = TheWorld.components.riftspawner, TheWorld.components.toadstoolspawner

    if riftspawner then
        inst:ListenForEvent("ms_riftaddedtopool", UpdateVentilation_Bridge, TheWorld)
	    inst:ListenForEvent("ms_riftremovedfrompool", UpdateVentilation_Bridge, TheWorld)
    end

    if toadstoolspawner then
        inst:ListenForEvent("toadstoolstatechanged", UpdateVentilation_Bridge, TheWorld)
        inst:ListenForEvent("toadstoolkilled", UpdateVentilation_Bridge, TheWorld)
    end

    inst:DoTaskInTime(0, UpdateVentilation, POPULATING)

    MakeHauntableWork(inst)
    AddHauntableCustomReaction(inst, CustomOnHaunt, false)

    return inst
end

return Prefab("cave_vent_rock", rock_fn, assets, prefabs)