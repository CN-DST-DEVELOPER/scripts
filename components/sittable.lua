local function onoccupier(self, occupier)
	if occupier ~= nil then
		self.inst:RemoveTag("cansit")
	else
		self.inst:AddTag("cansit")
	end
end

local Sittable = Class(function(self, inst)
	self.inst = inst
	self.occupier = nil

	self._onremoveoccupier = function() self.occupier = nil end

	inst:AddTag("cansit")
end,
nil,
{
	occupier = onoccupier,
})

function Sittable:SetOccupier(occupier)
	if self.occupier ~= occupier then
		if self.occupier ~= nil then
			self.inst:RemoveEventCallback("onremove", self._onremoveoccupier, self.occupier)
		end
		self.occupier = occupier
		if occupier ~= nil then
			self.inst:ListenForEvent("onremove", self._onremoveoccupier, occupier)
			self.inst:PushEvent("becomeunsittable")
		end
	end
end

function Sittable:IsOccupied()
	return self.occupier ~= nil
end

function Sittable:IsOccupiedBy(occupier)
	return self.occupier == occupier and occupier ~= nil
end

function Sittable:OnRemoveFromEntity()
	if self.occupier ~= nil then
		self.inst:RemoveEventCallback("onremove", self._onremoveoccupier, self.occupier)
	end
	self.inst:RemoveTag("cansit")
	self.inst:PushEvent("becomeunsittable")
end

return Sittable
