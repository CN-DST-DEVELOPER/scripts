local defs = {}

local TILE_SIZE = 4

local Terraformer = Class(function(self)
	self.col1 = -5
	self.col2 = 5
	self.row1 = -5
	self.row2 = 5
	self.width = self.col2 - self.col1 + 1
	self.height = self.row2 - self.row1 + 1
	self.data = {}
	self:Reset()
end)

function Terraformer:Reset()
	for k in pairs(self.data) do
		self.data[k] = nil
	end
	for col = 2, 5 do
		self:EraseTile(col, 5)
		self:EraseTile(-col, 5)
		self:EraseTile(col, -5)
		self:EraseTile(-col, -5)
	end
	for row = 2, 4 do
		self:EraseTile(-5, row)
		self:EraseTile(5, row)
		self:EraseTile(-5, -row)
		self:EraseTile(5, -row)
	end
end

function Terraformer:EraseTile(col, row)
	self.data[(row - self.row1) * self.width + col - self.col1] = true
end

function Terraformer:ApplyAtXZ(x, z)
	local map = TheWorld.Map
	local tile_x, tile_y = map:GetTileCoordsAtPoint(x, 0, z)
	local i = 0
	for row = self.row1, self.row2 do
		for col = self.col1, self.col2 do
			local tx = tile_x + col
			local ty = tile_y + row
			local old_tile = map:GetTile(tx, ty)
			if self.data[i] then
				if not TileGroupManager:IsInvalidTile(old_tile) then
					map:SetTile(tx, ty, WORLD_TILES.IMPASSABLE)
					local x1, y1, z1 = map:GetTileCenterPoint(tx, ty)
					TempTile_HandleTileChange(x1, y1, z1, old_tile)
				end
			elseif old_tile ~= WORLD_TILES.VAULT then
				map:SetTile(tx, ty, WORLD_TILES.VAULT)
			end
			i = i + 1
		end
	end
end

--------------------------------------------------------------------------

defs.ResetTerraformRoomAtXZ = function(inst, x, z)
	Terraformer():ApplyAtXZ(x, z)
end

--------------------------------------------------------------------------

defs["puzzle1"] = {}

defs.puzzle1.TerraformRoomAtXZ = function(inst, x, z)
	local terraformer = Terraformer()
	for row = -3, 3 do
		for col = -3, 3 do
			terraformer:EraseTile(col, row)
		end
	end
	terraformer:EraseTile(-3, 4)
	terraformer:EraseTile(-2, 4)
	terraformer:EraseTile(2, 4)
	terraformer:EraseTile(3, 4)
	terraformer:ApplyAtXZ(x, z)
end

defs.puzzle1.LayoutNewRoomAtXZ = function(inst, x, z)
	local trial = SpawnPrefab("abysspillar_trial")
	trial.Transform:SetPosition(x + 1.5 * TILE_SIZE, 0, z - 4 * TILE_SIZE)
	trial:SetSpawnXZ(x, z - 4 * TILE_SIZE)

	--runes
	local rune = SpawnPrefab("vault_rune")
	rune:SetId("puzzle1")
	rune.Transform:SetPosition(x - 1.5 * TILE_SIZE, 0, z - 4 * TILE_SIZE)

	--back columns
	local brokenvar = math.random(3)
	SpawnPrefab("vault_pillar"):MakeBroken(brokenvar == 1).Transform:SetPosition(x - 2.5 * TILE_SIZE, 0, z + 4 * TILE_SIZE)
	SpawnPrefab("vault_pillar"):MakeBroken(brokenvar == 2).Transform:SetPosition(x + 2.5 * TILE_SIZE, 0, z + 4 * TILE_SIZE)

	--exit light
	SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z + 4 * TILE_SIZE)

	--variations
	local activeminion, lightvar

	--minion statue columns
	for dx = -2.5, 2.5, 5 do
		local x1 = x + dx * TILE_SIZE
		local left = x1 < x

		if activeminion == nil then
			activeminion = math.random(-1, 1) * 2
		else
			local old = activeminion
			activeminion = math.random(-1, 0) * 2
			if activeminion >= old then
				activeminion = activeminion + 2
			end
		end

		if lightvar == nil then
			lightvar = math.random(-1, 1) * 2
		else
			local old = lightvar
			lightvar = math.random(-1, 0) * 2
			if lightvar >= old then
				lightvar = lightvar + 2
			end
		end

		for i = 2, -2, -2 do
			local z1 = z + i * TILE_SIZE

			local pillar = SpawnPrefab("vault_pillar"):MakeCapped(2)
			pillar.Transform:SetPosition(x1, 0, z1)

			local minion = SpawnPrefab("abysspillar_minion")
			minion:SetOnBigPillar(pillar, left)
			if i == activeminion then
				trial:SetMinion(minion, left)
			else
				minion:MakeBroken()
			end

			SpawnPrefab("vault_chandelier"):SetVariation(i == lightvar and 2 or 1).Transform:SetPosition(x1, 0, z1)
		end
	end
