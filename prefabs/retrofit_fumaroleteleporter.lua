local prefabs = {
    "wormhole",
}

local function can_spawn_here(x, z)
    local min_space = .5
    if TheWorld.Map:IsAboveGroundAtPoint(x, 0, z) and
        TheWorld.Map:IsAboveGroundAtPoint(x + min_space, 0, z) and
        TheWorld.Map:IsAboveGroundAtPoint(x, 0, z + min_space) and
        TheWorld.Map:IsAboveGroundAtPoint(x - min_space, 0, z) and
        TheWorld.Map:IsAboveGroundAtPoint(x, 0, z - min_space) then
        return #TheSim:FindEntities(x, 0, z, min_space) == 0
    end

    return false
end

local function DoRetrofitting(inst, force_pt)
    local w2 = nil
    if force_pt == nil then
        local topology = TheWorld.topology
        -- CentipedeCaveTask is assumed to only to connect to KEYS.TIER4 tasks.
        -- We will gather up all nodes that have this task as a key giver as a potential wormhole spawn location.
        local tasks = require("map/tasks")
        local tasknames = tasks.GetAllTaskNames()
        local tier4tasks = {}
        for _, taskname in ipairs(tasknames) do
            local task = tasks.GetTaskByName(taskname)
            if task and task.keys_given then
                if table.contains(task.keys_given, KEYS.TIER4) and table.contains(task.keys_given, KEYS.CAVE) then
                    tier4tasks[taskname] = true
                end
            end
        end

        local potential_indexies = {}
        for i, id in ipairs(topology.ids) do
            for taskname, _ in pairs(tier4tasks) do
                if id:find(taskname) == 1 then
                    table.insert(potential_indexies, i)
                end
            end
        end
        shuffleArray(potential_indexies)

        for _, index in ipairs(potential_indexies) do
            local area =  topology.nodes[index]
            local points_x, points_z = TheWorld.Map:GetRandomPointsForSite(area.x, area.y, area.poly, 15)
            for i = 1, #points_x do
                if can_spawn_here(points_x[i], points_z[i]) then
                    w2 = SpawnPrefab("wormhole")
                    w2.Transform:SetPosition(points_x[i], 0, points_z[i])
                    break
                end
            end
            if w2 ~= nil then
                break
            end
        end

    elseif force_pt.x ~= nil and force_pt.y ~= nil and force_pt.z ~= nil then
        w2 = SpawnPrefab("wormhole")
        w2.Transform:SetPosition(force_pt:Get())
    end

    if w2 ~= nil then
        local x, y, z = inst.Transform:GetWorldPosition()

        -- replace this marker with a wormhole
        local w1 = SpawnPrefab("wormhole")
        w1.Transform:SetPosition(x, y, z)

        w1.components.teleporter:Target(w2)
        w2.components.teleporter:Target(w1)

        -- this wormhole is being added because we cannot reliably retrofit the land masses being connected to the mainland, no need to have a sanity cost for using it
        w1.disable_sanity_drain = true
        w2.disable_sanity_drain = true

        inst:Remove()

        return true
    end

    return false
end

-- c_spawn("retrofit_fumaroleteleporter"):DoRetrofitting()

local function fn()
    local inst = CreateEntity()

    --[[Non-networked entity]]
    inst.entity:AddTransform()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.DoRetrofitting = DoRetrofitting

    return inst
end

return Prefab("retrofit_fumaroleteleporter", fn, nil, prefabs)
