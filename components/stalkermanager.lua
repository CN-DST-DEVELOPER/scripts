--------------------------------------------------------------------------
--[[ StalkerManager class definition ]]
--------------------------------------------------------------------------

-- This component manages saving data for the fuelweaver quest line (since they spawn and despawn)
-- and also only having one stalker at a time
-- all worlds (forest and caves) have this component

return Class(function(self, inst)

assert(TheWorld.ismastersim, "StalkerManager should not exist on client")

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _world = TheWorld

local _stalker
local _data = {}

-- For searching:
--  not_first_spawn

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnRemoveStalker(sack)
    _stalker = nil
end

local function OnRegisterStalker(_, stalker)
    if BRANCH == "dev" then
        -- assert(_stalker == nil, "We already have a stalker, but we're trying to register another one.")
    end

    _stalker = stalker
    inst:ListenForEvent("onremove", OnRemoveStalker, stalker)
end

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

-- to save data across instances of stalker
function self:GetData(var)
    return _data[var]
end

function self:SetData(var, val)
    _data[var] = val
end

function self:GetStalker()
    return _stalker
end

function self:StalkerExists()
    return _stalker ~= nil
end

function self:Debug_ResetData()
    _data = {}
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

--Register events
inst:ListenForEvent("ms_registerstalker", OnRegisterStalker, _world)

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

function self:OnSave()
    if next(_data) ~= nil then
        return { stalkerdata = _data }
    end
end

function self:OnLoad(data)
    if data ~= nil then
        if data.stalkerdata then
            _data = data.stalkerdata
        end
    end
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)