end

--------------------------------------------------------------------------

defs["puzzle2"] = {}

defs.puzzle2.TerraformRoomAtXZ = function(inst, x, z)
	local terraformer = Terraformer()
	for row = -4, 4 do
		for col = -4, 4 do
			if row >= 3 or math.abs(col) >= (row <= -3 and 2 or 3) then
				terraformer:EraseTile(col, row)
			end
		end
	end
	terraformer:ApplyAtXZ(x, z)
end

defs.puzzle2.LayoutNewRoomAtXZ = function(inst, x, z)
	--runes
	local rune = SpawnPrefab("vault_rune")
	rune:SetId("puzzle2")
	rune.Transform:SetPosition(x, 0, z - 3 * TILE_SIZE)

	--torches
	local trial = SpawnPrefab("lightsout_trial")
	trial.Transform:SetPosition(x, 0, z)
	trial:SetupPuzzle()

	--variations
	local brokenvar = math.random(4)
	local i = 1

	--columns
	for dx = -1.5, 1.5, 3 do
		SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 3.5 * TILE_SIZE)
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x - 3.5 * TILE_SIZE, 0, z + dx * TILE_SIZE)
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + 3.5 * TILE_SIZE, 0, z + dx * TILE_SIZE)
	end
	for zsign = -1, 1, 2 do
		for xsign = -1, 1, 2 do
			if brokenvar < i then
				brokenvar = math.random(i, i + 2)
			end
			for dx = 2.5, 3.5, 1 do
				local dz = 6 - dx
				SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * xsign * TILE_SIZE, 0, z + dz * zsign * TILE_SIZE)
				i = i + 1
			end
		end
		brokenvar = math.random(i, i + 3)
	end

	--ground
	local groundvars = { 3, 4, 5, 3, 4, 5, 3, 4, 5 }
	local groundorientations = { 1, 2, 3, 4, 1, 2, 3, 4, math.random(4) }
	for dx = -1.5, 1.5, 1.5 do
		for dz = -1.5, 1.5, 1.5 do
			SpawnPrefab("vault_ground_pattern_fx"):SetVariation(table.remove(groundvars, math.random(#groundvars))):SetOrientation(table.remove(groundorientations, math.random(#groundorientations))).Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
		end
	end

	--lights
	SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z)
end

--------------------------------------------------------------------------

local halldef = {}

halldef.TerraformRoomAtXZ = function(inst, x, z)
	local terraformer = Terraformer()
	for row = -4, 4 do
		for col = -4, 4 do
			if row ~= 0 and col ~= 0 and not (row <= 1 and row >= -1 and col <= 1 and col >= -1) then
				terraformer:EraseTile(col, row)
			end
		end
	end
	terraformer:ApplyAtXZ(x, z)
end

halldef.LayoutNewRoomAtXZ = function(inst, x, z)
	--variations
	local seed = TheWorld.components.vaultroommanager and TheWorld.components.vaultroommanager:GetPRNGSeed() or hash(TheNet:GetSessionIdentifier())
	local groundvar = bit.band(seed, 1) == 1
	local lightvar = math.random(3)
	local brokenvar = math.random(8)
	local broken2
	local i = 1

	--columns
	for dx = -1.5, 1.5, 3 do
		for dz = -3.5, 3.5, 7 do
			SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
			SpawnPrefab("vault_pillar"):MakeBroken(i + 1 == brokenvar).Transform:SetPosition(x + dz * TILE_SIZE, 0, z + dx * TILE_SIZE)
			i = i + 2
			if not broken2 and brokenvar < i then
				broken2 = true
				brokenvar = math.random(8)
			end
		end
		for dz = -2.5, 2.5, 5 do
			SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
			SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dz * TILE_SIZE, 0, z + dx * TILE_SIZE)
		end
	end

	--lights
	if lightvar > 2 then
		local r = 1 + math.random()
		local theta = math.random() * TWOPI
		SpawnPrefab("vault_chandelier_broken").Transform:SetPosition(x + math.cos(theta) * r, 0, z - math.sin(theta) * r)
		SpawnPrefab("vault_chandelier_decor"):SetVariation(math.random() < 0.5 and 1 or 3).Transform:SetPosition(x, 0, z)
	else
		SpawnPrefab("vault_chandelier"):SetVariation(lightvar).Transform:SetPosition(x, 0, z)
	end

	--ground
	local roomid = inst.components.vaultroom.roomid
	if roomid then
		local _, n = string.match(roomid, "^(hall)(%d+)")
		roomid = tonumber(n)
	end
	if roomid then
		if (roomid == 1 or roomid == 4 or roomid == 7) == groundvar then
			SpawnPrefab("vault_ground_pattern_fx"):SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
		end
	elseif math.random() < 0.5 then
		SpawnPrefab("vault_ground_pattern_fx"):SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
	end
end

for i = 1, 7 do
	defs["hall"..tostring(i)] = halldef
end

--------------------------------------------------------------------------

defs["lore1"] = {}

defs.lore1.TerraformRoomAtXZ = function(inst, x, z)
	local terraformer = Terraformer()
	for col = -4, 4 do
		if col ~= 0 then
			for row = 2, 4 do
				terraformer:EraseTile(col, row)
				terraformer:EraseTile(col, -row)
			end
		end
	end
	for row = -1, 1, 2 do
		terraformer:EraseTile(-4, row)
		terraformer:EraseTile(4, row)
		terraformer:EraseTile(-1, row)
		terraformer:EraseTile(1, row)
	end
	terraformer:ApplyAtXZ(x, z)
end

defs.lore1.LayoutNewRoomAtXZ = function(inst, x, z)
	--variations
	local groundvar = math.random(2)
	local brokenvar = math.random(4)
	local broken2
	local i = 1

	--runes
	local rune = SpawnPrefab("vault_rune")
	rune:SetId("lore1")
	rune.Transform:SetPosition(x - 2.5 * TILE_SIZE, 0, z)
	SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(groundvar == 1 and 2 or 1):SetOrientation(math.random(4)).Transform:SetPosition(x - 2.5 * TILE_SIZE, 0, z)
	SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x - 2.5 * TILE_SIZE, 0, z)

	--statues
	local statue = SpawnPrefab("vault_statue")
	statue:SetId("king")
	statue:SetScene("lore1")
	statue.Transform:SetPosition(x + 2.5 * TILE_SIZE, 0, z)
	SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(groundvar == 2 and 2 or 1):SetOrientation(math.random(4)).Transform:SetPosition(x + 2.5 * TILE_SIZE, 0, z)
	local theta = math.random() * TWOPI
	SpawnPrefab("vault_chandelier_broken").Transform:SetPosition(x + 2.5 * TILE_SIZE + 2.5 * math.cos(theta), 0, z - 2.5 * math.sin(theta))
	SpawnPrefab("vault_chandelier_decor"):SetVariation(math.random() < 0.5 and 1 or 3).Transform:SetPosition(x + 2.5 * TILE_SIZE, 0, z)
	SpawnPrefab("vault_chandelier_decor"):SetVariation(2).Transform:SetPosition(x, 0, z)

	--columns
	for dx = -1.5, 1.5, 3 do
		SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 2.5 * TILE_SIZE)
		SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 2.5 * TILE_SIZE)
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 3.5 * TILE_SIZE)
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 3.5 * TILE_SIZE)
	end
	for dx = -2.5, 2.5, 5 do
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 2.5 * TILE_SIZE)
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 2.5 * TILE_SIZE)
	end
	for dx = -3.5, 3.5, 7 do
		for dz = -2.5, 2.5, 5 do
			SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
			i = i + 1
			if not broken2 and brokenvar < i then
				broken2 = true
				brokenvar = math.random(4)
			end
		end
	end
