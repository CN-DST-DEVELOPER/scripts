local function _push_pt(tbl, x, _, z)
	local n = #tbl
	tbl[n + 1] = x
	tbl[n + 2] = z
end

local function _pop_pt(tbl)
	local n = #tbl
	if n > 0 then
		local x, z = tbl[n - 1], tbl[n]
		tbl[n - 1] = nil
		tbl[n] = nil
		return x, z
	end
end

local AbyssPillarGroup = Class(function(self, inst)
	self.inst = inst
	self.spawnfn = nil
	self.collapsefn = nil
	self.onaddpillarfn = nil
	self.onremovepillarfn = nil
	self.pillars = {}
	self.spawnpts = {}

	self._onpillarcollapsed = function(pillar)
		self.pillars[pillar] = nil
		_push_pt(self.spawnpts, pillar.Transform:GetWorldPosition())
		if self.onremovepillarfn then
			self.onremovepillarfn(inst, pillar)
		end
	end
end)

function AbyssPillarGroup:SetSpawnAtXZFn(fn)
	self.spawnfn = fn
end

function AbyssPillarGroup:SetCollapseFn(fn)
	self.collapsefn = fn
end

function AbyssPillarGroup:SetOnAddPillarFn(fn)
	self.onaddpillarfn = fn
end

function AbyssPillarGroup:SetOnRemovePillarFn(fn)
	self.onremovepillarfn = fn
end

function AbyssPillarGroup:StartTrackingPillar(pillar)
	if self.pillars[pillar] == nil then
		self.pillars[pillar] = true
		assert(pillar._abysspillargroup == nil)
		pillar._abysspillargroup = self
		self.inst:ListenForEvent("onremove", self._onpillarcollapsed, pillar)
		if self.onaddpillarfn then
			self.onaddpillarfn(self.inst, pillar)
		end
	end
end

function AbyssPillarGroup:StopTrackingPillar(pillar)
	if self.pillars[pillar] then
		self.pillars[pillar] = nil
		assert(pillar._abysspillargroup == self)
		pillar._abysspillargroup = nil
		self.inst:RemoveEventCallback("onremove", self._onpillarcollapsed, pillar)
		if self.onremovepillarfn then
			self.onremovepillarfn(self.inst, pillar)
		end
	end
end

function AbyssPillarGroup:SpawnPillarAtXZ(x, z, instant)
	local pillar = self.spawnfn and self.spawnfn(self.inst, x, z, instant)
	if pillar then
		self:StartTrackingPillar(pillar)
	end
end

function AbyssPillarGroup:AddPillarSpawnPointXZ(x, z)
	_push_pt(self.spawnpts, x, 0, z)
end

function AbyssPillarGroup:RespawnAllPillars()
	while #self.spawnpts > 0 do
		self:SpawnPillarAtXZ(_pop_pt(self.spawnpts))
	end
end

function AbyssPillarGroup:CollapseAllPillars()
	for pillar in pairs(self.pillars) do
		if self.collapsefn then
			self.collapsefn(self.inst, pillar)
		end
	end
end

function AbyssPillarGroup:Clear()
	for i = 1, #self.spawnpts do
		self.spawnpts[i] = nil
	end
	for pillar in pairs(self.pillars) do
		self:StopTrackingPillar(pillar)
		pillar:Remove()
	end
end

function AbyssPillarGroup:HasPillars()
	return next(self.pillars) ~= nil
end

function AbyssPillarGroup:HasSpawnPoints()
	return #self.spawnpts > 0
end

function AbyssPillarGroup:OnSave()
	local data = #self.spawnpts > 0 and { pts = shallowcopy(self.spawnpts) } or nil
	local refs
	if next(self.pillars) then
		refs = {}
		for pillar in pairs(self.pillars) do
			table.insert(refs, pillar.GUID)
		end
		data = data or {}
		data.ents = refs
	end
	return data, refs
end

function AbyssPillarGroup:OnLoad(data)--, ents)
	self.spawnpts = data.pts or self.spawnpts
end

function AbyssPillarGroup:LoadPostPass(ents, data)
	if data.ents then
		for _, guid in ipairs(data.ents) do
			local pillar = ents[guid]
			if pillar then
				self:StartTrackingPillar(pillar.entity)
			end
		end
	end
end

return AbyssPillarGroup
