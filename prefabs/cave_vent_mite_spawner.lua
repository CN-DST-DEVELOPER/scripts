require("worldsettingsutil")

local prefabs =
{
    "cave_vent_mite",
}

local ZERO = Vector3(0,0,0)
local function zero_spawn_offset(inst)
    return ZERO
end

local function OnMiteSpawned(inst, gnome)
    gnome:PushEvent("spawn")
end

local function DoSpawnTest(inst)
    if not inst.components.childspawner:CanSpawn() then
        if inst._PeriodicSpawnTesting ~= nil then
            inst._PeriodicSpawnTesting:Cancel()
            inst._PeriodicSpawnTesting = nil
        end
        return
    end

    local ix, iy, iz = inst.Transform:GetWorldPosition()

    local close_players = nil
    for _, player in ipairs(AllPlayers) do
        if player.components.areaaware ~= nil
                and player.components.areaaware:CurrentlyInTag("fumarolearea") then
            local dsq_to_player = player:GetDistanceSqToPoint(ix, iy, iz)
            if dsq_to_player <= TUNING.CAVE_MITE_SPAWN_RADIUSSQ then
                if close_players == nil then
                    close_players = {}
                end
                table.insert(close_players, player)
            end
        end
    end

    if close_players == nil or #close_players == 0 then
        return
    end

    local mite = inst.components.childspawner:SpawnChild()
    if mite == nil then
        return
    end

    local random_player_in_range = close_players[math.random(#close_players)]
    local spawn_distance = Lerp(10, 16, math.sqrt(math.random()))
    local player_position = random_player_in_range:GetPosition()

    local offset = FindWalkableOffset(
        player_position,
        math.random() * TWOPI,
        spawn_distance,
        nil,
        false,
        true
    )
    if offset == nil then
        return
    end

    mite.Transform:SetPosition((player_position + offset):Get())
end

local TEST_FREQUENCY = 10
local function StartTesting(inst)
    if inst._PeriodicSpawnTesting ~= nil then
        inst._PeriodicSpawnTesting:Cancel()
        inst._PeriodicSpawnTesting = nil
    end
    inst._PeriodicSpawnTesting = inst:DoPeriodicTask(TEST_FREQUENCY, DoSpawnTest)
end

local function OnEntityWake(inst)
    StartTesting(inst)
end

local function OnEntitySleep(inst)
    if inst._PeriodicSpawnTesting ~= nil then
        inst._PeriodicSpawnTesting:Cancel()
        inst._PeriodicSpawnTesting = nil
    end
end

local function OnAddMite(inst)
    if inst._PeriodicSpawnTesting == nil then
        StartTesting(inst)
    end
end

local function OnPreLoad(inst, data)
    WorldSettings_ChildSpawner_PreLoad(inst, data, TUNING.CAVE_MITE_RELEASE_TIME, TUNING.CAVE_MITE_ENABLED)
end

local function spawnerfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    --[[Non-networked entity]]
    inst:AddTag("CLASSIFIED")

    inst:AddComponent("childspawner")
    inst.components.childspawner:SetSpawnPeriod(TUNING.CAVE_MITE_RELEASE_TIME)
    inst.components.childspawner:SetRegenPeriod(TUNING.CAVE_MITE_REGEN_TIME)
    inst.components.childspawner:SetMaxChildren(TUNING.CAVE_MITE_MAX_CHILDREN)

    WorldSettings_ChildSpawner_SpawnPeriod(inst, TUNING.CAVE_MITE_RELEASE_TIME, TUNING.CAVE_MITE_ENABLED)
    WorldSettings_ChildSpawner_RegenPeriod(inst, TUNING.CAVE_MITE_REGEN_TIME, TUNING.CAVE_MITE_ENABLED)
    if not TUNING.CAVE_MITE_ENABLED then
        inst.components.childspawner.childreninside = 0
    end

    inst.components.childspawner:SetSpawnedFn(OnMiteSpawned)
    inst.components.childspawner:SetOccupiedFn(StartTesting)
    inst.components.childspawner:SetOnAddChildFn(OnAddMite)

    inst.components.childspawner.childname = "cave_vent_mite"
    inst.components.childspawner.overridespawnlocation = zero_spawn_offset

    inst.components.childspawner:StartRegen()

    inst.OnEntityWake = OnEntityWake
    inst.OnEntitySleep = OnEntitySleep

    inst.OnPreLoad = OnPreLoad

    return inst
end

return Prefab("cave_vent_mite_spawner", spawnerfn, nil, prefabs)