end

--------------------------------------------------------------------------

defs["lore2"] = {}

defs.lore2.TerraformRoomAtXZ = function(inst, x, z)
	local terraformer = Terraformer()
	for col = -4, 4 do
		if col ~= 0 then
			for row = 3, 4 do
				terraformer:EraseTile(col, row)
				terraformer:EraseTile(col, -row)
			end
		end
	end
	for row = -2, 2 do
		if row ~= 0 then
			for col = 3, 4 do
				terraformer:EraseTile(col, row)
				terraformer:EraseTile(-col, row)
			end
		end
	end
	for row = -2, 2, 4 do
		for col = -2, 2, 4 do
			terraformer:EraseTile(col, row)
		end
	end
	terraformer:ApplyAtXZ(x, z)
end

defs.lore2.LayoutNewRoomAtXZ = function(inst, x, z)
	--runes
	local rune = SpawnPrefab("vault_rune")
	rune:SetId("lore2")
	rune.Transform:SetPosition(x, 0, z - 1.5 * TILE_SIZE)

	--statues
	local statue = SpawnPrefab("vault_statue")
	statue:SetId("gate")
	statue:SetScene("lore2")
	statue.Transform:SetPosition(x, 0, z)

	local statueids = { "ancient1", "ancient2", "ancient3", "bug1", "bug2", "bug3" }
	local dtheta = TWOPI / 7
	local extra = 4 * DEGREES
	local theta = 90 * DEGREES + dtheta - 2.5 * extra
	dtheta = dtheta + extra
	local r = 1.2 * TILE_SIZE
	for i = 1, 6 do
		statue = SpawnPrefab("vault_statue")
		statue:SetId(table.remove(statueids, math.random(#statueids)))
		statue:SetScene("lore2")
		statue.Transform:SetPosition(x + r * math.cos(theta), 0, z - 0.8 * r * math.sin(theta))
		theta = theta + dtheta
	end

	--variations
	local brokenvar = math.random(8)
	local i = 1

	--columns
	for dx = -2.5, 2.5, 5 do
		for dz = -2.5, 2.5, 5 do
			SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
			i = i + 1
		end
	end
	if brokenvar < i then
		brokenvar = math.random(3, 8)
	end
	for dx = -1.5, 1.5, 3 do
		for dz = -3.5, 3.5, 7 do
			SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
			SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dz * TILE_SIZE, 0, z + dx * TILE_SIZE)
			i = i + 1
		end
	end

	--lights
	SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z)

	--ground
	SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
end

--------------------------------------------------------------------------

defs["lore3"] = {}

defs.lore3.TerraformRoomAtXZ = function(inst, x, z)
	local terraformer = Terraformer()
	for row = 3, 4 do
		terraformer:EraseTile(-4, row)
		terraformer:EraseTile(4, row)
	end
	for row = 1, 2 do
		for col = 3, 4 do
			terraformer:EraseTile(col, row)
			terraformer:EraseTile(-col, row)
		end
	end
	for col = 2, 4 do
		terraformer:EraseTile(col, -1)
		terraformer:EraseTile(-col, -1)
	end
	for row = -4, -2 do
		for col = 1, 4 do
			terraformer:EraseTile(col, row)
			terraformer:EraseTile(-col, row)
		end
	end
	terraformer:ApplyAtXZ(x, z)
end

defs.lore3.LayoutNewRoomAtXZ = function(inst, x, z)
	--runes
	local rune = SpawnPrefab("vault_rune")
	rune:SetId("lore3")
	rune.Transform:SetPosition(x, 0, z)

	--variations
	local brokenvarbk = math.random(0, 2) * 7 - 3.5
	local brokenvarfr = math.random(5)
	local i = 1
	local guardvars = { 1, 1, 2, 2, 2, 3, 3, math.random(3) } --1 & 3 are quite similar

	--statues
	for dx = -1.5, 1.5, 1 do
		local statue = SpawnPrefab("vault_statue")
		statue:SetId("guard"..table.remove(guardvars, math.random(#guardvars)))
		statue:SetScene("lore3")
		statue.Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 1.5 * TILE_SIZE)
	end
	for dx = -2, 2, 1 do
		if dx ~= 0 then
			local statue = SpawnPrefab("vault_statue")
			statue:SetId("guard"..table.remove(guardvars, math.random(#guardvars)))
			statue:SetScene("lore3")
			statue.Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 3 * TILE_SIZE)
		end
	end

	--columns
	for dx = -3.5, 3.5, 7 do
		SpawnPrefab("vault_pillar"):MakeBroken(dx == brokenvarbk).Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 1.5 * TILE_SIZE)
		SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvarfr).Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 1.5 * TILE_SIZE)
		i = i + 1
	end
	for dx = -2.5, 2.5, 5 do
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 1.5 * TILE_SIZE)
	end
	for dx = -1.5, 1.5, 3 do
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 2.5 * TILE_SIZE)
		SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvarfr).Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 3.5 * TILE_SIZE)
		i = i + 1
	end

	--lights
	SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z)

	--ground
	SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)

	--beta
	--SpawnPrefab("temp_beta_msg").Transform:SetPosition(x + 0.55 * TILE_SIZE, 0, z + 4.6 * TILE_SIZE)
