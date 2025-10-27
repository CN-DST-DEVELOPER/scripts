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
    for i, shadow in ipairs(inst.buzzardshadows) do
        local dist = shadow.components.circler.distance
        local angle = shadow.components.circler.angleRad
        local pos = inst:GetPosition()
        local offset = FindWalkableOffset(pos, angle, dist, 8, false)
        if offset ~= nil then
            child.Transform:SetPosition(pos.x + offset.x, 30, pos.z + offset.z)
        else
            child.Transform:SetPosition(pos.x, 30, pos.y)
        end
        child.sg:GoToState(child:HasTag("creaturecorpse") and "corpse_fall" or "glide")
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

local function OnWakeTask(inst)
    inst.waketask = nil
    if not inst:IsAsleep() then
        UpdateShadows(inst)
    end
end

local function UpdateAwakeTasks(inst)
    local _worldstate = TheWorld.state
    if not _worldstate.isnight and not _worldstate.iswinter and not _worldstate.islunarhailing then
        if inst.waketask == nil then
            inst.waketask = inst:DoTaskInTime(.5, OnWakeTask)
        end
        if inst.foodtask == nil then
            inst.foodtask = inst:DoPeriodicTask(math.random(20, 40) * .1, LookForFood)
        end
    end
end

local function InstantKillBuzzardsWithLunarHail(inst)
    local mutatedbirdmanager = TheWorld.components.mutatedbirdmanager
    if mutatedbirdmanager and TUNING.SPAWN_MUTATED_BUZZARDS_GESTALT then
        local childspawner = inst.components.childspawner
        local num_children = childspawner:NumChildren()

        mutatedbirdmanager:FillMigrationTaskAtInst("mutatedbuzzard_gestalt", inst, num_children)

        -- Clear the children
        childspawner.childreninside = 0
        for k, child in pairs(childspawner.childrenoutside) do
            child:Remove()
        end
    end
end

local function OnEntitySleep(inst)
    for i = #inst.buzzardshadows, 1, -1 do
        inst.buzzardshadows[i]:Remove()
        table.remove(inst.buzzardshadows, i)
    end
    CancelAwakeTasks(inst)

    if TheWorld.state.islunarhailing then
        InstantKillBuzzardsWithLunarHail(inst)
    end
end

local function OnEntityWake(inst)
    UpdateAwakeTasks(inst)
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
        if inst:IsAsleep() then
            InstantKillBuzzardsWithLunarHail(inst)
            inst:StopWatchingWorldState("lunarhaillevel", OnLunarHailLevel)
        elseif inst.components.childspawner.childreninside > 0 then
            local corpse = inst.components.childspawner:SpawnChild(nil, "buzzardcorpse")
            if corpse ~= nil and TUNING.SPAWN_MUTATED_BUZZARDS_GESTALT then
                -- state and position is handled in OnSpawn
                corpse:StartGestaltTimer(5 + math.random() * 6)
            end
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
    UpdateShadows(inst)
    if inst.components.childspawner.numchildrenoutside + inst.components.childspawner.childreninside >= inst.components.childspawner.maxchildren then
        inst.components.childspawner:StopRegen()
    end
end

local function SpawnerOnInit(inst)
    inst.OnEntityWake = OnEntityWake
    inst.OnEntitySleep = OnEntitySleep

    inst:WatchWorldState("iswinter", SpawnerOnIsWinter)
    SpawnerOnIsWinter(inst, TheWorld.state.iswinter)
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

    inst.buzzardshadows = {}
    inst.foodtask = nil
    inst.waketask = nil
    inst:DoTaskInTime(0, SpawnerOnInit)

    return inst
end

return Prefab("buzzardspawner", fn, spawner_assets, prefabs)