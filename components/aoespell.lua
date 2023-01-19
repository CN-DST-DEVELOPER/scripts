local AOESpell = Class(function(self, inst)
    self.inst = inst

    --self.spellfn = nil
end)

function AOESpell:SetSpellFn(fn)
    self.spellfn = fn
end

function AOESpell:CastSpell(doer, pos)
	local success, reason = true, nil
    if self.spellfn then
		success, reason = self.spellfn(self.inst, doer, pos)
		if success == nil and reason == nil then
			success = true
		end
    end

    if doer and doer:IsValid() then
		doer:PushEvent("oncastaoespell", { item = self.inst, pos = pos, success = success })
    end
	return success, reason
end

function AOESpell:CanCast(doer, pos)
	if not self.spellfn then
		return false
	end

	local alwayspassable, allowwater, deployradius
	local aoetargeting = self.inst.components.aoetargeting
	if aoetargeting then
		if not aoetargeting:IsEnabled() then
			return false
		end
		alwayspassable = aoetargeting.alwaysvalid
		allowwater = aoetargeting.allowwater
		deployradius = aoetargeting.deployradius
	end
	return TheWorld.Map:CanCastAtPoint(pos, alwayspassable, allowwater, deployradius)
end

return AOESpell