end

--------------------------------------------------------------------------

defs["teleport1"] = {}

defs.teleport1.TerraformRoomAtXZ = function(inst, x, z)
	local terraformer = Terraformer()
	for col = -4, 4 do
		if col ~= 0 then
			terraformer:EraseTile(col, 4)
		end
	end
	for row = -1, 3 do
		if row ~= 0 then
			terraformer:EraseTile(4, row)
			terraformer:EraseTile(-4, row)
		end
	end
	for row = 2, 3 do
		for col = 2, 3 do
			terraformer:EraseTile(col, row)
			terraformer:EraseTile(-col, row)
		end
	end
	for col = 2, 4 do
		terraformer:EraseTile(col, -2)
		terraformer:EraseTile(-col, -2)
	end
	for row = -4, -3 do
		for col = -4, 4 do
			if col ~= 0 then
				terraformer:EraseTile(col, row)
			end
		end
	end
	terraformer:ApplyAtXZ(x, z)
end

defs.teleport1.LayoutNewRoomAtXZ = function(inst, x, z)
	--runes
	local rune = SpawnPrefab("vault_rune")
	rune:SetId("teleport1")
	rune.Transform:SetPosition(x, 0, z)

	--variations
	local brokenvar = math.random(0, 2) * 5 - 2.5

	--columns
	for dx = -2.5, 2.5, 5 do
		SpawnPrefab("vault_pillar"):MakeBroken(brokenvar == dx).Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 2.5 * TILE_SIZE)
		SpawnPrefab("vault_pillar").Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 2.5 * TILE_SIZE)
	end
	for dx = -1.5, 1.5, 3 do
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 3.5 * TILE_SIZE)
	end

	--lights
	SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z)

	--ground
	SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
