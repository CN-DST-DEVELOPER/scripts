local SourceModifierList = require("util/sourcemodifierlist")

local HoundedTarget = Class(function(self, inst)
    self.inst = inst

	self.target_weight_mult = SourceModifierList(inst)
	self.hound_thief_sources = SourceModifierList(inst, false, SourceModifierList.boolean)

	self.hound_thief = false -- Deprecated
end)

function HoundedTarget:GetTargetWeight()
	return self.target_weight_mult:Get()
end

function HoundedTarget:IsHoundThief()
	return self.hound_thief_sources:Get() or self.hound_thief
end

return HoundedTarget
