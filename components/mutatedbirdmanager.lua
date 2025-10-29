--------------------------------------------------------------------------
--[[ MutatedBirdManager class definition ]]
--------------------------------------------------------------------------

-- NOTE: Migration here refers to the actual migration of creatures around the world. Not shard migration.

-- TODO might want to split this file into several components
-- migrationmanager
-- mutatedbuzzardmanager

--[[
birds will get angry at players who:
scare off mutated birds
have moon glass on them
are mining moon glass

unique interactions
birds get angry at wicker when she tries to read birds of the world (maybe future lunar aligned wicker can be immune to this)
]]

--[[
FIX START node
fix static island nodes
]]

return Class(function(self, inst)

assert(TheWorld.ismastersim, "MutatedBirdManager should not exist on client")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local VALID_PATH_CAPS = { ignorewalls = true, ignorecreep = true }

local CORPSE_PERSIST_SOURCE = "mutatedbuzzard_corpse"

-- bird vals

local RIFT_BIRD_MIGRATE_TIME_BASE = TUNING.RIFT_BIRD_MIGRATE_TIME_BASE
local RIFT_BIRD_MIGRATE_TIME_VAR = TUNING.RIFT_BIRD_MIGRATE_TIME_VAR

local RIFT_BIRD_MIGRATE_TIME_RAIN_FACTOR = TUNING.RIFT_BIRD_MIGRATE_TIME_RAIN_FACTOR
local RIFT_BIRD_MIGRATE_TIME_MOONPHASE_FACTOR = TUNING.RIFT_BIRD_MIGRATE_TIME_MOONPHASE_FACTOR
local RIFT_BIRD_MIGRATE_TIME_NON_NIGHT_FACTOR = TUNING.RIFT_BIRD_MIGRATE_TIME_NON_NIGHT_FACTOR

-- buzz vals

local MUTATEDBUZZARD_MIGRATE_TIME_BASE = TUNING.MUTATEDBUZZARD_MIGRATE_TIME_BASE
local MUTATEDBUZZARD_MIGRATE_TIME_VAR = TUNING.MUTATEDBUZZARD_MIGRATE_TIME_VAR

local MUTATEDBUZZARD_CORPSE_RANGE = TUNING.MUTATEDBUZZARD_CORPSE_RANGE
local MUTATEDBUZZARD_CORPSE_RANGE_SQ = MUTATEDBUZZARD_CORPSE_RANGE * MUTATEDBUZZARD_CORPSE_RANGE

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _world = TheWorld
local _worldstate = _world.state
local _map = _world.Map

local _activeplayers = {}
local _playertasks = {} --[player] = "Forest"

local _birdenemies = {} --[ent] = true

local _buzzards = {} -- array
local _buzzardshadows = {}

local idtomigrationkey = nil
--[[ E.g.
    -- each topology id
    ["Forest:0:Test"] = "Forest",
]]
local _migrationmap = nil
--[[ E.g.
    -- each task
    ["Forest"] = {
        -- neighbours
        "Savanha",
        "Grassland",
        "Desert",
    } 
]]
local _migrationpopulations = nil
--[[ E.g.
["mutatedbird"] = 
{
    ["Forest"] = {current = 0, max = 10, migrate_timer = 23.2}
},
["mutatedbuzzard_gestalt"] =
{
    ["Forest"] = {current = 3, max = 10, migrate_timer = 53.1},
    ["Savanha"] = {current = 3, max = 10, migrate_timer = 12.6},
}
]]

local _migrationdistances = nil
--[[ E.g.
["Forest"] = {
    ["Savanha"] = 1, -- distance 1, which means neighbours.
    ["Grassland"] = 1,
    ["Desert"] = 1,

    ["Squletch"] = 2,
    ["Deciduous"] = 2,

    ["MoonIsland"] = 3,
}
]]

local _migrationtypes = {}

local _ishailing = false

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------



--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

--[[
TODO
special cases for pearl and lunar island and monkey island
-- id == "START"

maybe set up extra connections anyways after generation based on distance
]]

----- 

local function IsNodeValid(id)
    return not id:find("COVE") and not id:find("BLOCKER_BLANK_") and not id:find("LOOP_BLANK")
end

local function AddNeighboringTasks(task_name_one, task_name_two)
    _migrationmap[task_name_one] = _migrationmap[task_name_one] or {}
    _migrationmap[task_name_two] = _migrationmap[task_name_two] or {}

    if not table.contains(_migrationmap[task_name_one], task_name_two) then
        table.insert(_migrationmap[task_name_one], task_name_two)
    end

    if not table.contains(_migrationmap[task_name_two], task_name_one) then
        table.insert(_migrationmap[task_name_two], task_name_one)
    end
end

local function RecurseNeighbours(node, searchednodes, neighboringtask)
    for _, i in pairs(node.neighbours) do
        local id = _world.topology.ids[i]
        if not searchednodes[id] and IsNodeValid(id) then
            local neighbour_node = _world.topology.nodes[i]

            --local _, static_layout_name = id:match("(.*):(.*)")
            local task_name, _, room_name = id:match("(.*):(.*):(.*)")

            if task_name and neighboringtask and neighboringtask ~= task_name then
                AddNeighboringTasks(task_name, neighboringtask)
            end

            searchednodes[id] = true
            local next_neighbor = id:find("REGION_LINK_SUB_") and neighboringtask or task_name -- If this is a region link, pass on the current neighbouring task, not ourselves.
            RecurseNeighbours(neighbour_node, searchednodes, next_neighbor)
        end
    end
end

local function RecurseMigrationMapNeighbours(task_name, neighbours, dist)
    local nextdist = dist + 1
    for i, neighbour_name in ipairs(neighbours) do
        if neighbour_name ~= task_name and (dist < (_migrationdistances[task_name][neighbour_name] or math.huge)) then
            _migrationdistances[task_name][neighbour_name] = dist

            local nextneighours = _migrationmap[neighbour_name]
            RecurseMigrationMapNeighbours(task_name, nextneighours, nextdist)
        end
    end
end

local function InitializeMigrationMapFromTopology()
    local searchednodes = {} -- ["Task:0:Room"] = true
    if _migrationmap == nil then
        _migrationmap = {}

        for i, id in ipairs(_world.topology.ids) do
            local task_name, _, room_name = id:match("(.*):(.*):(.*)")
            RecurseNeighbours(_world.topology.nodes[i], searchednodes, task_name) -- TODO create a unique searchednodes cache for each initial recurse?
        end
    end

    -- Now intialize our populations
    if _migrationpopulations == nil then
        _migrationpopulations = {}

        for migrate_type, data in pairs(_migrationtypes) do
            _migrationpopulations[migrate_type] = {}

            for task in pairs(_migrationmap) do
                _migrationpopulations[migrate_type][task] = { current = 0, migrate_time = data.GetMigrateTime() }
            end
        end
    end

    -- Our distances.
    if _migrationdistances == nil then
        _migrationdistances = {}

        for task_name, neighbours in pairs(_migrationmap) do
            _migrationdistances[task_name] = {}

            local dist = 1
            RecurseMigrationMapNeighbours(task_name, neighbours, dist)
        end
    end

    inst:StartUpdatingComponent(self)
end

-----

local function IsValidBuzzard(buzzard)
    return not buzzard.components.health:IsDead() and not buzzard._killed
end

local function IsAnyBuzzardInRange(pos)
    -- Buzzards
    for i, buzzard in ipairs(_buzzards) do
        if IsValidBuzzard(buzzard) and buzzard:GetDistanceSqToPoint(pos) <= MUTATEDBUZZARD_CORPSE_RANGE_SQ then
            return true
        end
    end

    -- Buzzard Shadows
    for i, buzzard in ipairs(_buzzardshadows) do
        if buzzard:GetDistanceSqToPoint(pos) <= MUTATEDBUZZARD_CORPSE_RANGE_SQ then
            return true
        end
    end

    return false
end

local function OnIsLunarHailing(_, ishailing, onpostinit)
    if ishailing then

    else
        --It was hailing, now it's ended! The bird population has been replaced!
        if _ishailing then
            self:MaxAllMigrationNodesWithType("mutatedbird")
        end
    end

    _ishailing = ishailing
end

local function OnPlayerJoined(src, player)
    for i, v in ipairs(_activeplayers) do
        if v == player then
            return
        end
    end
    table.insert(_activeplayers, player)
end

local function OnPlayerLeft(src, player)
    for i, v in ipairs(_activeplayers) do
        if v == player then
            table.remove(_activeplayers, i)
            _playertasks[player] = nil
            return
        end
    end
end

local function OnRemoveMutatedBuzzard(buzzard)
	for i, v in ipairs(_buzzards) do
		if v == buzzard then
			table.remove(_buzzards, i)
			return
		end
	end
end

local function RegisterMutatedBuzzard(inst, buzzard)
	table.insert(_buzzards, buzzard)
	inst:ListenForEvent("onremove", OnRemoveMutatedBuzzard, buzzard)
end

local function OnRiftRemovedFromPool()
    local riftspawner = _world.components.riftspawner
    if riftspawner and not riftspawner:IsLunarPortalActive() then
        -- TODO make them fall! just temporary deletion for now.
        for migrator_type, map in pairs(_migrationpopulations) do
            for task, data in pairs(map) do
                if data.current then
                    data.current = 0
                end
            end
        end

        local shadows_to_delete = {}
        --
        for i, shadow in ipairs(_buzzardshadows) do
            table.insert(shadows_to_delete, shadow) -- don't remove here while iterating.
        end
        --
        for i, shadow in ipairs(shadows_to_delete) do
            if not shadow._killed and shadow:IsValid() then
                self:RemoveBuzzardShadow(shadow)
            end
        end
    end
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

--Initialize variables
for i, v in ipairs(AllPlayers) do
    table.insert(_activeplayers, v)
end

--Register events
inst:ListenForEvent("ms_playerjoined", OnPlayerJoined, _world)
inst:ListenForEvent("ms_playerleft", OnPlayerLeft, _world)
inst:ListenForEvent("ms_registermutatedbuzzard", RegisterMutatedBuzzard)

inst:ListenForEvent("ms_riftremovedfrompool", OnRiftRemovedFromPool)

inst:WatchWorldState("islunarhailing", OnIsLunarHailing)

--------------------------------------------------------------------------
--[[ Post initialization ]]
--------------------------------------------------------------------------

function self:OnPostInit()
    InitializeMigrationMapFromTopology()
    OnIsLunarHailing(inst, _worldstate.islunarhailing, true)

    local corpsepersistmanager = _world.components.corpsepersistmanager
    if corpsepersistmanager ~= nil then
        corpsepersistmanager:AddPersistSourceFn(CORPSE_PERSIST_SOURCE, function(corpse)
            -- corpse can also be a creature as it died.
            return self:GetPopulationForNodeAtInst("mutatedbuzzard_gestalt", corpse) > 0 or IsAnyBuzzardInRange(corpse:GetPosition())
        end)
    end
end

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

function self:CreateMigrationType(migration_data)
    _migrationtypes[migration_data.type] = migration_data
end

--
-- max population only really applies for migration, its more like a "preferred" population
self:CreateMigrationType({
    type = "mutatedbird",
    GetMaxPopulationForNode = function()
        return 10
    end,

    -- Keep calculations simple, or cache them, this is every OnUpdate
    GetMigrateTimeMult = function()
        local mod = 1

        if TheWorld.state.israining then
            mod = mod * RIFT_BIRD_MIGRATE_TIME_RAIN_FACTOR
        end

        if not TheWorld.state.isnight then
            mod = mod * RIFT_BIRD_MIGRATE_TIME_NON_NIGHT_FACTOR
        end

        -- We follow the moon!
        mod = mod * RIFT_BIRD_MIGRATE_TIME_MOONPHASE_FACTOR[TheWorld.state.moonphase]

        return mod
    end,

    GetMigrateTime = function()
        return RIFT_BIRD_MIGRATE_TIME_BASE + math.random() * RIFT_BIRD_MIGRATE_TIME_VAR
    end,
})

self:CreateMigrationType({
    type = "mutatedbuzzard_gestalt",
    GetMaxPopulationForNode = function()
        return 10
    end,

    -- Keep calculations simple, or cache them, this is every OnUpdate
    GetMigrateTimeMult = function()
        -- TODO, it would be fun to check for the number of edible/mutatable creatures in this node for the buzzards
        local mod = 1

        if not TheWorld.state.isnight then
            mod = mod * RIFT_BIRD_MIGRATE_TIME_NON_NIGHT_FACTOR
        end

        -- We follow the moon!
        mod = mod * RIFT_BIRD_MIGRATE_TIME_MOONPHASE_FACTOR[TheWorld.state.moonphase]

        return mod
    end,

    GetMigrateTime = function()
        return MUTATEDBUZZARD_MIGRATE_TIME_BASE + math.random() * MUTATEDBUZZARD_MIGRATE_TIME_VAR
    end,
})
--

-- Mutated birds and swarms
local function IsValidEnemyOfBirds(ent)
    return ent.components.combat ~= nil and ent.components.health ~= nil and not ent.components.health:IsDead()
end

function self:SetEnemyOfBirds(ent)
    if IsValidEnemyOfBirds(ent) then
        _birdenemies[ent] = true
    end
end

--
function self:GetMaxPopulationForNodeAtPoint(migrator_type, x, y, z)
    if z == nil then -- to support passing in (x, z) instead of (x, y, x)
		z = y
		y = 0
	end

    local migration_data = _migrationtypes[migrator_type]
    local task_name = self:GetMigrationTaskAtPoint(x, y, z)
    return migration_data.GetMaxPopulationForNode(task_name)
end

function self:GetMaxPopulationForNodeAtInst(migrator_type, inst)
    local migration_data = _migrationtypes[migrator_type]
    local x, y, z = inst.Transform:GetWorldPosition()
    local task_name = self:GetMigrationTaskAtPoint(x, y, z)
    return migration_data.GetMaxPopulationForNode(task_name)
end

function self:GetPopulationForNodeAtPoint(migrator_type, x, y, z)
    if z == nil then -- to support passing in (x, z) instead of (x, y, x)
		z = y
		y = 0
	end

    local task_name = self:GetMigrationTaskAtPoint(x, y, z)
    local population = _migrationpopulations[migrator_type]
    return population and population[task_name] and population[task_name].current
        or 0
end

function self:GetPopulationForNodeAtInst(migrator_type, inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local task_name = self:GetMigrationTaskAtPoint(x, y, z)
    local population = _migrationpopulations[migrator_type]
    return population and population[task_name] and population[task_name].current
        or 0
end

function self:FillMigrationTaskAtInst(migrator_type, inst, num)
    local task_name = self:GetMigrationTaskAtPoint(inst.Transform:GetWorldPosition())
    self:FillMigrationTaskWithType(migrator_type, task_name, num)
end

function self:MaxAllMigrationNodesWithType(migrator_type)
    local migration_data = _migrationtypes[migrator_type]
    for task, data in pairs(_migrationpopulations[migrator_type]) do
        self:FillMigrationTaskWithType(migrator_type, task, migration_data.GetMaxPopulationForNode())
    end
end

function self:FillMigrationTaskWithType(migrator_type, task, num)
    local population_task = _migrationpopulations[migrator_type][task]
    if population_task then
        population_task.current = population_task.current + num
    end
end

function self:GetMigrationTaskAtPoint(x, y, z)
    local node, node_index = _map:FindVisualNodeAtPoint(x, y, z)
    if node == nil then
        return nil
    end

    local idname = _world.topology.ids[node_index]
    local task_name, _, _ = idname:match("(.*):(.*):(.*)")
    return task_name
end

function self:GetMigrationTaskAtInst(inst)
    return self:GetMigrationTaskAtPoint(inst.Transform:GetWorldPosition())
end

function self:GetMigrationDistanceFromTaskToTask(start_task, end_task)
    if start_task ~= nil and end_task ~= nil and start_task == end_task then
        return 0
    end
    return _migrationdistances[start_task] ~= nil and _migrationdistances[start_task][end_task] or nil
end

function self:MigratePopulationToNode()
    
end

--
local function GetNextNeighbourClosestToAPlayer(migration_neighbours)
    local next_neighbour
    --
    for _, neighbour_name in ipairs(migration_neighbours) do
        for player, player_task in pairs(_playertasks) do
            -- We found our place to migrate to!
            local dist_neighbour_to_player = self:GetMigrationDistanceFromTaskToTask(neighbour_name, player_task)
            local dist_next_neighbour_to_player = self:GetMigrationDistanceFromTaskToTask(next_neighbour, player_task)
            if player_task == neighbour_name then
                return neighbour_name
            elseif next_neighbour == nil
                or (dist_neighbour_to_player and dist_next_neighbour_to_player and dist_neighbour_to_player < dist_next_neighbour_to_player)
            then
                next_neighbour = neighbour_name
            end
        end
    end
    --
    return next_neighbour
end

function self:DoMigrateTick()
    
end

function self:ShouldMigrate(task)
    for player, player_task in pairs(_playertasks) do
        if task == player_task then
            return false -- We're already at a player! Just... wait and lurk...
        end
    end
    --
    return true
end

--

local CORPSE_MUST_TAGS = { "creaturecorpse" }
local CORPSE_NO_TAGS = { "NOCLICK" }
local function IsValidCorpse(corpse)
    return not Buzzard_ShouldIgnoreCorpse(corpse) and not corpse:WillMutate() and not corpse:IsFading() and not corpse:HasGestaltArriving()
end

local function FindCorpse(player)
    local x, y, z = player.Transform:GetWorldPosition()
    local corpses = TheSim:FindEntities(x, y, z, 25, CORPSE_MUST_TAGS, CORPSE_NO_TAGS)
    local valid_corpses = {}

    for i = 1, #corpses do
        local corpse = corpses[i]
        if IsValidCorpse(corpse) then
            table.insert(valid_corpses, corpse)
        end
    end

    return #valid_corpses > 0 and valid_corpses[math.random(#valid_corpses)] or nil
end

function self:RemoveBuzzardShadow(shadow)
    shadow:KillShadow()
    for i, v in ipairs(_buzzardshadows) do
        if v == shadow then
            table.remove(_buzzardshadows, i)
            return
        end
    end
end

local function SendBuzzardToCorpse(buzzardshadow, corpse)
    local x, y, z = corpse.Transform:GetWorldPosition()
    local buzzard = SpawnPrefab("mutatedbuzzard_gestalt")
	buzzard.Transform:SetPosition(x + math.random() * 10 - 5, 30, z + math.random() * 10 - 5)
	buzzard:FacePoint(x, y, z)
    buzzard.sg:GoToState("glide")

    buzzard:DoTaskInTime(0, buzzard.SetOwnCorpse, corpse) -- One tick delay for brain to initialize

	buzzardshadow.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_buzzard/flock_squawk")
    self:RemoveBuzzardShadow(buzzardshadow)
end

local function OnRemoveBuzzardShadow(shadow)
	for i, v in ipairs(_buzzardshadows) do
		if v == shadow then
			table.remove(_buzzardshadows, i)
			return
		end
	end
end

local function SpawnBuzzardShadow(player)
    local shadow = SpawnPrefab("circlingbuzzard_lunar")
    shadow.components.mutatedbuzzardcircler:SetCircleTarget(player)
    shadow.components.mutatedbuzzardcircler:Start()
    --
    table.insert(_buzzardshadows, shadow)
    inst:ListenForEvent("onremove", OnRemoveBuzzardShadow, shadow)
end

--

function self:OnUpdate(dt)
    -- Set where the players are at.

    for i, player in ipairs(_activeplayers) do
        _playertasks[player] = self:GetMigrationTaskAtInst(player)
    end

    -- Migrate some birds around.
    if not _migrationpopulations then
        return
    end

    for migrator_type, map in pairs(_migrationpopulations) do
        local migration_data = _migrationtypes[migrator_type]

        for task, data in pairs(map) do

            local current_pop, migrate_time = data.current, data.migrate_time
            local max_pop = migration_data.GetMaxPopulationForNode()

            -- TODO self:DoMigrateTick
            if current_pop > 0 then
                if migrate_time <= 0 then
                    local migration_neighbours = _migrationmap[task]
                    local migrate_to = GetNextNeighbourClosestToAPlayer(migration_neighbours) or GetRandomItem(migration_neighbours)

                    -- TODO public function?
                    if migrate_to then
                        local migrate_to_population = _migrationpopulations[migrator_type][migrate_to]
                        local num_to_migrate = math.clamp(current_pop, 0, max_pop - migrate_to_population.current)
                        --
                        migrate_to_population.current = migrate_to_population.current + num_to_migrate
                        data.current = data.current - num_to_migrate
                    end

                    data.migrate_time = migration_data.GetMigrateTime()
                end

                if self:ShouldMigrate(task) then
                    data.migrate_time = data.migrate_time - dt * migration_data.GetMigrateTimeMult()
                end
            end
        end

    end

    -- Send some birds to our enemies.


    -- Send buzzards

    for player, player_task in pairs(_playertasks) do
        -- TODO don't spawn all, spread them out!
        local mutatedbuzzard_population = _migrationpopulations["mutatedbuzzard_gestalt"][player_task]
        if mutatedbuzzard_population then
            if mutatedbuzzard_population.current > 0 and not player:HasTag("playerghost") and not player.components.health:IsDead() then
                local num_current_buzzards = player._num_circling_buzzards or 0
                local num_to_spawn = math.min(mutatedbuzzard_population.current, 10 - num_current_buzzards)
                if num_to_spawn > 0 then
                    for i = 1, num_to_spawn do
                        SpawnBuzzardShadow(player)
                    end

                    mutatedbuzzard_population.current = mutatedbuzzard_population.current - num_to_spawn
                end
            end
        end

        if (player._find_corpse_cooldown or 0) <= 0 then
            local corpse = FindCorpse(player)
            if corpse ~= nil then
                for i, shadow in ipairs(_buzzardshadows) do
                    local mutatedbuzzardcircler = shadow.components.mutatedbuzzardcircler
                    if mutatedbuzzardcircler.circle_target == player then
                        SendBuzzardToCorpse(shadow, corpse)
                        break
                    end
                end
            end

            player._find_corpse_cooldown = 5 * FRAMES + math.random(10) * FRAMES
        else
            player._find_corpse_cooldown = player._find_corpse_cooldown - dt
        end
    end
end
self.LongUpdate = self.OnUpdate

function self:Debug_GetMigrationMap()
    return _migrationmap
end

function self:Debug_GetMigrationPopulations()
    return _migrationpopulations
end

function self:Debug_GetMigrationDistances()
    return _migrationdistances
end

function self:Debug_GetBirdEnemies()
    return _birdenemies
end

function self:Debug_IsNodeValidForMigration(id)
    return IsNodeValid(id)
end

function self:OnSave()
    local data, ents = {}, {}

    data.migrationmap = _migrationmap -- TODO should we save this??
    data.migrationpopulations = _migrationpopulations

    data.buzzard_shadow_valid_migration_nodes = {}
    for i, shadow in ipairs(_buzzardshadows) do
        local mutatedbuzzardcircler = shadow.components.mutatedbuzzardcircler
        if mutatedbuzzardcircler and mutatedbuzzardcircler.last_valid_migration_node then
            table.insert(data.buzzard_shadow_valid_migration_nodes, mutatedbuzzardcircler.last_valid_migration_node)
        end
    end

    if next(data) == nil then
        return nil, nil
    end

    return data, ents
end

function self:OnLoad(data)
    if data ~= nil then
        if data.migrationmap then
            _migrationmap = data.migrationmap
        end
        if data.migrationpopulations then
            _migrationpopulations = data.migrationpopulations
        end
        if data.buzzard_shadow_valid_migration_nodes then
            for i, node_name in ipairs(data.buzzard_shadow_valid_migration_nodes) do
                self:FillMigrationTaskWithType("mutatedbuzzard_gestalt", node_name, 1)
            end
        end
    end
end

function self:LoadPostPass(newents, savedata)

end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()

    return string.format("")
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------


end)