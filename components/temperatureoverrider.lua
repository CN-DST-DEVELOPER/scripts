local _sizes = {}
local _maxsize = 0

local function _reg_active_overrider_size(size)
    _maxsize = math.max(size, _maxsize)
    _sizes[size] = (_sizes[size] or 0) + 1
end

local function _unreg_active_overrider_size(size)
    if _sizes[size] > 1 then
        _sizes[size] = _sizes[size] - 1
    else
        _sizes[size] = nil
        if size == _maxsize then
            _maxsize = 0
            for k in pairs(_sizes) do
                _maxsize = math.max(k, _maxsize)
            end
        end
    end
end

----------------------------------------------------------------------------------

-- Globals

local TEMPERATURE_OVERRIDER_MUST_TAGS = { "temperatureoverrider" }

function GetTemperatureAtXZ(x, z)
    if _maxsize <= 0 then
        return TheWorld.state.temperature
    end

    local overriders = TheSim:FindEntities(x, 0, z, _maxsize, TEMPERATURE_OVERRIDER_MUST_TAGS)

    for i, ent in ipairs(overriders) do
        local r = ent.components.temperatureoverrider:GetActiveRadius()

        if r >= _maxsize or ent:GetDistanceSqToPoint(x, 0, z) <= r * r then
            --for dsq check, use <=, not <, to match spatial hash query
            return ent.components.temperatureoverrider:GetTemperature()
        end
    end

    return TheWorld.state.temperature
end

function GetLocalTemperature(inst)
    if _maxsize <= 0 then
        return TheWorld.state.temperature
    end

    local x, y, z = inst.Transform:GetWorldPosition()

    return GetTemperatureAtXZ(x, z)
end

----------------------------------------------------------------------------------

local function onradius(self, radius, oldradius)
    if self.enabled then
        self:SetActiveRadius_Internal(radius, oldradius or 0)
    end
end

local function OnActiveRadiusDirty(inst)
    local self = inst.components.temperatureoverrider
    if self._lastactiveradius ~= 0 then
        _unreg_active_overrider_size(self._lastactiveradius)
    end
    self._lastactiveradius = self._activeradius:value()
    if self._lastactiveradius ~= 0 then
        _reg_active_overrider_size(self._lastactiveradius)
    end
end

local TemperatureOverrider = Class(function(self, inst)
    self.inst = inst

    -- Cache variables.
    self.ismastersim = TheWorld.ismastersim

    -- Network variables.
    self._activeradius = net_float(inst.GUID, "temperatureoverrider._activeradius", "_activeradiusdirty" )
    self._temperature  = net_float(inst.GUID, "temperatureoverrider._temperature"                        )

    if self.ismastersim then
        --Server only
        self.radius = 16
        self.enabled = false
        self._temperature:set(25)
    else
        self._lastactiveradius = 0
        self.OnActiveRadiusDirty = OnActiveRadiusDirty
        inst:ListenForEvent("_activeradiusdirty", self.OnActiveRadiusDirty)
    end
end,
nil,
{
    radius = onradius,
})

----------------------------------------------------------------------------------
-- Globals

function TemperatureOverrider:OnRemoveFromEntity()
    assert(false)
end

function TemperatureOverrider:OnRemoveEntity()
    if self._activeradius:value() ~= 0 then
        _unreg_active_overrider_size(self._activeradius:value())
    end
end

function TemperatureOverrider:GetActiveRadius()
    return self._activeradius:value()
end

function TemperatureOverrider:GetTemperature()
    return self._temperature:value()
end

----------------------------------------------------------------------------------
-- Master Sim

function TemperatureOverrider:SetTemperature(temperature)
    if self.ismastersim then
        self._temperature:set(temperature)
    end
end

function TemperatureOverrider:SetRadius(radius)
    if self.ismastersim then
        self.radius = radius
    end
end

function TemperatureOverrider:Enable()
    if self.ismastersim and not self.enabled then
        self.enabled = true
        self:SetActiveRadius_Internal(self.radius, 0)
    end
end

function TemperatureOverrider:Disable()
    if self.ismastersim and self.enabled then
        self.enabled = false
        self:SetActiveRadius_Internal(0, self.radius)
    end
end

function TemperatureOverrider:SetActiveRadius_Internal(new, old)
    if new ~= old then
        if old ~= 0 then
            _unreg_active_overrider_size(old)
            if new == 0 then
                self.inst:RemoveTag("temperatureoverrider")
            end
        end
        if new ~= 0 then
            if old == 0 then
                self.inst:AddTag("temperatureoverrider")
            end
            _reg_active_overrider_size(new)
        end
        self._activeradius:set(new)
    end
end

return TemperatureOverrider
