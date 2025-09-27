local SlingshotModder = Class(function(self, inst)
	self.inst = inst
end)

function SlingshotModder:StartModding(target, user)
	if target.components.linkeditem and target.components.linkeditem:IsEquippableRestrictedToOwner() then
		local owneruserid = target.components.linkeditem:GetOwnerUserID()
		if owneruserid and (user and user.userid) ~= owneruserid then
			return false, "NOT_MINE"
		end
	end
	return target.components.slingshotmods and target.components.slingshotmods:Open(user) or false
end

function SlingshotModder:StopModding(target, user)
	return target.components.slingshotmods and target.components.slingshotmods:Close(user) or false
end

return SlingshotModder
