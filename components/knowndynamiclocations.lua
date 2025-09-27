local KnownDynamicLocations = Class(function(self, inst)
	self.inst = inst
	self.locations = {}
end)

function KnownDynamicLocations:OnRemoveFromEntity()
	for name, entry in pairs(self.locations) do
		self:StopWatchingPlatformForEntry(entry)
	end
end

function KnownDynamicLocations:GetLocation(name)
	local entry = self.locations[name]
	return entry and entry.pos:GetPosition() or nil
end

function KnownDynamicLocations:GetDynamicLocation(name)
	local entry = self.locations[name]
	return entry and entry.pos or nil
end

function KnownDynamicLocations:RememberLocation(name, pt, dont_overwrite)
	if not dont_overwrite then
		self:ForgetLocation(name)
	end
	if self.locations[name] == nil then
		if pt and not (isbadnumber(pt.x) or isbadnumber(pt.y) or isbadnumber(pt.z)) then
			local entry = {}
			if POPULATING then
				--Defer hooking up platforms until LoadPostPass
				entry.pos = DynamicPosition()
				entry.pos.local_pt = pt
				entry.loading = true
			else
				entry.pos = DynamicPosition(pt)
				self:WatchPlatformForEntry(entry)
			end
			self.locations[name] = entry
		else
			print("KnownDynamicLocations:RememberDynamicLocation position error: ", self.inst.prefab, self.inst:IsValid(), pos)
			error("Error: KnownDynamicLocations:RememberDynamicLocation() recieved a bad pos value.")
		end
	end
end

function KnownDynamicLocations:ForgetLocation(name)
	local entry = self.locations[name]
	if entry then
		self:StopWatchingPlatformForEntry(entry)
		self.locations[name] = nil
	end
end

function KnownDynamicLocations:WatchPlatformForEntry(entry)
	if entry.pos.walkable_platform and entry.onremoveplatform == nil then
		entry.onremoveplatform = function()
			--convert to world position without platform
			entry.pos.local_pt.x, entry.pos.local_pt.y, entry.pos.local_pt.z = entry.pos:GetPosition():Get()
			entry.pos.walkable_platform = nil
			entry.onremoveplatform = nil
		end
		self.inst:ListenForEvent("onremove", entry.onremoveplatform, entry.pos.walkable_platform)
	end
end

function KnownDynamicLocations:StopWatchingPlatformForEntry(entry)
	if entry.onremoveplatform then
		self.inst:RemoveEventCallback("onremove", entry.onremoveplatform, entry.pos.walkable_platform)
		entry.onremoveplatform = nil
	end
end

function KnownDynamicLocations:GetDebugString()
	if next(self.locations) == nil then
		return
	end

	local str = ""
	for name, entry in pairs(self.locations) do
		str = str..string.format("%s: %s ", name, tostring(entry.pos))
	end
	return str
end

function KnownDynamicLocations:OnSave()
	if next(self.locations) == nil then
		return
	end

	local locs = {}
	for name, entry in pairs(self.locations) do
		local rec = { name = name }
		rec.x, rec.y, rec.z = entry.pos:GetPosition():Get()
		if rec.y == 0 then
			rec.y = nil
		end
		table.insert(locs, rec)
	end
	return { locations = locs }
end

function KnownDynamicLocations:OnLoad(data)
	if data and data.locations then
		for _, rec in pairs(data.locations) do
			self:RememberLocation(rec.name, Vector3(rec.x, rec.y or 0, rec.z))
		end
	end
end

function KnownDynamicLocations:LoadPostPass(ents, data)
	for name, entry in pairs(self.locations) do
		if entry.loading then
			entry.loading = nil
			entry.pos = DynamicPosition(entry.pos:GetPosition())
			self:WatchPlatformForEntry(entry)
		end
	end
end

return KnownDynamicLocations