end

--------------------------------------------------------------------------

defs["mask1"] = {}

defs.mask1.TerraformRoomAtXZ = function(inst, x, z)
	local terraformer = Terraformer()
	for col = -5, 5, 10 do
		for row = -1, 1 do
			terraformer:EraseTile(col, row)
		end
	end
	for col = -4, 4 do
		if col ~= 0 then
			terraformer:EraseTile(col, 4)
			for row = -4, -2 do
				terraformer:EraseTile(col, row)
			end
		end
	end
	for col = 2, 4 do
		for row = 2, 3 do
			terraformer:EraseTile(col, row)
			terraformer:EraseTile(-col, row)
		end
	end
	terraformer:EraseTile(-4, 1)
	terraformer:EraseTile(4, 1)
	terraformer:EraseTile(1, -1)
	terraformer:EraseTile(-1, -1)
	terraformer:ApplyAtXZ(x, z)
end

defs.mask1.LayoutNewRoomAtXZ = function(inst, x, z)
	--husks
	SpawnPrefab("ancient_husk"):SetId("handmaid").Transform:SetPosition(x, 0, z + TILE_SIZE)
	SpawnPrefab("ancient_husk"):SetId("mason").Transform:SetPosition(x - 2.5 * TILE_SIZE, 0, z)
	SpawnPrefab("ancient_husk"):SetId("architect").Transform:SetPosition(x + 2.5 * TILE_SIZE, 0, z)

	--masks
	SpawnPrefab("mask_ancient_handmaidhat").Transform:SetPosition(x + 0.4, 0, z + TILE_SIZE - 2)
	SpawnPrefab("mask_ancient_masonhat").Transform:SetPosition(x - 2.5 * TILE_SIZE + 0.5, 0, z - 2.25)
	SpawnPrefab("mask_ancient_architecthat").Transform:SetPosition(x + 2.5 * TILE_SIZE - 1.5, 0, z - 1.85)

	--variations
	local groundvar = math.random(2)
	local groundvar1 = math.random(4)
	local groundvar2 = math.random(3)
	groundvar2 = groundvar2 >= groundvar1 and groundvar2 + 1 or groundvar2
	local lightvar = math.random(3)
	local lightvar1 = math.random(2)
	local lightvar2 = lightvar1 == 1 and 2 or 1
	local brokenvar = math.random(4)
	local broken2
	local i = 1

	--columns
	for dx = -1.5, 1.5, 3 do
		SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 2.5 * TILE_SIZE)
		SpawnPrefab("vault_pillar"):MakeBroken(i + 1 == brokenvar).Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 3.5 * TILE_SIZE)
		i = i + 2
		if not broken2 and brokenvar < i then
			brokenvar = math.random(i, 8)
		end
	end
	for dx = -2.5, 2.5, 5 do
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 2.5 * TILE_SIZE)
	end
	for dx = -3.5, 3.5, 7 do
		SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 2.5 * TILE_SIZE)
		i = i + 1
	end
	if brokenvar < i then
		brokenvar = math.random(5, 8)
	end
	for dx = -2.5, 2.5, 5 do
		SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 2.5 * TILE_SIZE)
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 3.5 * TILE_SIZE)
		i = i + 1
	end
	for dx = -3.5, 3.5, 7 do
		SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 2.5 * TILE_SIZE)
	end

	--lights
	SpawnPrefab("vault_chandelier"):SetVariation(lightvar == 1 and lightvar1 or lightvar2).Transform:SetPosition(x, 0, z + TILE_SIZE)
	SpawnPrefab("vault_chandelier"):SetVariation(lightvar == 2 and lightvar1 or lightvar2).Transform:SetPosition(x - 2.5 * TILE_SIZE, 0, z)
	SpawnPrefab("vault_chandelier"):SetVariation(lightvar == 3 and lightvar1 or lightvar2).Transform:SetPosition(x + 2.5 * TILE_SIZE, 0, z)

	--ground
	SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(groundvar == 1 and 1 or 2):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z + TILE_SIZE)
	SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(groundvar == 2 and 1 or 2):SetOrientation(groundvar1).Transform:SetPosition(x - 2.5 * TILE_SIZE, 0, z)
	SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(groundvar == 2 and 1 or 2):SetOrientation(groundvar2).Transform:SetPosition(x + 2.5 * TILE_SIZE, 0, z)
