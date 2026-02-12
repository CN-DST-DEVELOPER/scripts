require("worldsettingsutil")

local assets =
{
    Asset("ANIM", "anim/rabbit_hole.zip"),
}

local prefabs =
{
    "rabbit",
    "rabbitking_lucky",
}

local function OnIsCollapsedDirty(inst)
    if inst.iscollapsed:value() then
        inst.wet_prefix = STRINGS.WET_PREFIX.RABBITHOLE
        inst.always_wet_prefix = true
    else
        inst.wet_prefix = STRINGS.WET_PREFIX.GENERIC
        inst.always_wet_prefix = nil
    end
end

local function dig_up(inst)
    if inst.components.spawner:IsOccupied() then
        inst.components.lootdropper:SpawnLootPrefab("rabbit")
    end
    inst:Remove()
end

local function startspawning(inst)
    if inst.components.spawner ~= nil then
        inst.components.spawner:SetQueueSpawning(false)
        if not inst.components.spawner:IsSpawnPending() then
            inst.components.spawner:SpawnWithDelay(math.random(60, 180))
        end
    end
end

local function stopspawning(inst)
    if inst.components.spawner ~= nil then
        inst.components.spawner:SetQueueSpawning(true, math.random(60, 120))
    end
end

local function onoccupied(inst)
    if inst.springmode then
        if not inst.iscollapsed:value() then
            inst.AnimState:PlayAnimation("idle_flooded")
            inst.iscollapsed:set(true)
            OnIsCollapsedDirty(inst)
        end
    elseif TheWorld.state.isday and not TheWorld.state.isspring then
        startspawning(inst)
    end
end

local function OnIsDay(inst, isday)
    if isday and not TheWorld.state.isspring and
        inst.components.spawner ~= nil and inst.components.spawner:IsOccupied() then
        startspawning(inst)
    else
        stopspawning(inst)
    end
end

local function SetSpringMode(inst)
    inst.springtask = nil
    if (not inst.springmode and TheWorld.state.isspring) or inst.springmode == nil then
        inst.springmode = true

        inst:StopWatchingWorldState("isday", OnIsDay)
        stopspawning(inst)

        if inst.components.spawner:IsOccupied() or inst.components.spawner.child == nil then
            inst.AnimState:PlayAnimation("idle_flooded")
            inst.iscollapsed:set(true)
            OnIsCollapsedDirty(inst)
        end
    end
end

local function SetNormalMode(inst)
    inst.springtask = nil
    if (inst.springmode and not TheWorld.state.isspring) or inst.springmode == nil then
        inst.springmode = false

        inst:WatchWorldState("isday", OnIsDay)
        OnIsDay(inst, TheWorld.state.isday)

        inst.AnimState:PlayAnimation("idle")
        inst.iscollapsed:set(false)
        OnIsCollapsedDirty(inst)
    end
end

local function OnStartRain(inst)
    if inst.watchingrain then
        inst.watchingrain = nil
        inst:StopWatchingWorldState("startrain", OnStartRain)
    end

    if inst.springtask ~= nil then
        inst.springtask:Cancel()
        inst.springtask = nil
    end

    if not inst.springmode then
        inst.springtask = inst:DoTaskInTime(math.random(3, 20), SetSpringMode)
    end
end

local function OnIsSpring(inst, isspring)
    if inst.springtask ~= nil then
        inst.springtask:Cancel()
        inst.springtask = nil
    end

    local watchrain = false
    if isspring then
        if not inst.springmode then
            --It just became spring, and we're not in spring mode,
            --so watch for rain to start spring mode transition timer
            watchrain = true
        end
    elseif inst.springmode then
        --It is no long spring, and we're in spring mode,
        --so start normal mode transition timer
        inst.springtask = inst:DoTaskInTime(math.random(TUNING.MIN_RABBIT_HOLE_TRANSITION_TIME, TUNING.MAX_RABBIT_HOLE_TRANSITION_TIME), SetNormalMode)
    end

    if watchrain then
        if TheWorld.state.israining then
            --Special case where it's already raining, so there is no
            --need to watch for rain anymore, and just run the handler
            OnStartRain(inst)
        elseif not inst.watchingrain then
            inst.watchingrain = true
            inst:WatchWorldState("startrain", OnStartRain)
        end
    elseif inst.watchingrain then
        inst.watchingrain = nil
        inst:StopWatchingWorldState("startrain", OnStartRain)
    end
end

