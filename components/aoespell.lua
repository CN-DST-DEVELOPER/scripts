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

	if self.inst.components.spellbook then
		if not self.inst.components.spellbook:CanBeUsedBy(doer) then
			return false
		elseif self.inst.components.inventoryitem then
			--Keep in sync with COMPONENT_ACTIONS.INVENTORY.spellbook
			if self.inst.components.inventoryitem:GetGrandOwner() ~= doer then
				return false
			elseif self.inst.components.fueled and self.inst.components.fueled:IsEmpty() then
				return false
			end
		elseif self.inst.isplayer then
			--Keep in sync with COMPONENT_ACTIONS.SCENE.spellbook
			if self.inst ~= doer then
				return false
			end
		else
			return false --unsupported
		end
	end

	local alwayspassable, allowwater, deployradius, allowriding
	local aoetargeting = self.inst.components.aoetargeting
	if aoetargeting then
		if not aoetargeting:IsEnabled() then
			return false
		end
		alwayspassable = aoetargeting.alwaysvalid
		allowwater = aoetargeting.allowwater
		deployradius = aoetargeting.deployradius
		allowriding = aoetargeting.allowriding
	end

	if not allowriding and doer.components.rider ~= nil and doer.components.rider:IsRiding() then
		return false
	end

	return TheWorld.Map:CanCastAtPoint(pos, alwayspassable, allowwater, deployradius)
end

return AOESpell
