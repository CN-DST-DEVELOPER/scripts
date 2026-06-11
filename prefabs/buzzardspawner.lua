local spawner_assets =
{
    Asset("MINIMAP_IMAGE", "buzzard"),
}

local prefabs =
{
    "buzzard",
    "circlingbuzzard",
}

local FOOD_TAGS = { "edible_"..FOODTYPE.MEAT, "prey" }
local NO_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO" }

local function RemoveBuzzardShadow(inst, shadow)
    shadow:KillShadow()
    for i, v in ipairs(inst.buzzardshadows) do
        if v == shadow then
            table.remove(inst.buzzardshadows, i)
            return
        end
    end
end

local function SpawnBuzzardShadow(inst)
    local shadow = SpawnPrefab("circlingbuzzard")
    shadow.components.circler:SetCircleTarget(inst)
    shadow.components.circler:Start()
    table.insert(inst.buzzardshadows, shadow)
end

local function UpdateShadows(inst)
    local count = inst.components.childspawner.childreninside
    local old = #inst.buzzardshadows
    if old < count then
        for i = old + 1, count do
            SpawnBuzzardShadow(inst)
        end
    elseif old > count then
        for i = old, count + 1, -1 do
            RemoveBuzzardShadow(inst, inst.buzzardshadows[i])
        end
    end
end

local function ReturnChildren(inst)
    for k, child in pairs(inst.components.childspawner.childrenoutside) do
        if child.components.homeseeker ~= nil then
            child.components.homeseeker:GoHome()
        end
        child.shouldGoAway = true -- The above doesn't actually really work, so we're setting this instead for the brain.
        child:PushEvent("gohome")
    end
end

local function OnSpawn(inst, child)
    local is_asleep = inst:IsAsleep()
    local y = is_asleep and 0 or 30
    for i, shadow in ipairs(inst.buzzardshadows) do
        local dist = shadow.components.circler.distance
        local angle = shadow.components.circler.angleRad
        local pos = inst:GetPosition()
        local offset = FindWalkableOffset(pos, angle, dist, 8, false)
        if offset ~= nil then
            child.Transform:SetPosition(pos.x + offset.x, y, pos.z + offset.z)
        else
            child.Transform:SetPosition(pos.x, y, pos.y)
        end
        if is_asleep then
            child.sg:GoToState(child:HasTag("creaturecorpse") and "corpse_idle" or "idle")
        else
            child.sg:GoToState(child:HasTag("creaturecorpse") and "corpse_fall" or inst.forcefall and "fall" or "glide")
        end
        RemoveBuzzardShadow(inst, shadow)
        return
    end
end

local function stophuntingfood(inst)
    local food = inst.foodHunted or inst
    local buzzard = inst.buzzardHunted or inst
    if food ~= nil and buzzard ~= nil then
        food.buzzardHunted = nil
        buzzard.foodHunted = nil
        food:RemoveEventCallback("onpickup", stophuntingfood)
        food:RemoveEventCallback("onremove", stophuntingfood)
        buzzard:RemoveEventCallback("onremove", stophuntingfood)
    end
end

local CANHAUNT_MUST_TAGS = { "buzzard" }
local function CanBeHunted(food)
    return food.buzzardHunted == nil and food:IsOnValidGround() and FindEntity(food, 3, nil, CANHAUNT_MUST_TAGS, NO_TAGS) == nil
end

local function LookForFood(inst)
    if not inst.components.childspawner:CanSpawn() or math.random() <= .25 then
        return
    end

    local food = FindEntity(inst, 25, CanBeHunted, nil, NO_TAGS, FOOD_TAGS)
    if food ~= nil then
        local buzzard = inst.components.childspawner:SpawnChild()
		if buzzard ~= nil then
			local x, y, z = food.Transform:GetWorldPosition()
			buzzard.Transform:SetPosition(x + math.random() * 3 - 1.5, 30, z + math.random() * 3 - 1.5)
			buzzard:FacePoint(x, y, z)

			if food:HasTag("prey") then
				buzzard.sg.statemem.target = food
			end

			food.buzzardHunted = buzzard
			buzzard.foodHunted = food
			food:ListenForEvent("onpickup", stophuntingfood)
			food:ListenForEvent("onremove", stophuntingfood)
			buzzard:ListenForEvent("onremove", stophuntingfood)

			inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/buzzard/distant")
		end
    end
end

local function CancelAwakeTasks(inst)
    if inst.waketask ~= nil then
        inst.waketask:Cancel()
        inst.waketask = nil
    end
    if inst.foodtask ~= nil then
        inst.foodtask:Cancel()
        inst.foodtask = nil
    end