end

--------------------------------------------------------------------------

defs["generator1"] = {}

defs.generator1.TerraformRoomAtXZ = function(inst, x, z)
	local terraformer = Terraformer()
	for row = 2, 4 do
		for col = -4, 4 do
			if col ~= 0 then
				terraformer:EraseTile(col, row)
			end
		end
	end
	for col = 3, 4 do
		terraformer:EraseTile(col, 1)
		terraformer:EraseTile(-col, 1)
	end
	for col = 3, 4 do
		terraformer:EraseTile(col, -1)
		terraformer:EraseTile(-col, -1)
	end
	for col = 2, 4 do
		terraformer:EraseTile(col, -2)
		terraformer:EraseTile(-col, -2)
	end
	for row = -4, -3 do
		for col = -4, 4 do
			if col ~= 0 then
				terraformer:EraseTile(col, row)
			end
		end
	end
	terraformer:ApplyAtXZ(x, z)
end

defs.generator1.LayoutNewRoomAtXZ = function(inst, x, z)
	--switch
	SpawnPrefab("vault_switch_base").Transform:SetPosition(x, 0, z)

	--variations
	local lightvar = math.random(3)
	local lightvar1 = math.random(2)
	local lightvar2 = lightvar1 == 1 and 2 or 1
	local brokenvar = math.random(4)
	local i = 1

	--columns
	for dx = -1.5, 1.5, 3 do
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 3.5 * TILE_SIZE)
	end
	for dx = -1.5, 1.5, 3 do
		SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 2.5 * TILE_SIZE)
	end
	for dx = -2.5, 2.5, 5 do
		SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SIZE, 0, z + 2.5 * TILE_SIZE)
		i = i + 1
	end
	for dz = 1.5, -1.5, -3 do
		for dx = -3.5, 3.5, 7 do
			SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
			i = i + 1
			if brokenvar < i and i <= 5 then
				brokenvar = math.random(i, 6)
			end
		end
	end
	for dx = -2.5, 2.5, 5 do
		SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 2.5 * TILE_SIZE)
	end
	for dx = -1.5, 1.5, 3 do
		SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z - 3.5 * TILE_SIZE)
	end

	--lights
	for i = 1, 3 do
		local theta = (90 + 120 * i) * DEGREES
		local r = 2.95
		SpawnPrefab("vault_chandelier"):SetVariation(lightvar == i and lightvar1 or lightvar2).Transform:SetPosition(x + math.cos(theta) * r, 0, z - math.sin(theta) * r)
	end

	--ground
	SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