local function OnInit(inst, springmode)
    inst.inittask = nil

    --Set initial mode immediately
    if not TheWorld.state.isspring then
        SetNormalMode(inst)
    elseif springmode then
        SetSpringMode(inst)
    else
        SetNormalMode(inst)
        OnIsSpring(inst, true)
    end

    --Start watching for spring changes
    inst:WatchWorldState("isspring", OnIsSpring)
end

local function OnSave(inst, data)
    data.springmode = inst.springmode or nil
end

local function OnLoad(inst, data)
    if data ~= nil and data.springmode and inst.inittask ~= nil then
        inst.inittask:Cancel()
        inst.inittask = inst:DoTaskInTime(0, OnInit, true)
    end
end

local function GetStatus(inst)
    return inst.iscollapsed:value() and "SPRING" or nil
end

local function OnHaunt(inst)
    return not (inst.springmode or TheWorld.state.isspring)
        and inst.components.spawner ~= nil
        and inst.components.spawner:IsOccupied()
        and inst.components.spawner:ReleaseChild()
end

local function OnPreLoad(inst, data)
    WorldSettings_Spawner_PreLoad(inst, data, TUNING.RABBIT_RESPAWN_TIME)
end

local function AbleToAcceptTest(inst, item, giver, count)
    if inst.iscollapsed:value() then
        return false
    end

    if item.prefab ~= "carrot" then
        return false
    end

    if not giver:HasTag("player") then
        return false
    end

    local rabbitkingmanager = TheWorld.components.rabbitkingmanager
    if rabbitkingmanager == nil or not rabbitkingmanager:CanFeedCarrot(giver) then
        return false
    end

    return true
end

local function OnItemAccepted(inst, giver, item, count)
    if item.prefab == "carrot" then
        local rabbitkingmanager = TheWorld.components.rabbitkingmanager
        if rabbitkingmanager then
            rabbitkingmanager:AddCarrotFromPlayer(giver, inst)
        end
    end
end

local function OnVacated(inst, child)
    stopspawning(inst) -- First stop the regular spawning stuff.
    -- Then try your luck!
    local x, y, z = inst.Transform:GetWorldPosition()
    local player = FindClosestPlayerInRangeSq(x, y, z, TUNING.RABBITKING_TELEPORT_DISTANCE_SQ, true)
    if player and TryLuckRoll(player, TUNING.RABBITKING_LUCKY_ODDS, LuckFormulas.LuckyRabbitSpawn) then
        local rabbitkingmanager = TheWorld.components.rabbitkingmanager
        if rabbitkingmanager and not rabbitkingmanager:ShouldStopActions() then -- Same with this.
            if rabbitkingmanager:CreateRabbitKingForPlayer(player, child:GetPosition(), "lucky", {home = inst}) then
                child:Remove()
            end
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("cattoy")

    inst.AnimState:SetBank("rabbithole")
    inst.AnimState:SetBuild("rabbit_hole")
    inst.AnimState:PlayAnimation("idle")
    --inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)

    inst.iscollapsed = net_bool(inst.GUID, "rabbithole.iscollapsed", "iscollapseddirty")
    OnIsCollapsedDirty(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("iscollapseddirty", OnIsCollapsedDirty)

        return inst
    end

    inst:AddComponent("spawner")
    WorldSettings_Spawner_SpawnDelay(inst, TUNING.RABBIT_RESPAWN_TIME, TUNING.RABBIT_ENABLED)
    inst.components.spawner:Configure("rabbit", TUNING.RABBIT_RESPAWN_TIME)

    inst.components.spawner:SetOnOccupiedFn(onoccupied)
    inst.components.spawner:SetOnVacateFn(OnVacated)

    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.DIG)
    inst.components.workable:SetOnFinishCallback(dig_up)
    inst.components.workable:SetWorkLeft(1)
    AddToRegrowthManager(inst)

    inst.springmode = nil
    inst.springtask = nil
    inst.watchingrain = nil
    inst.inittask = inst:DoTaskInTime(0, OnInit)

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("hauntable")
    inst.components.hauntable:SetHauntValue(TUNING.HAUNT_SMALL)
    inst.components.hauntable:SetOnHauntFn(OnHaunt)

    local trader = inst:AddComponent("trader")
    trader:SetAbleToAcceptTest(AbleToAcceptTest)
    trader:SetOnAccept(OnItemAccepted)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    inst.OnPreLoad = OnPreLoad

    return inst
end

return Prefab("rabbithole", fn, assets, prefabs)
