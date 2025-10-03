--------------------------------------------------------------------------
--[[ FumaroleLocalTemperature class definition ]]
--------------------------------------------------------------------------
--[[
    Manages temp inside fumarole, GetTemperatureAtXZ in temperatureoverrider calls our getters
]]
require("components/temperatureoverrider")
return Class(function(self, inst)

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local NOISE_SYNC_PERIOD = 30
local TILE_SEARCH_HALF_SIZE = 4

--------------------------------------------------------------------------
--[[ Temperature constants ]]
--------------------------------------------------------------------------

local TEMPERATURE_NOISE_SCALE = .05
local TEMPERATURE_NOISE_MAG = 16
-- 70
local MIN_TEMPERATURE = 80
local MAX_TEMPERATURE = 125
local WINTER_CROSSOVER_TEMPERATURE = 75
local SUMMER_CROSSOVER_TEMPERATURE = 90

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _world = TheWorld
local _map = _world.Map
local _state = _world.state
local _ismastersim = _world.ismastersim

--Temperature
local _seasontemperature
local _globaltemperaturemult = 1
local _globaltemperaturelocus = 0

local _currenttemperature
local _cachetemperature

--Light
local _season = "autumn"

--Network
local _noisetime = net_float(inst.GUID, "fumarolelocaltemperature._noisetime")
--local _venting = net_bool(inst.GUID, "fumarolelocaltemperature._venting")

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function SetWithPeriodicSync(netvar, val, period, ismastersim)
    if netvar:value() ~= val then
        local trunc = val > netvar:value() and "floor" or "ceil"
        local prevperiod = math[trunc](netvar:value() / period)
        local nextperiod = math[trunc](val / period)

        if prevperiod == nextperiod then
            --Client and server update independently within current period
            netvar:set_local(val)
        elseif ismastersim then
            --Server sync to client when period changes
            netvar:set(val)
        else
            --Client must wait at end of period for a server sync
            netvar:set_local(nextperiod * period)
        end
    elseif ismastersim then
        --Force sync when value stops changing
        netvar:set(val)
    end
end

local ForceResync = _ismastersim and function(netvar)
    netvar:set_local(netvar:value())
    netvar:set(netvar:value())
end or nil

local function CalculateVentingTemperature()
    return _venting:value() and 100
        or 0
end

local function CalculateSeasonTemperature(season, progress)
    return (season == "winter" and math.sin(PI * progress) * (MIN_TEMPERATURE - WINTER_CROSSOVER_TEMPERATURE) + WINTER_CROSSOVER_TEMPERATURE)
        or (season == "spring" and Lerp(WINTER_CROSSOVER_TEMPERATURE, SUMMER_CROSSOVER_TEMPERATURE, progress))
        or (season == "summer" and math.sin(PI * progress) * (MAX_TEMPERATURE - SUMMER_CROSSOVER_TEMPERATURE) + SUMMER_CROSSOVER_TEMPERATURE)
        or Lerp(SUMMER_CROSSOVER_TEMPERATURE, WINTER_CROSSOVER_TEMPERATURE, progress)
end

local function CalculateTemperature()
    local temperaturenoise = 2 * TEMPERATURE_NOISE_MAG * perlin(0, 0, _noisetime:value() * TEMPERATURE_NOISE_SCALE) - TEMPERATURE_NOISE_MAG
    return (((temperaturenoise + _seasontemperature) - _globaltemperaturelocus) * _globaltemperaturemult) + _globaltemperaturelocus
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnSeasonTick(src, data)
    _seasontemperature = CalculateSeasonTemperature(data.season, data.progress)
    _season = data.season
    --_seasonprogress = data.progress
end

local OnSimUnpaused = _ismastersim and function()
    --Force resync values that client may have simulated locally
    ForceResync(_noisetime)
end or nil

local function InitializeDataGrids()
    if _cachetemperature == nil then
        _cachetemperature = DataGrid(_map:GetSize())
    end
end
InitializeDataGrids() -- This can be done immediately because this is a NETWORK world entity, which is spawned after map size is set

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

function self:SetTemperatureMod(multiplier, locus)
    _globaltemperaturemult = multiplier
    _globaltemperaturelocus = locus
end

function self:GetTemperature()
    return _currenttemperature
end

function self:GetTemperatureAtXZ(x, z)
    local tx, ty = _map:GetTileCoordsAtPoint(x, 0, z)
    local index = _cachetemperature:GetIndex(tx, ty)
    local temp_perc = _cachetemperature:GetDataAtIndex(index)

    if not temp_perc then
        local num_fumarole = 0
        local tile_area = 0

        for off_tx = -TILE_SEARCH_HALF_SIZE, TILE_SEARCH_HALF_SIZE do
            for off_ty = -TILE_SEARCH_HALF_SIZE, TILE_SEARCH_HALF_SIZE do
                local ptx, pty = tx + off_tx, ty + off_ty
                if not TileGroupManager:IsImpassableTile(_map:GetTile(ptx, pty)) then
                    tile_area = tile_area + 1
                    if _map:NodeAtTileHasTag(ptx, pty, "fumarolearea") then
                        num_fumarole = num_fumarole + 1
                    end
                end
            end
        end

        temp_perc = num_fumarole == 0 and 0 or num_fumarole / tile_area
        _cachetemperature:SetDataAtIndex(index, temp_perc)
    end

    return temp_perc ~= 0 and Lerp(_state.temperature, _currenttemperature, temp_perc) or nil
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

_seasontemperature = CalculateSeasonTemperature(_season, .5)

--Initialize network variables
_noisetime:set(0)
--_venting:set(false)

--Register events
inst:ListenForEvent("seasontick", OnSeasonTick, _world)

if _ismastersim then
    --Register master simulation events
    inst:ListenForEvent("ms_simunpaused", OnSimUnpaused, _world)
end

_currenttemperature = CalculateTemperature()
inst:StartUpdatingComponent(self)

--------------------------------------------------------------------------
--[[ Update ]]
--------------------------------------------------------------------------

--[[
    Client updates temperature, moisture, precipitation effects, and snow
    level on its own while server force syncs values periodically. Client
    cannot start, stop, or change precipitation on its own, and must wait
    for server syncs to trigger these events.
--]]
function self:OnUpdate(dt)
    --Update noise
    SetWithPeriodicSync(_noisetime, _noisetime:value() + dt, NOISE_SYNC_PERIOD, _ismastersim)

    _currenttemperature = CalculateTemperature()
end

self.LongUpdate = self.OnUpdate

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

if _ismastersim then function self:OnSave()
    return
    {
        season = _season,
        seasontemperature = _seasontemperature,
        noisetime = _noisetime:value(),
    }
end end

if _ismastersim then function self:OnLoad(data)
    _season = data.season or "autumn"
    _seasontemperature = data.seasontemperature or CalculateSeasonTemperature(_season, .5)
    _noisetime:set(data.noisetime or 0)
end end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
    local temperature = CalculateTemperature()
    return string.format("%2.2fC mult: %.2f locus %.1f", temperature, _globaltemperaturemult, _globaltemperaturelocus)
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)