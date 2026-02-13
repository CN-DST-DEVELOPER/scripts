--------------------------------------------------------------------------
--[[ MigrationManager class definition ]]
--------------------------------------------------------------------------

-- NOTE: Migration here refers to the actual migration of creatures around the world. Not shard migration.
--[[
MigrationManager handles creating, managing and migrating population groups of creatures in the world in the 
migration map the component creates

Currently only Crystal-Crested Buzzards use this system; but we should totally do more with it!
]]

return Class(function(self, inst)

assert(TheWorld.ismastersim, "MigrationManager should not exist on client")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local UPDATE_TIME_SECONDS = 1 / 3

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _world = TheWorld
local _worldstate = _world.state
local _map = _world.Map

local _lastuid = -1 -- For population groups

local _activeplayers = {}
local _migrationtypes = {}

local _migrationmap = nil
local mapdistancecache = {}

--[[E.g.
["Forest"] =
{
    weight = 1,
    neighbours =
    {
        ["Savanha"] = true,
        ["Grassland"] = true,
        ["Desert"] = true,
    }
}
]]

local _migrationpopulations = {}

--[[E.g.
["mutatedbuzzard_gestalt"] =
{
    populations =
    {
        [uid] = {
            uid = 2,
            entities = {ent1, ent2, ent3, ent4},
            data = {
                weighted_nodes = { ["Forest"] = 1, ["MoonIsland_Shard"] = 20},
                current_node = "DeciduousBiome",
                migration_path = {"Forest", "MoonIsland_Shard", "LunarRiftBiome"},
                recently_visited_nodes = {"RockyBiome", "Badlands"} -- needed ?
                migrate_timer = 35.32,
            },
        },
    },
}
]]

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function CreateMigrationMapTable()
    return { weight = 0, neighbours = {} }
end

local function CreateMigratorPopulationsTable()
    return { populations = {} }
end

local function CreatePopulationGroupTable()
    return {
        uid = self:GetNewPopulationGroupUID(),
        entities = {},
        data =
        {
            current_node = nil,
            weighted_nodes = {},
            migration_path = {},
            recently_visited_nodes = {},
            migrate_timer = 0,
        },
    }
end

local function GetNodeFromTopologyID(id)
    local gen_data = ConvertTopologyIdToData(id)
    return gen_data.layout_id or gen_data.task_id or nil
end

local function IsNodeValid(id)
    return not id:find("COVE") and not id:find("BLOCKER_BLANK_") and not id:find("LOOP_BLANK")
end

local function IsNodeLinker(id)
    return id:find("REGION_LINK_SUB_")
end

local function AddNeighboringNodes(node_name_one, node_name_two)
    _migrationmap[node_name_one] = _migrationmap[node_name_one] or CreateMigrationMapTable()
    _migrationmap[node_name_two] = _migrationmap[node_name_two] or CreateMigrationMapTable()

    _migrationmap[node_name_one].neighbours[node_name_two] = true
    _migrationmap[node_name_two].neighbours[node_name_one] = true
end

local function RecurseNeighbours(node, searchednodes, neighboringnode)
    --
    _migrationmap[neighboringnode] = _migrationmap[neighboringnode] or CreateMigrationMapTable()

    for _, i in pairs(node.neighbours) do
        local id = _world.topology.ids[i]
        if not searchednodes[id] and IsNodeValid(id) then
            local neighbour_node = _world.topology.nodes[i]
            local node_name = GetNodeFromTopologyID(id)

            if node_name and neighboringnode and neighboringnode ~= node_name then
                AddNeighboringNodes(node_name, neighboringnode)
            end

            searchednodes[id] = true
            local next_neighbor = IsNodeLinker(id) and neighboringnode or node_name
            RecurseNeighbours(neighbour_node, searchednodes, next_neighbor)
        end
    end
end

local function RecurseMigrationMapNeighboursDistanceCache(node, neighbours, dist)
    local nextdist = dist + 1
    for neighbour in pairs(neighbours) do
        if neighbour ~= node and (dist < (mapdistancecache[node][neighbour] or math.huge)) then
            mapdistancecache[node][neighbour] = dist

            local nextneighours = _migrationmap[neighbour].neighbours
            RecurseMigrationMapNeighboursDistanceCache(node, nextneighours, nextdist)
        end
    end
end

local function InitializeMigrationMapFromTopology()
    if _migrationmap == nil then
        _migrationmap = {}
        for i, id in ipairs(_world.topology.ids) do
            local searchednodes = {} -- ["Task:0:Room"] = true
            if not IsNodeLinker(id) then
                RecurseNeighbours(_world.topology.nodes[i], searchednodes, GetNodeFromTopologyID(id))
            end
        end
    end

    for node, data in pairs(_migrationmap) do
        mapdistancecache[node] = {}

        local dist = 1
        RecurseMigrationMapNeighboursDistanceCache(node, data.neighbours, dist)
    end
end

local function FilterMaxPopulationsFn(migrator_type, population)
    return #population.entities < _migrationtypes[migrator_type].GetMaxGroupPopulation(population)
end

local function XYZHelper(x, y, z) -- for supporting (x, z), (x, y, z), and (Vector3)
    if y == nil and z == nil then
        return x:Get()
    elseif z == nil then
        return x, 0, y
    end

    return x, y, z
end

local function UnregisterMigratorEntity(ent)
    local uid = ent.migrationmanager_groupuid
    local group, migrator_type = self:GetPopulationGroup(uid)
    ent:ReturnToScene()
    ent.migrationmanager_groupuid = nil
    inst:RemoveEventCallback("onremove", UnregisterMigratorEntity, ent)
    table.removearrayvalue(group.entities, ent)

    if #group.entities <= 0 then
        self:ClearPopulationGroup(migrator_type, uid)
    end
end

local function RegisterMigratorEntity(ent, uid)
    local group = self:GetPopulationGroup(uid)
    ent:RemoveFromScene()
    ent.migrationmanager_groupuid = group.uid
    inst:ListenForEvent("onremove", UnregisterMigratorEntity, ent)
    table.insert(group.entities, ent)
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnPlayerJoined(src, player)
    _activeplayers[player] = self:GetMigrationNodeAtInst(player)
end

local function OnPlayerLeft(src, player)
    _activeplayers[player] = nil
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

--Initialize variables
for i, v in ipairs(AllPlayers) do
    OnPlayerJoined(inst, v)
end

--Register events
inst:ListenForEvent("ms_playerjoined", OnPlayerJoined, _world)
inst:ListenForEvent("ms_playerleft", OnPlayerLeft, _world)

--------------------------------------------------------------------------
--[[ Post initialization ]]
--------------------------------------------------------------------------

function self:OnPostInit()
    InitializeMigrationMapFromTopology()
    inst:StartUpdatingComponent(self)
end

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

function self:CreateMigrationType(migration_data)
    _migrationtypes[migration_data.type] = migration_data
    _migrationpopulations[migration_data.type] = CreateMigratorPopulationsTable()
end

function self:GetNewPopulationGroupUID()
	_lastuid = _lastuid + 1
	return _lastuid
end

-- Getters

function self:GetPlayerLocationList()
    return _activeplayers
end

function self:GetMigrationNodeAtPoint(x, y, z)
    x, y, z = XYZHelper(x, y, z)

    local node, node_index = _map:FindNodeAtPoint(x, y, z) --_map:FindVisualNodeAtPoint(x, y, z)
    if node == nil then
        return nil
    end

    local idname = _world.topology.ids[node_index]
    return GetNodeFromTopologyID(idname)
end

function self:GetMigrationNodeAtInst(inst)
    return self:GetMigrationNodeAtPoint(inst.Transform:GetWorldPosition())
end

function self:GetDistanceNodeToNode(node1, node2)
    if node1 ~= nil and node2 ~= nil and node1 == node2 then
        return 0
    end
    return mapdistancecache[node1] ~= nil and mapdistancecache[node1][node2] or nil
end

function self:GetPopulationGroup(uid)
    for migrator_type, v in pairs(_migrationpopulations) do
        local group = v.populations[uid]
        if group ~= nil then
            return group, migrator_type
        end
    end
end

function self:GetFirstPopulationGroupInNode(migrator_type, node, filterfn)
    for uid, population in pairs(_migrationpopulations[migrator_type].populations) do
        if population.data.current_node == node
            and (filterfn == nil or filterfn(migrator_type, population)) then
            return uid
        end
    end
end

function self:GetEntityFromMigrationNode(migrator_type, node)
    for uid, population in pairs(_migrationpopulations[migrator_type].populations) do
        for i, ent in ipairs(population.entities) do
            self:RemoveEntityFromPopulationGroup(ent)
            return ent
        end
    end
end

function self:ForEachEntityInMigration(migrator_type, cb)
    local exit = false
    for uid, population in pairs(_migrationpopulations[migrator_type].populations) do
        if exit then
            break
        end
        for i, ent in ipairs(population.entities) do
            local stop = cb(ent, population)
            if stop then
                exit = true
                break
            end
        end
    end
    return exit
end

function self:GetPopulationForNodeAtPoint(migrator_type, x, y, z)
    x, y, z = XYZHelper(x, y, z)
    local node = self:GetMigrationNodeAtPoint(x, y, z)
    local c = 0
    for uid, population in pairs(_migrationpopulations[migrator_type].populations) do
        if node == population.data.current_node then
            c = c + #population.entities
        end
    end
    return c
end

function self:GetPopulationForNodeAtInst(migrator_type, inst)
    return self:GetPopulationForNodeAtPoint(migrator_type, inst.Transform:GetWorldPosition())
end

function self:ShouldPopulationGroupMigrate(migration_data, population)
    migration_data = type(migration_data) == "string" and _migrationtypes[migration_data] or migration_data -- support pass migrator type

    if migration_data.CanPopulationGroupMigrate then
        return migration_data.CanPopulationGroupMigrate(population)
    end

    return #population.entities > 0
end

-- Setters

function self:CreatePopulationGroup(migrator_type, spawnnode)
    local population = CreatePopulationGroupTable()
    local uid = population.uid

    population.data.migrate_timer = _migrationtypes[migrator_type].GetMigrateTime()
    population.data.current_node = spawnnode
    _migrationpopulations[migrator_type].populations[uid] = population

    return uid
end

function self:ClearPopulationGroup(migrator_type, uid)
    _migrationpopulations[migrator_type].populations[uid] = nil
end

function self:RemoveEntityFromPopulationGroup(ent)
    if not ent.migrationmanager_groupuid then
        return false
    end

    local popgroup = self:GetPopulationGroup(ent.migrationmanager_groupuid)
    if not popgroup then
        return false
    end

    UnregisterMigratorEntity(ent)
    return true
end

function self:AddEntityToPopulationGroup(group_uid, ent)
    if ent.migrationmanager_groupuid ~= nil then -- Already in a group
        return false
    end

    local popgroup = self:GetPopulationGroup(group_uid)
    if not popgroup then
        return false
    end

    RegisterMigratorEntity(ent, group_uid)
    return true
end

function self:EnterMigrationInNode(migrator_type, ent, node)
    local popgroupuid = self:GetFirstPopulationGroupInNode(migrator_type, node, FilterMaxPopulationsFn) or self:CreatePopulationGroup(migrator_type, node)
    self:AddEntityToPopulationGroup(popgroupuid, ent)
end

function self:EnterMigration(migrator_type, ent) -- decides whether to join a existing group or create a new one at position
    local node = self:GetMigrationNodeAtInst(ent)
    if not node then
        return
    end

    local popgroupuid = self:GetFirstPopulationGroupInNode(migrator_type, node, FilterMaxPopulationsFn) or self:CreatePopulationGroup(migrator_type, node)
    self:AddEntityToPopulationGroup(popgroupuid, ent)
end

function self:ClearAllPopulationGroupMigrationPaths(migrator_type)
    for uid, population in pairs(_migrationpopulations[migrator_type].populations) do
        population.data.migration_path = {}
    end
end

function self:MigratePopulationToNode(migration_data, population, node)
    migration_data = type(migration_data) == "string" and _migrationtypes[migration_data] or migration_data -- support pass migrator type

    if population.data.migration_path[1] == node then
        self:MigratePopulationToNextNode(migration_data, population)
        return
    end

    table.insert(population.data.recently_visited_nodes, population.data.current_node)
    population.data.current_node = node
    population.data.migrate_timer = migration_data.GetMigrateTime()
    population.data.migration_path = {} -- Clear our migration path, cuz we didn't go to the next one in it anyways

    if #population.data.recently_visited_nodes > migration_data.num_path_nodes then
        table.remove(population.data.recently_visited_nodes, 1)
    end
end

function self:MigratePopulationToNextNode(migration_data, population)
    migration_data = type(migration_data) == "string" and _migrationtypes[migration_data] or migration_data -- support pass migrator type

    -- We have no migration path, this can happen in a disconnected node. So just retry the timer I guess.
    if #population.data.migration_path <= 0 then
        population.data.migrate_timer = migration_data.GetMigrateTime()
        return
    end

    local next_node = table.remove(population.data.migration_path, 1)
    table.insert(population.data.recently_visited_nodes, population.data.current_node)
    population.data.current_node = next_node
    population.data.migrate_timer = migration_data.GetMigrateTime()

    if #population.data.recently_visited_nodes > migration_data.num_path_nodes then
        table.remove(population.data.recently_visited_nodes, 1)
    end
end

function self:UpdatePopulationMigrationPath(migration_data, population)
    if migration_data.UpdatePopulationMigrationPath then
        migration_data.UpdatePopulationMigrationPath(population, _migrationmap)
    else
        local lastnode = population.data.migration_path[#population.data.migration_path] or population.data.current_node
        local randomneighbour = shuffledKeys(_migrationmap[lastnode].neighbours)[1]
        table.insert(population.data.migration_path, randomneighbour)
    end
end

--------------------------------------------------------------------------
--[[ Update ]]
--------------------------------------------------------------------------

function self:DoUpdatePlayerLocations()
    for player in pairs(_activeplayers) do
        _activeplayers[player] = self:GetMigrationNodeAtInst(player)
    end
end

function self:DoUpdateMigrate(dt)
    for migrator_type, v in pairs(_migrationpopulations) do
        local migration_data = _migrationtypes[migrator_type]
        for uid, population in pairs(v.populations) do
            -- Migration timers
            if population.data.migrate_timer <= 0 then
                self:MigratePopulationToNextNode(migration_data, population)
            end

            if self:ShouldPopulationGroupMigrate(migration_data, population) then
                population.data.migrate_timer = population.data.migrate_timer - dt * migration_data.GetMigrateTimeMult()
            end

            -- Migration path
            if #population.data.migration_path < migration_data.num_path_nodes then
                self:UpdatePopulationMigrationPath(migration_data, population)
            end
        end
    end
end

local t = GetTime()
local update_accumulation = 0
function self:OnUpdate(dt)
    update_accumulation = update_accumulation + dt
    if update_accumulation < UPDATE_TIME_SECONDS then
        return
    end
    update_accumulation = 0

    --- Real time that has passed since last update
    local current_time = GetTime()
	dt = current_time - t
	t = current_time
    ---

    self:DoUpdatePlayerLocations() -- Set where the players are at.
    self:DoUpdateMigrate(dt) -- Do migration
end

--------------------------------------------------------------------------
--[[ Save / Load ]]
--------------------------------------------------------------------------

function self:OnSave()
    local data, ents = { migrationpopulations = {}, lastuid = _lastuid }, {}

    for migrator, v in pairs(_migrationpopulations) do
        data.migrationpopulations[migrator] = {}
        for uid, population in pairs(v.populations) do
            local popsavedata = { uid = population.uid, entity_guids = {}, data = population.data }

            for _, ent in ipairs(population.entities) do
                table.insert(popsavedata.entity_guids, ent.GUID)
                table.insert(ents, ent.GUID)
            end

            table.insert(data.migrationpopulations[migrator], popsavedata)
        end
    end

    return data, ents
end

function self:OnLoad(data)
    if data ~= nil then
        if data.migrationpopulations ~= nil then
            for migrator, populations in pairs(data.migrationpopulations) do
                for i, population in pairs(populations) do
                    _migrationpopulations[migrator].populations[population.uid] =
                    {
                        uid = population.uid,
                        entities = {},
                        data = population.data,
                    }
                end
            end
        end

        if data.lastuid ~= nil then
            _lastuid = data.lastuid
        end
    end
end

function self:LoadPostPass(newents, savedata)
    if savedata ~= nil then
        if savedata.migrationpopulations ~= nil then
            for migrator, populations in pairs(savedata.migrationpopulations) do
                for _, popdata in pairs(populations) do
                    for _, guid in ipairs(popdata.entity_guids) do
                        local ent = newents[guid]
                        if ent ~= nil then
                            RegisterMigratorEntity(ent.entity, popdata.uid)
                        end
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:Debug_GetMigrationMap()
    return _migrationmap
end

function self:Debug_GetMigrationPopulations()
    return _migrationpopulations
end

function self:Debug_IsNodeValidForMigration(id)
    return IsNodeValid(id)
end

function self:GetDebugString()
    return string.format("")
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------


end)