end

--------------------------------------------------------------------------

local function fountain_TerraformRoomAtXZ(inst, x, z)
	local terraformer = Terraformer()
	for row = 2, 4 do
		for col = -4, 4 do
			if col ~= 0 then
				terraformer:EraseTile(col, row)
				terraformer:EraseTile(col, -row)
			end
		end
	end
	for row = -1, 1, 2 do
		for col = 3, 4 do
			terraformer:EraseTile(col, row)
			terraformer:EraseTile(-col, row)
		end
	end
	terraformer:ApplyAtXZ(x, z)
end

local function fountain_LayoutNewRoomAtXZ(inst, x, z, product)
	--fountain
	local fountain = SpawnPrefab("archive_lockbox_dispencer")
	fountain:SetProductOrchestrina(product)
	fountain.Transform:SetPosition(x, 0, z)

	--variations
	local brokenvart = math.random(4)
	local brokenvarb = math.random(4)
	local broken2t, broken2b
	local it, ib = 1, 1

	--columns
	for dz = -1.5, 1.5, 3 do
		for dx = -3.5, 3.5, 7 do
			SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
		end
	end
	for dz = -2.5, 2.5, 5 do
		for dx = -2.5, 2.5, 5 do
			SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
		end
	end
	for dx = -1.5, 1.5, 3 do
		for dz = 2.5, 3.5, 1 do
			SpawnPrefab("vault_pillar"):MakeBroken(brokenvart == it).Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
			it = it + 1
		end
		if not broken2t and brokenvart < it then
			broken2t = true
			brokenvart = math.random(4)
		end
		for dz = -3.5, -2.5, 1 do
			SpawnPrefab("vault_pillar"):MakeBroken(brokenvarb == ib).Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
			ib = ib + 1
		end
		if not broken2b and brokenvarb < ib then
			broken2b = true
			brokenvarb = math.random(4)
		end
	end

	--lights
	SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z)

	--ground
	SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
end

defs["fountain1"] = {}
defs["fountain2"] = {}
defs.fountain1.TerraformRoomAtXZ = fountain_TerraformRoomAtXZ
defs.fountain2.TerraformRoomAtXZ = fountain_TerraformRoomAtXZ
defs.fountain1.LayoutNewRoomAtXZ = function(inst, x, z) fountain_LayoutNewRoomAtXZ(inst, x, z, "turf_vault") end
defs.fountain2.LayoutNewRoomAtXZ = function(inst, x, z) fountain_LayoutNewRoomAtXZ(inst, x, z, "vaultrelic") end

--------------------------------------------------------------------------

defs["playbill1"] = {}

