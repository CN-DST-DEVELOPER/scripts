--------------------------------------------------------------------------
--[[ Rift Spawner class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "Rift Spawner should not exist on client")

--------------------------------------------------------------------------
--[[ Dependencies ]]
--------------------------------------------------------------------------

local _worldsettingstimer = TheWorld.components.worldsettingstimer

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local RIFTSPAWN_TIMERNAME = "rift_spawn_timer"
local MINIMUM_DSQ_FROM_PREVIOUS_RIFT = 10000

local SPAWN_DISSUADE_CANT_TAGS = {"DECOR", "FX", "NOCLICK", "INLIMBO"}
local SPAWN_DISSUADE_ONEOF_TAGS = {"antlion_sinkhole_blocker", "king", "structure"}
local SPAWN_DISSUADE_COUNT, SPAWN_DISSUADE_RADIUS = 1, 5*TILE_SCALE
local SPAWN_SEARCH_START_DISTANCE, SPAWN_SEARCH_LENGTH, SPAWN_SEARCH_STEP = 10, 10, 2

local MAX_PREVIOUS_PORTAL_TRACK_COUNT = 6
local HALF_MAX_PREVIOUS_PORTAL_TRACK_COUNT = MAX_PREVIOUS_PORTAL_TRACK_COUNT / 2

--------------------------------------------------------------------------
--[[ Public member variables ]]
--------------------------------------------------------------------------

self.inst = inst

--------------------------------------------------------------------------
--[[ Private member variables ]]
--------------------------------------------------------------------------

local _map = TheWorld.Map

-- SPAWN MODES
--  1: never
--  2: rare
--  3: default
--  4: often
--  5: always
local _spawnmode = 3
local _lunar_rifts_enabled = false

local _rifts = {}
local _previous_spawn_xs = {}
local _previous_spawn_zs = {}

local _spawn_check_directions = {
    {1, 1}, {1, 0}, {1, -1},
    {0, 1}, {0, -1},
    {-1, 1}, {-1, 0}, {-1, -1}
}

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------
local function is_point_near_previous_spawn(x, z)
    for i = 1, #_previous_spawn_xs do
        if distsq(x, z, _previous_spawn_xs[i], _previous_spawn_zs[i]) < MINIMUM_DSQ_FROM_PREVIOUS_RIFT then
            return true
        end
    end

    return false
end

local function get_next_rift_location()
    local spawn_x, spawn_z

    local previous_rifts_count = #_previous_spawn_xs
    if previous_rifts_count == 0 then
        local map_width, map_height = _map:GetSize()
        map_width = (map_width/2) * TILE_SCALE
        map_height = (map_height/2) * TILE_SCALE

        local half_width, half_height = map_width/2, map_height/2
        for _ = 1, 10 do
            local x, y, z = _map:GetTileCenterPoint(
                (2*math.random() - 1)*half_width,
                0,
                (2*math.random() - 1)*half_height
            )
            if not is_point_near_previous_spawn(x, z) and not _map:IsOceanAtPoint(x, 0, z, false) then
                local point_exists, _tx, _tz = _map:GetNearestPointOnWater(x, z, 1.5 * TILE_SCALE, 1)
                if not point_exists then
                    local nearby_objects = TheSim:FindEntities(x, y, z, SPAWN_DISSUADE_RADIUS, nil, SPAWN_DISSUADE_CANT_TAGS, SPAWN_DISSUADE_ONEOF_TAGS)
                    if #nearby_objects < SPAWN_DISSUADE_COUNT then
                        spawn_x, spawn_z = x, z
                        break
                    end
                end
            end
        end
    else
        local last_portal_h, last_portal_v = _map:GetTileCoordsAtPoint(_previous_spawn_xs[previous_rifts_count], 0, _previous_spawn_zs[previous_rifts_count])
        local map_side_random = math.random()
        local search_tile_h = (map_side_random < 0.66 and -last_portal_h) or last_portal_h
        local search_tile_v = (map_side_random > 0.33 and -last_portal_v) or last_portal_v

        local shuffled_directions = shuffleArray(_spawn_check_directions)
        for _, direction in ipairs(shuffled_directions) do
            for i = SPAWN_SEARCH_START_DISTANCE, SPAWN_SEARCH_LENGTH do
                local test_tile_h = search_tile_h + (SPAWN_SEARCH_STEP * i * TILE_SCALE * direction[1])
                local test_tile_v = search_tile_v + (SPAWN_SEARCH_STEP * i * TILE_SCALE * direction[2])
                local x, y, z = _map:GetTileCenterPoint(test_tile_h, 0, test_tile_v)

                -- Give up on this direction if we hit water.
                -- Being near water or near a previous portal is something we can "recover" from
                -- by continuing, but hitting water means we might risk crossing the water to an island.
                if _map:IsOceanAtPoint(x, 0, z, false) then
                    break
                end

                if not is_point_near_previous_spawn(x, z) and not _map:IsSurroundedByWater(x, 0, z, 2*TILE_SCALE) then
                    local nearby_objects = TheSim:FindEntities(x, y, z, SPAWN_DISSUADE_RADIUS, nil, SPAWN_DISSUADE_CANT_TAGS, SPAWN_DISSUADE_ONEOF_TAGS)
                    if #nearby_objects < SPAWN_DISSUADE_COUNT then
                        spawn_x, spawn_z = x, z
                        break
                    end
                end
            end

            if spawn_x then
                break
            end
        end
    end

    return spawn_x, spawn_z
end

local function track_spawn_location(spawn_x, spawn_z)
    table.insert(_previous_spawn_xs, spawn_x)
    table.insert(_previous_spawn_zs, spawn_z)

    -- If we reached our max portal track count, chop out the earlier half, so we can spawn near those locations again.
    if #_previous_spawn_xs == MAX_PREVIOUS_PORTAL_TRACK_COUNT then
        for i = 1, HALF_MAX_PREVIOUS_PORTAL_TRACK_COUNT do
            _previous_spawn_xs[i] = _previous_spawn_xs[i + HALF_MAX_PREVIOUS_PORTAL_TRACK_COUNT]
            _previous_spawn_zs[i] = _previous_spawn_zs[i + HALF_MAX_PREVIOUS_PORTAL_TRACK_COUNT]
        end

        for i = HALF_MAX_PREVIOUS_PORTAL_TRACK_COUNT + 1, MAX_PREVIOUS_PORTAL_TRACK_COUNT do
            _previous_spawn_xs[i] = nil
            _previous_spawn_zs[i] = nil
        end
    end
end

local function get_next_rift_type()
    return "lunarrift_portal"
end

local function on_rift_removed(rift)
    _rifts[rift] = nil

    -- If we can spawn rifts, and a timer isn't already counting down...
    if _spawnmode ~= 1 and not _worldsettingstimer:ActiveTimerExists(RIFTSPAWN_TIMERNAME) then
        -- AND our max rift count can support another rift, start the timer to spawn a new one!
        local num_rifts = GetTableSize(_rifts)
        if num_rifts < TUNING.MAXIMUM_RIFTS_COUNT then
            _worldsettingstimer:StartTimer(RIFTSPAWN_TIMERNAME, TUNING.RIFTS_SPAWNDELAY)
        end
    end
end


local function AddRiftToPool(rift, rift_prefab)
    _rifts[rift] = rift_prefab
    self.inst:ListenForEvent("onremove", on_rift_removed, rift)
end


local function SpawnRift(pos)
    local spawn_x, spawn_z = get_next_rift_location()

    if pos then 
        spawn_x = pos.x
        spawn_z = pos.z
    end
    if not spawn_x then
        return
    end


    track_spawn_location(spawn_x, spawn_z)

    local rift_type = get_next_rift_type()
    local rift = SpawnPrefab(rift_type)
    rift.Transform:SetPosition(spawn_x, 0, spawn_z)
    AddRiftToPool(rift, rift_type)

    return rift
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnRiftTimerDone()
    if _spawnmode == 1 then
        return
    end

    local num_rifts = GetTableSize(_rifts)
    if num_rifts < TUNING.MAXIMUM_RIFTS_COUNT then
        local spawned_rift = SpawnRift()

        -- If we failed to spawn a rift, but know we can support more,
        -- try again in a relatively short time period.
        if not spawned_rift then
            _worldsettingstimer:StartTimer(RIFTSPAWN_TIMERNAME, TUNING.TOTAL_DAY_TIME)
        elseif (num_rifts + 1) < TUNING.MAXIMUM_RIFTS_COUNT then
            _worldsettingstimer:StartTimer(RIFTSPAWN_TIMERNAME, TUNING.RIFTS_SPAWNDELAY)
        end
    end
end

local function SetDifficulty(src, difficulty)
	if difficulty == "never" then
		_spawnmode = 1
        _worldsettingstimer:StopTimer(RIFTSPAWN_TIMERNAME)
	else
        if difficulty == "rare" then
		    _spawnmode = 2
        elseif difficulty == "default" then
            _spawnmode = 3
        elseif difficulty == "often" then
            _spawnmode = 4
        elseif difficulty == "always" then
            _spawnmode = 5
        end

        if _worldsettingstimer:ActiveTimerExists(RIFTSPAWN_TIMERNAME) then
            local new_time = math.min(
                _worldsettingstimer:GetTimeLeft(RIFTSPAWN_TIMERNAME),
                TUNING.RIFTS_SPAWNDELAY
            )
            _worldsettingstimer:SetTimeLeft(RIFTSPAWN_TIMERNAME, new_time)
        end
	end
end

local function EnableLunarRifts(src)
    _lunar_rifts_enabled = true

    if _spawnmode ~= 1 and not _worldsettingstimer:ActiveTimerExists(RIFTSPAWN_TIMERNAME) then
        _worldsettingstimer:StartTimer(RIFTSPAWN_TIMERNAME, TUNING.RIFTS_SPAWNDELAY)
    end
end

local function OnLunarriftMaxsize(src, rift)
    local fx, fy, fz = rift.Transform:GetWorldPosition()
    for _, player in ipairs(AllPlayers) do
        local px, py, pz = player.Transform:GetWorldPosition()
        local sq_dist = distsq(fx, fz, px, pz)

        if sq_dist > 900 then --30*30
            player._lunarportalmax:push()
        end
    end
end

local function SetEnabledSetting(src, enabled_difficulty)
    if enabled_difficulty == "never" then
        _lunar_rifts_enabled = false
        _worldsettingstimer:StopTimer(RIFTSPAWN_TIMERNAME)
    elseif enabled_difficulty == "always" then
        EnableLunarRifts(src)
    end
end
--------------------------------------------------------------------------
--[[ Public getters and setters ]]
--------------------------------------------------------------------------

function self:GetEnabled()
    return _lunar_rifts_enabled
end

function self:GetRifts()
    return _rifts
end

function self:GetRiftsOfType(type)
    local return_rifts = nil
    for rift, rift_type in pairs(_rifts) do
        if rift_type == type then
            if return_rifts then
                table.insert(return_rifts, rift)
            else
                return_rifts = {rift}
            end
        end
    end
    return return_rifts
end

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

function self:OnSave()
    local data = {
        timerfinished = (not _worldsettingstimer:ActiveTimerExists(RIFTSPAWN_TIMERNAME)) or nil,
        rift_guids = {},
    }
    local ents = {}
    for rift, type in pairs(_rifts) do
        if type then
            table.insert(data.rift_guids, rift.GUID)
            table.insert(ents, rift.GUID)
        end
    end

    data._lunar_enabled = _lunar_rifts_enabled

    return data, ents
end

function self:OnLoad(data)
    if data.timerfinished then
        _worldsettingstimer:StopTimer(RIFTSPAWN_TIMERNAME)
    end

    _lunar_rifts_enabled = data._lunar_enabled or _lunar_rifts_enabled
end

function self:LoadPostPass(newents, data)
    if data then
        if data.rift_guids then
            for _, rift_guid in ipairs(data.rift_guids) do
                local new_ent = newents[rift_guid]
                if new_ent and new_ent.entity then
                    AddRiftToPool(new_ent.entity, new_ent.entity.prefab)
                end
            end
        end
    end

    if _lunar_rifts_enabled then
        EnableLunarRifts()
    end
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
    local s
    if _lunar_rifts_enabled then
        s = "Lunar Rifts ON - Number of rifts: " .. GetTableSize(_rifts)
    else
        -- Rifts might still exist if a server setting was changed.
        s = "Lunar Rifts OFF - Number of rifts: " .. GetTableSize(_rifts)
    end

    s = s .. string.format(" | Rift spawn time: %s", _worldsettingstimer:GetTimeLeft(RIFTSPAWN_TIMERNAME) or "-")

    return s
end

function self:Debug_SpawnRift(respect_spawn_limit)
    local spawned_rift
    if not respect_spawn_limit or GetTableSize(_rifts) < TUNING.MAXIMUM_RIFTS_COUNT then
        spawned_rift = SpawnRift()
    end

    return spawned_rift
end

function self:SpawnRift(pos)
    SpawnRift(pos)
end
--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

inst:ListenForEvent("rifts_setdifficulty", SetDifficulty)
inst:ListenForEvent("rifts_settingsenabled", SetEnabledSetting)
inst:ListenForEvent("lunarrift_opened", EnableLunarRifts)
inst:ListenForEvent("ms_lunarrift_maxsize", OnLunarriftMaxsize)

_worldsettingstimer:AddTimer(
    RIFTSPAWN_TIMERNAME,
    TUNING.RIFTS_SPAWNDELAY + 1,
    TUNING.SPAWN_RIFTS ~= 0,
    OnRiftTimerDone
)

end)