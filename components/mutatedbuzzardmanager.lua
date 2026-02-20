--------------------------------------------------------------------------
--[[ MutatedBuzzardManager class definition ]]
--------------------------------------------------------------------------

local rift_portal_defs = require("prefabs/rift_portal_defs")
local RIFTPORTAL_CONST = rift_portal_defs.RIFTPORTAL_CONST
rift_portal_defs = nil

--[[
MutatedBuzzardManager works in conjunction with corpsepersistmanager and migrationmanager
Handles tracking populations from migrationmanager on players and spawning the shadows
Handles adding a corpse persist source and creating the migration type
]]

return Class(function(self, inst)

assert(TheWorld.ismastersim, "MutatedBuzzardManager should not exist on client")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local UPDATE_TIME_SECONDS = 1 / 2
local UPDATE_DROP_BUZZARD_SECONDS = 3

local CORPSE_PERSIST_SOURCE = "mutatedbuzzard_corpse_persist"

local RIFT_BIRD_MIGRATE_TIME_MOONPHASE_FACTOR = TUNING.RIFT_BIRD_MIGRATE_TIME_MOONPHASE_FACTOR
local RIFT_BIRD_MIGRATE_TIME_NON_NIGHT_FACTOR = TUNING.RIFT_BIRD_MIGRATE_TIME_NON_NIGHT_FACTOR

local MUTATEDBUZZARD_MIGRATE_TIME_BASE = TUNING.MUTATEDBUZZARD_MIGRATE_TIME_BASE
local MUTATEDBUZZARD_MIGRATE_TIME_VAR = TUNING.MUTATEDBUZZARD_MIGRATE_TIME_VAR

local MUTATEDBUZZARD_CORPSE_RANGE = TUNING.MUTATEDBUZZARD_CORPSE_RANGE
local MUTATEDBUZZARD_CORPSE_RANGE_SQ = MUTATEDBUZZARD_CORPSE_RANGE * MUTATEDBUZZARD_CORPSE_RANGE

local MUTATEDBUZZARD_MAX_SHADOWS = 10

local DROP_BUZZARDS_REASONS =
{
    RIFT_INACTIVE = "rift_inactive",
    WINTER = "winter_active",
}

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _world = TheWorld
local _worldstate = _world.state
local _migrationmanager = _world.components.migrationmanager
local _riftspawner = _world.components.riftspawner
local _map = _world.Map

local _activeplayers = {}
local _buzzards = {}
local _buzzardshadows = {}

local _dropbuzzardsources = SourceModifierList(inst, false, SourceModifierList.boolean)

local migrationnode_weights = {} -- ["Forest"] = 10,

local lunarrifts_nodes = {} -- [rift] = "Forest",
local megaflare_nodes = {} -- ["Forest"] = 23.53, -- time left for distraction
local death_nodes = {} -- ["Forest"] = {10.32, 60.33},

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function CreatePlayerDataTable(player)
    return { player = player, population_uid = nil, population_time = nil }
end

local function UnregisterBuzzardShadow(shadow)
	for i, v in ipairs(_buzzardshadows) do
		if v == shadow then
			table.remove(_buzzardshadows, i)
            if shadow:IsValid() then
                inst:RemoveEventCallback("onremove", UnregisterBuzzardShadow, shadow)
                inst:RemoveEventCallback("shadowkilled", UnregisterBuzzardShadow, shadow)
            end
			return
		end
	end
end

local function RegisterBuzzardShadow(shadow)
    table.insert(_buzzardshadows, shadow)
    inst:ListenForEvent("onremove", UnregisterBuzzardShadow, shadow)
    inst:ListenForEvent("shadowkilled", UnregisterBuzzardShadow, shadow)
end

local buzzard_OnRemove
local shadow_OnRemove

shadow_OnRemove = function(shadow)
    local buzzard = shadow.buzzard
    if buzzard then
        buzzard:RemoveEventCallback("onremove", buzzard_OnRemove)
        buzzard.shadow = nil
    end
end

buzzard_OnRemove = function(buzzard)
    local shadow = buzzard.shadow
    if shadow then
        shadow:RemoveEventCallback("onremove", shadow_OnRemove)
        shadow.buzzard = nil
    end
end

local function SpawnBuzzardShadow(player, buzzard)
    local shadow = SpawnPrefab("circlingbuzzard_lunar")
    RegisterBuzzardShadow(shadow)
    shadow.components.mutatedbuzzardcircler:SetCircleTarget(player)
    shadow.components.mutatedbuzzardcircler:Start()

    if shadow:IsValid() then -- shadow could have been removed from circler:Start call
        buzzard.shadow = shadow
        shadow.buzzard = buzzard

        shadow:ListenForEvent("onremove", shadow_OnRemove)
        buzzard:ListenForEvent("onremove", buzzard_OnRemove)
    end
end

local function FilterPopulationFn(migrator_type, population)
    local i, ent = next(population.entities)
    return ent ~= nil and (not ent.shadow or not ent.shadow:IsValid())
end

local function GetRandomPlayerInNode(node)
    local players = {}
    for player, data in pairs(_migrationmanager:GetPlayerMigrationData()) do
        if data.migration_node and data.migration_node == node then
            table.insert(players, player)
        end
    end
    shuffleArray(players)
    return #players > 0 and players[math.random(#players)] or nil
end

local function TryDropBuzzard(ent, population)
    if ent.shadow and ent.shadow:IsValid() then
        ent.shadow.components.mutatedbuzzardcircler:DropBuzzard()
        ent.shadow = nil
    elseif ent:IsValid() then
        local player = GetRandomPlayerInNode(population.data.current_node)
        if player then
            SpawnBuzzardShadow(player, ent)
            ent.shadow.components.mutatedbuzzardcircler:DropBuzzard()
            ent.shadow = nil
        else
            ent:Remove()
        end
    end
    return true -- return true to stop iteration in ForEachEntityInMigration
end

local function TrySpawnBuzzardShadows(player, population)
    for i, ent in ipairs(population.entities) do
        if not ent.shadow or not ent.shadow:IsValid() then
            if (player._num_circling_buzzards or 0) < MUTATEDBUZZARD_MAX_SHADOWS then
                SpawnBuzzardShadow(player, ent)
            end
        end
    end
end

local function ClearBuzzardShadows(population)
    for i, ent in ipairs(population.entities) do
        if ent.shadow and ent.shadow:IsValid() then
            ent.shadow:KillShadow()
        end
    end
end

local function AnyBuzzardInRange(x, y, z)
    for i, buzzard in ipairs(_buzzards) do
        if buzzard:GetDistanceSqToPoint(x, y, z) <= MUTATEDBUZZARD_CORPSE_RANGE_SQ then
            return true
        end
    end

    for i, buzzard in ipairs(_buzzardshadows) do
        if buzzard:GetDistanceSqToPoint(x, y, z) <= MUTATEDBUZZARD_CORPSE_RANGE_SQ then
            return true
        end
    end

    return false
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnPlayerJoined(src, player)
    _activeplayers[player] = CreatePlayerDataTable(player)
end

local function OnPlayerLeft(src, player)
    _activeplayers[player] = nil
end

local function UnregisterMutatedBuzzard(buzzard)
    for i, v in ipairs(_buzzards) do
		if v == buzzard then
			table.remove(_buzzards, i)
            if buzzard:IsValid() then
                inst:RemoveEventCallback("onremove", UnregisterMutatedBuzzard, buzzard)
                inst:RemoveEventCallback("death", UnregisterMutatedBuzzard, buzzard)
            end
			return
		end
	end
end

local function RegisterMutatedBuzzard(inst, buzzard)
	table.insert(_buzzards, buzzard)
	inst:ListenForEvent("onremove", UnregisterMutatedBuzzard, buzzard)
	inst:ListenForEvent("death", UnregisterMutatedBuzzard, buzzard)
end

local function OnMegaFlareDetonated(src, data)
    if not data or not data.sourcept then
        return
    end

    local node = _migrationmanager:GetMigrationNodeAtPoint(data.sourcept)
    if not node then
        return
    end

    megaflare_nodes[node] = TUNING.MUTATEDBUZZARD_MEGAFLARE_TIME
    -- TODO, clear migration paths for buzzard groups.
end

local function OnEntityDeath(src, data)
    local deadinst = data ~= nil and data.inst or nil
    if not deadinst then
        return
    end

    local x, y, z = deadinst.Transform:GetWorldPosition()
    local node = _migrationmanager:GetMigrationNodeAtPoint(x, y, z)
    if not node then
        return
    end

    if not EntityHasCorpse(deadinst) then -- We only want to attract if we actually have a corpse
        return
    end

    death_nodes[node] = death_nodes[node] or {}
    table.insert(death_nodes[node], TUNING.MUTATEDBUZZARD_DEATHATTRACTION_TIME)
end

local function OnRiftStateUpdate()
    local riftspawner = _world.components.riftspawner
    self:SetDropBuzzardsSource(DROP_BUZZARDS_REASONS.RIFT_INACTIVE, riftspawner and not riftspawner:IsLunarPortalActive())
end

local function OnRiftAddedToPool(src, data)
    local rift = data ~= nil and data.rift or nil
    if rift then
        lunarrifts_nodes[rift] = _migrationmanager:GetMigrationNodeAtInst(rift)
    end
    OnRiftStateUpdate()
end

local function OnRiftRemovedFromPool(src, data)
    local rift = data ~= nil and data.rift or nil
    if rift then
        lunarrifts_nodes[rift] = nil
    end
    OnRiftStateUpdate()
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

inst:ListenForEvent("ms_registermutatedbuzzard", RegisterMutatedBuzzard, _world)
inst:ListenForEvent("megaflare_detonated", OnMegaFlareDetonated, _world)

inst:ListenForEvent("entity_death", OnEntityDeath, _world)

if _riftspawner ~= nil then
    inst:ListenForEvent("ms_riftaddedtopool", OnRiftAddedToPool, _world)
    inst:ListenForEvent("ms_riftremovedfrompool", OnRiftRemovedFromPool, _world)
end

-- Initialize in migrationmanager
_migrationmanager:CreateMigrationType({
    type = MIGRATION_TYPES.MUTATED_BUZZARD_GESTALT,

    num_path_nodes = 5, -- 5 nodes in the migration path
    UpdatePopulationMigrationPath = function(population, map)
        -- TODO just choosing a random neighbour node to travel to, not good!
        --  be smarter on where we want to go!
        -- megaflare_nodes
        -- lunarrifts_nodes
        -- death_nodes
        local lastnode = population.data.migration_path[#population.data.migration_path] or population.data.current_node

        local alreadyvisitedorgoingto = {}
        for i, neighbour in ipairs(shuffledKeys(map[lastnode].neighbours)) do
            if table.contains(population.data.recently_visited_nodes, neighbour)
                or table.contains(population.data.migration_path, neighbour) then
                table.insert(alreadyvisitedorgoingto, neighbour)
            else
                table.insert(population.data.migration_path, neighbour)
                return
            end
        end

        -- We already recently visited all these apparently, just pick one.
        if #alreadyvisitedorgoingto > 0 then
            table.insert(population.data.migration_path, alreadyvisitedorgoingto[math.random(#alreadyvisitedorgoingto)])
        end
    end,
    GetMaxGroupPopulation = function()
        return 10
    end,

    CanPopulationGroupMigrate = function(population)
        for player, data in pairs(_activeplayers) do
            -- This population is following the player.
            if data.population_uid == population.uid then
                return false
            end
        end
        return true
    end,

    GetMigrateTimeMult = function()
        local mult = 1

        if not _worldstate.isnight then
            mult = mult * RIFT_BIRD_MIGRATE_TIME_NON_NIGHT_FACTOR
        end

        -- We follow the moon!
        mult = mult * RIFT_BIRD_MIGRATE_TIME_MOONPHASE_FACTOR[TheWorld.state.moonphase]

        return mult
    end,

    GetMigrateTime = function()
        return MUTATEDBUZZARD_MIGRATE_TIME_BASE + math.random() * MUTATEDBUZZARD_MIGRATE_TIME_VAR
    end,

    GetWeightedMigrationNodes = function()
        return migrationnode_weights
    end,
})

--------------------------------------------------------------------------
--[[ Post initialization ]]
--------------------------------------------------------------------------

local function CorpsePersistFn(corpse) -- corpse param can also be a creature as it died.
    if corpse:IsOnOcean(true) then
        return false
    end

    -- exclude really tiny insects like bees
    if corpse:HasTag("insect") and corpse:HasAnyTag("smallcreature", "smallcreaturecorpse") then
        return false
    end

    if corpse:HasTag("buzzard") then
        return false
    end

    return _migrationmanager:GetPopulationForNodeAtInst(MIGRATION_TYPES.MUTATED_BUZZARD_GESTALT, corpse) > 0
        or AnyBuzzardInRange(corpse.Transform:GetWorldPosition())
end

function self:OnPostInit()
    inst:StartUpdatingComponent(self)

    local rifts = _riftspawner ~= nil and _riftspawner:GetRiftsOfAffinity(RIFTPORTAL_CONST.AFFINITY.LUNAR) or nil
    if rifts ~= nil then
        for i, rift in ipairs(rifts) do
            OnRiftAddedToPool(_world, { rift = rift })
        end
    end
    OnRiftStateUpdate()

    local corpsepersistmanager = _world.components.corpsepersistmanager
    if corpsepersistmanager ~= nil then
        corpsepersistmanager:AddPersistSourceFn(CORPSE_PERSIST_SOURCE, CorpsePersistFn)
    end
end

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

function self:SetDropBuzzardsSource(source, boolval) -- Start dropping them on update
    _dropbuzzardsources:SetModifier(source, boolval)
end

function self:GetDropBuzzards()
    return _dropbuzzardsources:Get()
end

function self:TrackPopulationOnPlayer(player, population)
    local playerdata = _activeplayers[player]
    playerdata.population_uid = population.uid
    playerdata.population_time = TUNING.TOTAL_DAY_TIME
end

function self:ClearPopulationTracking(player)
    local playerdata = _activeplayers[player]
    local population, migrator_type = _migrationmanager:GetPopulationGroup(playerdata.population_uid)
    playerdata.population_uid = nil
    playerdata.population_time = nil

    if population ~= nil then
        _migrationmanager:MigratePopulationToNextNode(migrator_type, population)
        ClearBuzzardShadows(population)
    end
end

--------------------------------------------------------------------------
--[[ Update ]]
--------------------------------------------------------------------------

local update_accumulation = 0
local drop_buzzard_update_accumulation = 0
function self:UpdateTimers(dt)
    update_accumulation = update_accumulation + dt
    drop_buzzard_update_accumulation = drop_buzzard_update_accumulation + dt
    for node, time in pairs(megaflare_nodes) do
        megaflare_nodes[node] = time - dt
        if megaflare_nodes[node] <= 0 then
            megaflare_nodes[node] = nil
        end
    end

    for node, timers in pairs(death_nodes) do
        for i, time in ipairs(timers) do
            timers[i] = time - dt
        end

        for i, time in ipairs(timers) do
            while time ~= nil and time <= 0 do
                table.remove(timers, i)
                time = timers[i]
            end
        end
    end

    for player, data in pairs(_activeplayers) do
        if data.population_time then
            data.population_time = data.population_time - dt
            if data.population_time <= 0 then
                self:ClearPopulationTracking(player)
            end
        end
    end
end

function self:OnUpdate(dt)
    self:UpdateTimers(dt)
    if update_accumulation < UPDATE_TIME_SECONDS then
        return
    end
    update_accumulation = 0
    --
    local do_drop_buzzard = _dropbuzzardsources:Get()

    -- Kill them!
    if do_drop_buzzard then
        if drop_buzzard_update_accumulation >= UPDATE_DROP_BUZZARD_SECONDS then
            drop_buzzard_update_accumulation = 0
            _migrationmanager:ForEachEntityInMigration(MIGRATION_TYPES.MUTATED_BUZZARD_GESTALT, TryDropBuzzard)
        end
        return
    end

    -- Send buzzards
    for player, data in pairs(_migrationmanager:GetPlayerMigrationData()) do
        local node = data.migration_node
        if _activeplayers[player].population_uid then

            local invalid_uid = node == nil
            local population = _migrationmanager:GetPopulationGroup(_activeplayers[player].population_uid)
            if population then
                if population.data.current_node ~= node then
                    local mapdist = _migrationmanager:GetDistanceNodeToNode(population.data.current_node, node)
                    if mapdist and mapdist <= 1 then
                        _migrationmanager:MigratePopulationToNode(MIGRATION_TYPES.MUTATED_BUZZARD_GESTALT, population, node)
                    else
                        -- mapdist doesn't exist or it's too far, invalid.
                        invalid_uid = true
                    end
                end
                if not invalid_uid then
                    TrySpawnBuzzardShadows(player, population)
                end
            else
                invalid_uid = true
            end

            if invalid_uid then
                self:ClearPopulationTracking(player)
            end

        elseif node then

            local population_uid = _migrationmanager:GetFirstPopulationGroupInNode(MIGRATION_TYPES.MUTATED_BUZZARD_GESTALT, node, FilterPopulationFn)
            if population_uid then
                local population = _migrationmanager:GetPopulationGroup(population_uid)
                if population then
                    self:TrackPopulationOnPlayer(player, population)
                    TrySpawnBuzzardShadows(player, population)
                end
            end

        end

    end
end

--------------------------------------------------------------------------
--[[ Save / Load ]]
--------------------------------------------------------------------------

function self:OnSave()
    local data, ents = {}, {}

    data.megaflare_nodes = megaflare_nodes
    data.death_nodes = death_nodes

    if next(data) == nil then
        return nil, nil
    end

    return data, ents
end

function self:OnLoad(data)
    if data ~= nil then
        if data.megaflare_nodes ~= nil then
            megaflare_nodes = data.megaflare_nodes
        end

        if data.death_nodes ~= nil then
            death_nodes = data.death_nodes
        end
    end
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:Debug_GetPlayerData()
    return _activeplayers
end

function self:GetDebugString()
    return string.format("")
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------


end)