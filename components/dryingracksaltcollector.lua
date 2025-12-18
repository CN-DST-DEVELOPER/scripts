local DryingRackSaltCollector = Class(function(self, inst)
	self.inst = inst
	self.slots = {}
	self.numsalts = 0
	self.onsaltchangedfn = nil
end)

function DryingRackSaltCollector:SetOnSaltChangedFn(fn)
	self.onsaltchangedfn = fn
end

function DryingRackSaltCollector:AddSalt(slot)
	if not self.slots[slot] then
		self.slots[slot] = true
		self.numsalts = self.numsalts + 1
		if self.onsaltchangedfn then
			self.onsaltchangedfn(self.inst, self.numsalts)
		end
		return true
	end
	return false
end

function DryingRackSaltCollector:RemoveSalt(slot)
	if self.slots[slot] then
		self.slots[slot] = nil
		self.numsalts = self.numsalts - 1
		if self.onsaltchangedfn then
			self.onsaltchangedfn(self.inst, self.numsalts)
		end
		return true
	end
	return false
end

function DryingRackSaltCollector:HasSalt(slot)
	if slot then
		return self.slots[slot] or false
	end
	return self.numsalts > 0
end

function DryingRackSaltCollector:GetNumSalts()
	return self.numsalts
end

function DryingRackSaltCollector:OnSave()
	if self.numsalts > 0 then
		local slots = {}
		for k in pairs(self.slots) do
			table.insert(slots, k)
		end
		return { slots = slots }
	end
end

function DryingRackSaltCollector:OnLoad(data)--, ents)
	if data.slots and #data.slots > 0 then
		for _, v in ipairs(data.slots) do
			if not self.slots[v] then
				self.slots[v] = true
				self.numsalts = self.numsalts + 1
			end
		end
		if self.onsaltchangedfn then
			self.onsaltchangedfn(self.inst, self.numsalts)
		end
	end
end

return DryingRackSaltCollector