end

local function TryUpdateShadows(inst)
    if not inst:IsAsleep() then
        -- The shadows can still appear during lunar hail
        if not TheWorld.state.isnight and not TheWorld.state.iswinter then
            UpdateShadows(inst)
        end
    end
end

local function OnWakeTask(inst)
    inst.waketask = nil
    TryUpdateShadows(inst)
end

local function UpdateAwakeTasks(inst)
    local _worldstate = TheWorld.state
    if not _worldstate.isnight and not _worldstate.iswinter then
        if inst.waketask == nil then
            inst.waketask = inst:DoTaskInTime(.5, OnWakeTask)
        end
        if inst.foodtask == nil and not _worldstate.islunarhailing then
            inst.foodtask = inst:DoPeriodicTask(math.random(20, 40) * .1, LookForFood)
        end
    end
end

local function CreateFlareDetonatedListener(hit_num)
    return function(inst, data)
        data.hit_num_buzzards = data.hit_num_buzzards or 0
        if data.sourcept and inst:GetDistanceSqToPoint(data.sourcept) <= TUNING.BUZZARDSPAWNER_FLARE_HIT_DIST_SQ and data.hit_num_buzzards < hit_num then
            local buzzard
            repeat
                inst.forcefall = true
                buzzard = inst.components.childspawner:SpawnChild(data.igniter)
                inst.forcefall = nil
                if buzzard ~= nil then
                    buzzard.Transform:OffsetPosition(0, math.random() * 15 - 7.5, 0)
                    data.hit_num_buzzards = data.hit_num_buzzards + 1
                end
            until data.hit_num_buzzards >= hit_num or buzzard == nil
        end
    end
end

local OnMiniFlareDetonated = CreateFlareDetonatedListener(1)
local OnMegaFlareDetonated = CreateFlareDetonatedListener(5)

local function RegisterFlareListeners(inst)
    inst.miniflare_detonated_cb = function(src, data) OnMiniFlareDetonated(inst, data) end
    inst.megaflare_detonated_cb = function(src, data) OnMegaFlareDetonated(inst, data) end
    inst:ListenForEvent("miniflare_detonated", inst.miniflare_detonated_cb, TheWorld)
    inst:ListenForEvent("megaflare_detonated", inst.megaflare_detonated_cb, TheWorld)
end

local function OnEntitySleep(inst)
    for i = #inst.buzzardshadows, 1, -1 do
        inst.buzzardshadows[i]:Remove()
        table.remove(inst.buzzardshadows, i)
    end
    CancelAwakeTasks(inst)
    if inst.miniflare_detonated_cb ~= nil then
        inst:RemoveEventCallback("miniflare_detonated", inst.miniflare_detonated_cb, TheWorld)
    end
    if inst.megaflare_detonated_cb ~= nil then
        inst:RemoveEventCallback("megaflare_detonated", inst.megaflare_detonated_cb, TheWorld)
    end
end

local function OnEntityWake(inst)
    UpdateAwakeTasks(inst)
    RegisterFlareListeners(inst)
end

local function UpdateChildSpawner(inst)
    local isnight, iswinter, islunarhailing = TheWorld.state.isnight, TheWorld.state.iswinter, TheWorld.state.islunarhailing

    if islunarhailing or iswinter then
        inst.components.childspawner:StopSpawning()
        inst.components.childspawner:StopRegen()
    else
        if isnight then
            inst.components.childspawner:StopSpawning()
            if not inst.components.childspawner.regening and inst.components.childspawner.numchildrenoutside + inst.components.childspawner.childreninside < inst.components.childspawner.maxchildren then
                inst.components.childspawner:StartRegen()
            end
        else
            inst.components.childspawner:StartSpawning()
        end
    end
end

local function SpawnerOnIsNight(inst, isnight)
    if isnight then
        UpdateChildSpawner(inst)
        ReturnChildren(inst)
        CancelAwakeTasks(inst)
    else
        inst.components.childspawner:StartSpawning()
        if not inst:IsAsleep() then
            UpdateAwakeTasks(inst)
        end
    end
end

