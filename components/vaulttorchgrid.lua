local DEFAULT_SPACING = 4

local VaultTorchGrid = Class(function(self, inst)
	self.inst = inst
	self.spacing = DEFAULT_SPACING
	self.numcols = 0
	self.numrows = 0
	self.coloffs = 0 --e.g. if numcols is 3, then range is [-1, 1], so coloffs is -1
	self.rowoffs = 0
	self.grid = {}
	--self.ontorchaddedfn = nil
	--self.ontorchremovedfn = nil
end)

function VaultTorchGrid:SetOnTorchAddedFn(fn)
	self.ontorchaddedfn = fn
end

function VaultTorchGrid:SetOnTorchRemovedFn(fn)
	self.ontorchremovedfn = fn
end

function VaultTorchGrid:OnRemoveEntity()
	for _, gridcol in pairs(self.grid) do
		for _, torch in pairs(gridcol) do
			torch:Remove()
		end
	end
end

function VaultTorchGrid:Clear()
	for col, gridcol in pairs(self.grid) do
		for row, torch in pairs(gridcol) do
			torch:Remove()
			gridcol[row] = nil
			if self.ontorchremovedfn then
				self.ontorchremovedfn(self.inst, torch)
			end
		end
		self.grid[col] = nil
	end
	self.numcols, self.numrows = 0, 0
end

function VaultTorchGrid:Initialize(numcols, numrows, spacing)
	self:Clear()
	self.spacing = spacing or DEFAULT_SPACING
	self.numcols, self.numrows = numcols, numrows
	self.coloffs = math.floor((1 - numcols) / 2)
	self.rowoffs = math.floor((1 - numrows) / 2)
	local x, _, z = self.inst.Transform:GetWorldPosition()
	for col = 1, numcols do
		local gridcol = {}
		self.grid[col] = gridcol
		for row = 1, numrows do
			local torch = SpawnPrefab("vault_torch")
			torch.col = col - 1 + self.coloffs
			torch.row = row - 1 + self.rowoffs
			torch.Transform:SetPosition(x + torch.col * self.spacing, 0, z + torch.row * self.spacing)
			torch.persists = false
			gridcol[row] = torch
			if self.ontorchaddedfn then
				self.ontorchaddedfn(self.inst, torch)
			end
		end
	end
end

function VaultTorchGrid:GetTorch(col, row)
	local gridcol = self.grid[col - self.coloffs + 1]
	return gridcol and gridcol[row - self.rowoffs + 1]
end

function VaultTorchGrid:ForEach(cb)
	if cb then
		for _, gridcol in ipairs(self.grid) do
			for _, torch in ipairs(gridcol) do
				if cb(self.inst, torch) then
					return --cb returns true to break out
				end
			end
		end
	end
end

local function _try_adjacent(self, col, row, cb)
	local gridcol = self.grid[col]
	if gridcol then
		local torch = gridcol[row]
		if torch then
			cb(self.inst, torch)
		end
	end
end

function VaultTorchGrid:ForEachAdjacent(torch, cb)
	if cb and torch.col and torch.row then
		local col = torch.col - self.coloffs + 1
		local gridcol = self.grid[col]
		if gridcol then
			local row = torch.row - self.rowoffs + 1
			if gridcol[row] == torch then
				_try_adjacent(self, col - 1, row, cb)
				_try_adjacent(self, col + 1, row, cb)
				_try_adjacent(self, col, row - 1, cb)
				_try_adjacent(self, col, row + 1, cb)
			end
		end
	end
end

--------------------------------------------------------------------------

local TorchGridSerializer = Class(function(self)
	self.str = ""
	self.int = 0
	self.numbits = 0
end)

function TorchGridSerializer:PushBit(val)
	if self.numbits == 32 then
		self.str = string.format("%x%s", self.int, self.str)
		self.int = 0
		self.numbits = 0
	end
	if val ~= 0 then
		self.int = bit.bor(self.int, bit.lshift(1, self.numbits))
	end
	self.numbits = self.numbits + 1
end

function TorchGridSerializer:PushTorch(torch)
	self:PushBit(torch.components.machine:IsOn() and 1 or 0)
	self:PushBit(torch:IsStuck() and 1 or 0)
	self:PushBit(torch:IsBroken() and 1 or 0)
end

function TorchGridSerializer:GetString()
	return self.numbits > 0 and string.format("%x%s", self.int, self.str) or self.str
end

--------------------------------------------------------------------------

local TorchGridDeserializer = Class(function(self, str)
	self.str = str
	self.int = 0
	self.bitnum = 32
end)

function TorchGridDeserializer:PopBit()
	if self.bitnum == 32 then
		if string.len(self.str) > 8 then
			self.int = tonumber(string.sub(self.str, -8), 16) or 0
			self.str = string.sub(self.str, 1, -9)
		else
			self.int = tonumber(self.str, 16) or 0
			self.str = ""
		end
		self.bitnum = 0
	end
	local val = bit.band(1, bit.rshift(self.int, self.bitnum))
	self.bitnum = self.bitnum + 1
	return val
end

function TorchGridDeserializer:PopTorch(torch)
	local on = self:PopBit() ~= 0
	local stuck = self:PopBit() ~= 0
	local broken = self:PopBit() ~= 0

	if stuck then
		if on then
			torch:MakeStuckOn()
		else
			torch:MakeStuckOff()
		end
	else
		if on then
			if not torch.components.machine:IsOn() then
				torch.components.machine:TurnOn()
			end
		elseif torch.components.machine:IsOn() then
			torch.components.machine:TurnOff()
		end

		if broken then
			torch:MakeBroken()
		else
			torch:MakeNormal()
		end
	end
end

--------------------------------------------------------------------------

function VaultTorchGrid:OnSave()
	if self.numcols > 0 and self.numrows > 0 then
		local serializer = TorchGridSerializer()
		for _, gridcol in ipairs(self.grid) do
			for _, torch in ipairs(gridcol) do
				serializer:PushTorch(torch)
			end
		end
		return {
			cols = self.numcols,
			rows = self.numrows,
			spacing = self.spacing ~= DEFAULT_SPACING and self.spacing or nil,
			bits = serializer:GetString(),
		}
	end
end

function VaultTorchGrid:OnLoad(data)--, ents)
	if data.cols and data.rows then
		if self.numcols ~= data.cols or
			self.numrows ~= data.rows or
			self.spacing ~= (data.spacing or DEFAULT_SPACING)
		then
			self:Initialize(data.cols, data.rows, data.spacing)
		end

		local str = data.bits
		if data.bits then
			local deserializer = TorchGridDeserializer(data.bits)
			for _, gridcol in ipairs(self.grid) do
				for _, torch in ipairs(gridcol) do
					deserializer:PopTorch(torch)
				end
			end
		end
	end
end

return VaultTorchGrid
