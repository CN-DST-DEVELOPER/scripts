local function OnHealthDelta(inst)--, data)
	inst.components.dpstracker:DoUpdate()
end

local DpsTracker = Class(function(self, inst)
	self.inst = inst
	self.tbl = {} --ring buffer
	self.i0 = 1 --head index
	self.sz = 0 --current size of tbl
	self.max_size = 100 --max size of tbl
	self.max_window = 2 --seconds
	self.dps = 0
	--self.ondpsupdatefn = nil

	inst:ListenForEvent("healthdelta", OnHealthDelta)
end)

function DpsTracker:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("healthdelta", OnHealthDelta)
end

function DpsTracker:SetOnDpsUpdateFn(fn)
	self.ondpsupdatefn = fn
end

function DpsTracker:GetDps()
	return self.dps
end

function DpsTracker:DoUpdate()
	local MAX_SIZE = self.max_size
	local MAX_WINDOW = self.max_window
	local tbl = self.tbl
	local i0 = self.i0
	local i1
	local sz = self.sz
	local entry
	local t = GetTime()

	if sz > 0 then
		i1 = i0 + sz - 1
		if i1 > MAX_SIZE then
			i1 = i1 - MAX_SIZE
		end
		entry = tbl[i1]
		--if time matches, we can overwrite it, otherwise clear
		if entry.t ~= t then
			i1 = nil
			entry = nil
		end
	end

	if i1 == nil then
		if sz < MAX_SIZE then
			i1 = i0 + sz
			if i1 > MAX_SIZE then
				i1 = i1 - MAX_SIZE
			end
			sz = sz + 1
			entry = tbl[i1]
			if entry == nil then
				entry = {}
				tbl[i1] = entry
			end
		else
			i1 = i0
			i0 = i0 == MAX_SIZE and 1 or i0 + 1
			entry = tbl[i1]
		end
	end

	entry.hp = self.inst.components.health.currenthealth
	entry.t = t

	while sz > 1 do
		if entry.t - tbl[i0].t > MAX_WINDOW then
			i0 = i0 == MAX_SIZE and 1 or i0 + 1
			sz = sz - 1
		else
			break
		end
	end

	local entry0 = tbl[i0]
	local dt = entry.t - entry0.t
	self.dps = (entry0.hp - entry.hp) / (dt > 0 and dt or MAX_WINDOW)
	self.i0 = i0
	self.sz = sz

	if self.ondpsupdatefn then
		self.ondpsupdatefn(self.inst, self.dps)
	end
end

return DpsTracker