local function OnLunarHailLevel(inst, lunarhaillevel)
    if lunarhaillevel <= inst._drop_buzzards_at_lunar_hail_level then
        if inst.components.childspawner.childreninside > 0 then
            inst.components.childspawner.spawnoffscreen = true -- For if we're off screen.

            local corpse = inst.components.childspawner:SpawnChild(nil, "buzzardcorpse")
            if corpse ~= nil then
                -- state and position is handled in OnSpawn
                if TUNING.SPAWN_MUTATED_BUZZARDS_GESTALT then
                    corpse:StartGestaltTimer(10 + math.random() * 6)
                else
                    corpse:StartFadeTimer(12 + math.random() * 6)
                end
            end

            inst.components.childspawner.spawnoffscreen = false
        else
            inst:StopWatchingWorldState("lunarhaillevel", OnLunarHailLevel)
        end
    end
end

local BUZZARDSPAWNER_KILL_BUZZARDS_LUNAR_HAIL_BASE = TUNING.BUZZARDSPAWNER_KILL_BUZZARDS_LUNAR_HAIL_BASE
local BUZZARDSPAWNER_KILL_BUZZARDS_LUNAR_HAIL_VAR = TUNING.BUZZARDSPAWNER_KILL_BUZZARDS_LUNAR_HAIL_VAR
local function SpawnerOnIsLunarHailing(inst, islunarhailing)
    if islunarhailing then
        inst._drop_buzzards_at_lunar_hail_level = BUZZARDSPAWNER_KILL_BUZZARDS_LUNAR_HAIL_BASE + math.random() * BUZZARDSPAWNER_KILL_BUZZARDS_LUNAR_HAIL_VAR
        inst:WatchWorldState("lunarhaillevel", OnLunarHailLevel)

        UpdateChildSpawner(inst)
        ReturnChildren(inst)
        CancelAwakeTasks(inst)
    else
        inst._drop_buzzards_at_lunar_hail_level = nil
        inst:StopWatchingWorldState("lunarhaillevel", OnLunarHailLevel)

        UpdateChildSpawner(inst)
        if not inst:IsAsleep() then
            UpdateAwakeTasks(inst)
        end
    end
end

local function SpawnerOnIsWinter(inst, iswinter)
    if iswinter then
        inst:StopWatchingWorldState("isnight", SpawnerOnIsNight)
        inst:StopWatchingWorldState("islunarhailing", SpawnerOnIsLunarHailing)

        if inst._drop_buzzards_at_lunar_hail_level ~= nil then
            inst._drop_buzzards_at_lunar_hail_level = nil
            inst:StopWatchingWorldState("lunarhaillevel", OnLunarHailLevel)
        end

        UpdateChildSpawner(inst)
        ReturnChildren(inst)
        CancelAwakeTasks(inst)
    else
        inst:WatchWorldState("isnight", SpawnerOnIsNight)
        inst:WatchWorldState("islunarhailing", SpawnerOnIsLunarHailing)
        SpawnerOnIsNight(inst, TheWorld.state.isnight)
        SpawnerOnIsLunarHailing(inst, TheWorld.state.islunarhailing)
    end
end

local function OnAddChild(inst)
    TryUpdateShadows(inst)
    if inst.components.childspawner.numchildrenoutside + inst.components.childspawner.childreninside >= inst.components.childspawner.maxchildren then
        inst.components.childspawner:StopRegen()
    end
end

local function SpawnerOnInit(inst)
    inst.OnEntityWake = OnEntityWake
    inst.OnEntitySleep = OnEntitySleep

    inst:WatchWorldState("iswinter", SpawnerOnIsWinter)
    SpawnerOnIsWinter(inst, TheWorld.state.iswinter)

    if not inst:IsAsleep() then
        RegisterFlareListeners(inst)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("buzzard.png")

    inst:AddTag("buzzardspawner")
    inst:AddTag("CLASSIFIED")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("childspawner")
    inst.components.childspawner.childname = "buzzard"
    inst.components.childspawner:SetSpawnedFn(OnSpawn)
    inst.components.childspawner:SetOnAddChildFn(OnAddChild)
    inst.components.childspawner:SetMaxChildren(math.random(1, 2))
    inst.components.childspawner:SetSpawnPeriod(TUNING.BUZZARD_SPAWN_PERIOD + math.random(-TUNING.BUZZARD_SPAWN_VARIANCE, TUNING.BUZZARD_SPAWN_VARIANCE))
    inst.components.childspawner:SetRegenPeriod(TUNING.BUZZARD_REGEN_PERIOD)
    inst.components.childspawner:StopRegen()
    inst.components.childspawner.save_max_children = true

    inst.buzzardshadows = {}
    inst.foodtask = nil
    inst.waketask = nil
    inst:DoTaskInTime(0, SpawnerOnInit)

    return inst
end

return Prefab("buzzardspawner", fn, spawner_assets, prefabs)