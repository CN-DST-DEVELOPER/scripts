local Preserver = Class(function(self, inst)
    self.inst = inst

    self.perish_rate_multiplier = 1
end)

function Preserver:SetPerishRateMultiplier(rate)
    self.perish_rate_multiplier = rate
end

function Preserver:GetPerishRateMultiplier(item)
    return FunctionOrValue(self.perish_rate_multiplier, self.inst, item) or 1
end

function Preserver:GetDebugString()
    if self.perish_rate_multiplier == nil then
        return "Perish rate mult = nil (1.00)"
    end

    if type(self.perish_rate_multiplier) == "number" then
        return string.format("Perish rate mult = %.2f", self.perish_rate_multiplier)
    end

    return "Perish rate mult = "..tostring(self.perish_rate_multiplier)
end

return Preserver