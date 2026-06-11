local SourceModifierList = require("util/sourcemodifierlist")

local AoeDiminishingReturns = Class(function(self, inst)
	self.inst = inst
	self.mult = SourceModifierList(inst)
end)

function AoeDiminishingReturns:OnRemoveFromEntity()
	self.mult:Reset()
end

return AoeDiminishingReturns