defs.playbill1.TerraformRoomAtXZ = function(inst, x, z)
	local terraformer = Terraformer()
	for row = 3, 4 do
		for col = -4, 4 do
			if col ~= 0 then
				terraformer:EraseTile(col, row)
				terraformer:EraseTile(col, -row)
			end
		end
	end
	for row = 1, 2 do
		for col = -4, -3 do
			terraformer:EraseTile(col, row)
			terraformer:EraseTile(-col, -row)
		end
		for col = 3 - row, 4 do
			terraformer:EraseTile(col, row)
			terraformer:EraseTile(-col, -row)
		end
	end
	terraformer:ApplyAtXZ(x, z)
end

defs.playbill1.LayoutNewRoomAtXZ = function(inst, x, z)
	--variations
	local lightvar = math.random(3)
	local groundvar = math.random(2)
	local brokenvar = math.random(4)
	local playbillvar = math.random(2)
	local tablevar = math.random(2)
	local i = 1
	local stoolvars = { 1, 2, 3, 4 }
	--shuffle
	for i = 1, #stoolvars - 1 do
		local rnd = math.random(i, #stoolvars)
		if rnd ~= i then
			local tmp = stoolvars[i]
			stoolvars[i] = stoolvars[rnd]
			stoolvars[rnd] = tmp
		end
	end

	--furniture
	for j = 1, 2 do
		local spread = j > 1 and -1 or 1
		local x1 = x - spread * TILE_SIZE
		local z1 = z + spread * TILE_SIZE
		SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(j == groundvar and 2 or 1):SetOrientation(math.random(4)).Transform:SetPosition(x1, 0, z1)
		local decortable = SpawnPrefab("vault_table_round")
		decortable:SetVariation(j == tablevar and 3 or 2)
		decortable.Transform:SetPosition(x1, 0, z1)
		if j == playbillvar then
			decortable.components.furnituredecortaker:AcceptDecor(SpawnPrefab("playbill_the_vault"), TheWorld)
		end
		SpawnPrefab("vault_chandelier"):SetVariation(j == lightvar and 2 or 1).Transform:SetPosition(x1, 0, z1)
		local theta = math.random() * TWOPI
		local delta = TWOPI / 3
		local r = 2.1
		for i = 1, 3 do
			theta = theta + delta
			local stool = SpawnPrefab("vault_stool")
			local rnd = math.random()
			rnd = math.clamp(math.ceil(rnd * rnd * 3), 1, 3)
			rnd = table.remove(stoolvars, rnd)
			table.insert(stoolvars, rnd)
			stool:SetVariation(rnd)
			stool.Transform:SetPosition(x1 + r * math.cos(theta), 0, z1 - r * math.sin(theta))
			stool.Transform:SetRotation(theta * RADIANS + 180)
		end
	end
	SpawnPrefab("vault_chandelier_decor"):SetVariation(2).Transform:SetPosition(x, 0, z)

	--columns
	for dx = -1.5, 1.5, 3 do
		for dz = -3.5, 3.5, 7 do
			SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
			SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dz * TILE_SIZE, 0, z + dx * TILE_SIZE)
		end
	end
	SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x - 2.5 * TILE_SIZE, 0, z + 3.5 * TILE_SIZE)
	SpawnPrefab("vault_pillar"):MakeBroken(i + 1 == brokenvar).Transform:SetPosition(x - 3.5 * TILE_SIZE, 0, z + 2.5 * TILE_SIZE)
	i = i + 2
	if brokenvar < i then
		brokenvar = math.random(2, 4)
	end
	SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + 2.5 * TILE_SIZE, 0, z - 3.5 * TILE_SIZE)
	SpawnPrefab("vault_pillar"):MakeBroken(i + 1 == brokenvar).Transform:SetPosition(x + 3.5 * TILE_SIZE, 0, z - 2.5 * TILE_SIZE)
	i = i + 2
	brokenvar = math.random(5, 7)
	for dx = 1.5, 2.5, 1 do
		local dz = 4 - dx
		SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SIZE, 0, z + dz * TILE_SIZE)
		SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x - dx * TILE_SIZE, 0, z - dz * TILE_SIZE)
		i = i + 1
	end
end

--------------------------------------------------------------------------

return defs
