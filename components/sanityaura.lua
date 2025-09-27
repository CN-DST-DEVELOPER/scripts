local SanityAura = Class(function(self, inst)
    self.inst = inst
    self.aura = 0
    
    --self.max_distsq = nil
    --self.aurafn = nil
    --self.fallofffn = nil

	self.inst:AddTag("sanityaura")
end)

function SanityAura:OnRemoveFromEntity()
	self.inst:RemoveTag("sanityaura")
end

function SanityAura:GetBaseAura(observer) --No falloff.
	return self.aurafn == nil and self.aura or self.aurafn(self.inst, observer)
end

local SANITY_EFFECT_RANGE_SQ = TUNING.SANITY_EFFECT_RANGE * TUNING.SANITY_EFFECT_RANGE
function SanityAura:GetAura(observer)
	local aura_val = 0
	local distsq = observer:GetDistanceSqToInst(self.inst)
	if distsq <= (self.max_distsq or SANITY_EFFECT_RANGE_SQ) then
	    aura_val = (self.aurafn == nil and self.aura or self.aurafn(self.inst, observer)) / (self.fallofffn ~= nil and self.fallofffn(self.inst, observer, distsq) or math.max(1, distsq))
	end
    return aura_val
end

return SanityAura
