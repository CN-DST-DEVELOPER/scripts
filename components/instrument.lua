local Instrument = Class(function(self, inst)
    self.inst = inst
    self.range = 15
    --self.onheard = nil
    --self.onplayed = nil
end)

function Instrument:SetOnHeardFn(fn)
    self.onheard = fn
end

function Instrument:SetOnPlayedFn(fn)
    self.onplayed = fn
end

function Instrument:SetOnFinishedPlayingFn(fn)
    self.onfinishedplaying = fn
end

function Instrument:SetRange(range)
    self.range = range
end

function Instrument:SetAssetOverrides(build, symbol, sound)
    self.override_build = build
    self.override_symbol = symbol
    self.override_sound = sound
end
function Instrument:GetAssetOverrides()
    return self.override_build, self.override_symbol, self.override_sound
end

local NOTAGS = { "FX", "DECOR", "INLIMBO" }
function Instrument:Play(musician)
    if self.onplayed ~= nil then
        self.onplayed(self.inst, musician)
    end
    if self.onheard ~= nil then
        local x, y, z = musician.Transform:GetWorldPosition()
        local listeners = TheSim:FindEntities(x, y, z, self.range, nil, NOTAGS)
        for _, listener in ipairs(listeners) do
            if listener ~= self.inst then
                self.onheard(listener, musician, self.inst)
            end
        end
    end
    if self.onfinishedplaying ~= nil then
        self.onfinishedplaying(self.inst, musician)
    end
    return true
end

return Instrument
