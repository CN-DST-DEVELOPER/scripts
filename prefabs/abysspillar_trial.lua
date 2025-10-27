local assets =
{
	Asset("ANIM", "anim/vault_switch.zip"),
	Asset("MINIMAP_IMAGE", "vault_switch"),
}

local prefabs =
{
	"abysspillar",
	"abysspillar_fx",
	"abysspillar_minion",
}

local SPACING = 3.25
local COALLAPSING_DELAY = 1
local FORMING_DELAY = 2

local function GridId(row, col)
	return string.format("%d,%d", row, col)
end

local function GetGridPillar(inst, row, col)
	return inst.grid[GridId(row, col)]
end

local function SetGridPillar(inst, row, col, pillar)
	local id = GridId(row, col)
	if inst.grid[id] == nil then
		inst.grid[id] = pillar
		pillar.row, pillar.col = row, col
	end
end

local function RemoveGridPillar(inst, pillar)
	local id = pillar.row and GridId(pillar.row, pillar.col)
	if inst.grid[id] == pillar then
		inst.grid[id] = nil
		pillar.row, pillar.col = nil
	end
end

local function IsGridPillar(inst, pillar)
	return pillar and pillar.row and inst.grid[GridId(pillar.row, pillar.col)] == pillar
end

local function IsValidDir(dirx, dirz)
	return (dirx == 0 or dirx == -1 or dirx == 1)
		and (dirz == 0 or dirz == -1 or dirz == 1)
		and (dirx == 0) ~= (dirz == 0)
end

local function IsValidTrial(inst)
	return inst.x0 and inst.z0 and IsValidDir(inst.dirx, inst.dirz)
end

local function _torowcol(inst, x, z)
	local dx = math.floor((x - inst.x0) / SPACING + 0.5)
	local dz = math.floor((z - inst.z0) / SPACING + 0.5)
	local row, col
	if inst.dirx ~= 0 then
		return math.floor(dx * inst.dirx + 0.5), math.floor(0.5 - dz * inst.dirx)
	else--if inst.dirz ~= 0 then
		return math.floor(dz * inst.dirz + 0.5), math.floor(dx * inst.dirz + 0.5)
	end
end

local function _toxz(inst, row, col)
	local dx = inst.dirx * SPACING
	local dz = inst.dirz * SPACING
	return inst.x0 + row * dx + col * dz, inst.z0 + row * dz - col * dx
end

local function DoSpawnPillarAtXZ(inst, x, z, instant)
	if not instant then
		local fx = SpawnPrefab("abysspillar_fx")
		fx.Transform:SetPosition(x, 0, z)
		if not fx:IsAsleep() then
			if math.random() < 0.5 then
				fx:Flip()
			end
			local delay
			if inst.randomspawndelay then
				--max delay for entrance
				--no delay for exit
				local row, col = _torowcol(inst, x, z)
				delay =
					row == 0 and 0.5 or
					row ~= 6 and math.random() * 0.5 or
					nil
			end
			fx:StartForming(inst, delay)
			return fx
		end
		fx:Remove()
	end

	local pillar = SpawnPrefab("abysspillar")
	pillar.Transform:SetPosition(x, 0, z)
	if math.random() < 0.5 then
		pillar:Flip()
	end
	return pillar
end

local function DoCollapsePillar(inst, pillar)
	if pillar.components.walkableplatform then --make sure it's not a forming fx
		if inst.collapsequeue then
			table.insert(inst.collapsequeue, pillar)
		else
			pillar:CollapsePillar()
		end
	end
end

local function SpawnGridPillar(inst, row, col)
	inst.components.abysspillargroup:SpawnPillarAtXZ(_toxz(inst, row, col))
end

local SpawnGridFns =
{
	--type 1
	function(inst)
		--entrance
		SpawnGridPillar(inst, 0, 0)
		--exit
		SpawnGridPillar(inst, 6, 0)
		--grid
		for row = 1, 5 do
			for col = -2, 2 do
				SpawnGridPillar(inst, row, col)
			end
		end
	end,

	--type 2
	function(inst)
		--entrance
		SpawnGridPillar(inst, 0, 0)
		--exit
		SpawnGridPillar(inst, 6, 1)
		SpawnGridPillar(inst, 6, -1)
		--grid
		for row = 1, 5 do
			for col = -2, 2 do
				SpawnGridPillar(inst, row, col)
			end
		end
	end,

	--type 3
	function(inst)
		--entrance
		SpawnGridPillar(inst, 0, math.random() < 0.5 and -1 or 1)
		--SpawnGridPillar(inst, 0, 1)
		--exit
		SpawnGridPillar(inst, 6, 0)
		--grid
		for row = 1, 5 do
			local len = row == 5 and 1 or 2
			for col = -len, len do
				SpawnGridPillar(inst, row, col)
			end
		end
	end,
}

local function CheckGridType(inst)
	return not inst.components.abysspillargroup:HasSpawnPoints() and
		(	(not GetGridPillar(inst, 0, 0) and 3) or
			(not GetGridPillar(inst, 6, 0) and 2) or
			1
		) or nil
end

local function ResetActivatable(inst)
	inst.components.activatable.inactive = true
end

local function DoSpawnNewGrid(inst)
	local map = TheWorld.Map
	local x, _, z = inst.spawnx, nil, inst.spawnz
	if x == nil then
		x, _, z = map:GetTileCenterPoint(inst.Transform:GetWorldPosition())
	end
	for dir = 0, 270, 90 do
		local theta = dir * DEGREES
		local dx, dz = math.cos(theta), -math.sin(theta)
		local dx1, dz1 = 4 * dx, 4 * dz
		local x1, z1 = x + dx1, z + dz1
		if not (map:IsPassableAtPoint(x1, 0, z1) or
				map:IsPassableAtPoint(x1 + dz1, 0, z1 - dx1) or
				map:IsPassableAtPoint(x1 - dz1, 0, z1 + dx1))
		then
			inst.dirx = (dx > 0.99 and 1) or (dx < -0.99 and -1) or 0
			inst.dirz = (dz > 0.99 and 1) or (dz < -0.99 and -1) or 0
			inst.x0 = math.floor(x1 + 2 * dx + 0.5)
			inst.z0 = math.floor(z1 + 2 * dz + 0.5)

			inst.randomspawndelay = true
			SpawnGridFns[math.random(#SpawnGridFns)](inst)
			inst.randomspawndelay = nil
			inst.task = inst:DoTaskInTime(FORMING_DELAY, ResetActivatable)
			return
		end
	end
	inst.task = inst:DoTaskInTime(0.5, ResetActivatable)
end

local function DoRespawn(inst)
	if inst.keepsamepuzzle and IsValidTrial(inst) then
		inst.keepsamepuzzle = nil
		inst.randomspawndelay = true
		inst.components.abysspillargroup:RespawnAllPillars()
		inst.randomspawndelay = nil
		inst.task = inst:DoTaskInTime(FORMING_DELAY, ResetActivatable)
	else
		inst.x0, inst.z0, inst.dirx, inst.dirz = nil
		inst.components.abysspillargroup:Clear()
		DoSpawnNewGrid(inst)
	end
end

local function OnActivate(inst, doer)
	if doer and doer:IsValid() then
		inst:ForceFacePoint(doer.Transform:GetWorldPosition())
	end
	inst.AnimState:PlayAnimation("activate")
	inst.AnimState:PushAnimation("idle", false)
	inst.SoundEmitter:PlaySound("rifts6/lever/pull")

	if inst.task then
		inst.task:Cancel()
	end

	--Return tracked mininons back to their off pillar
	for i = 1, #inst.minions do
		local v = inst.minions[i]
		inst.minions[i] = nil
		local bigpillar, leftminion = v.ent:GetBigPillar()
		if bigpillar then
			v.ent.sg:HandleEvent("deactivate")
		end
	end

	inst.collapsequeue = {}
	inst.components.abysspillargroup:CollapseAllPillars()
	local tocollapse = inst.collapsequeue
	inst.collapsequeue = nil

	inst.contestant = nil

	if #tocollapse > 0 then
		local pillar = table.remove(tocollapse, math.random(#tocollapse))
		pillar:CollapsePillar()
		for i = 2, math.floor(#tocollapse / 3) do
			pillar = table.remove(tocollapse, math.random(#tocollapse))
			pillar:DoTaskInTime(math.random() * 0.2, pillar.CollapsePillar)
		end
		for i = 1, math.ceil(#tocollapse / 2) do
			pillar = table.remove(tocollapse, math.random(#tocollapse))
			pillar:DoTaskInTime(0.1 + math.random() * 0.2, pillar.CollapsePillar)
		end
		for i, v in ipairs(tocollapse) do
			v:DoTaskInTime(0.2 + math.random() * 0.2, v.CollapsePillar)
		end
		inst.task = inst:DoTaskInTime(COALLAPSING_DELAY, DoRespawn)
	elseif inst.components.abysspillargroup:HasSpawnPoints() then
		DoRespawn(inst)
	else
		DoSpawnNewGrid(inst)
	end
end

local function OnAddPillar(inst, pillar)
	if not IsValidTrial(inst) then
		return
	elseif pillar.components.walkableplatform then --make sure it's not a forming fx
		local x, _, z = pillar.Transform:GetWorldPosition()
		local row, col = _torowcol(inst, x, z)
		SetGridPillar(inst, row, col, pillar)
		inst:ListenForEvent("abysspillar_playeroccupied", inst._onplayeroccupiedpillar, pillar)
		inst:ListenForEvent("abysspillar_playervacated", inst._onplayervacatedpillar, pillar)
	end
end

local function OnRemovePillar(inst, pillar)
	inst:RemoveEventCallback("abysspillar_playeroccupied", inst._onplayeroccupiedpillar, pillar)
	inst:RemoveEventCallback("abysspillar_playervacated", inst._onplayervacatedpillar, pillar)
	RemoveGridPillar(inst, pillar)
end

--------------------------------------------------------------------------

local GRID_UP = 0
local GRID_RIGHT = 1
local GRID_DOWN = 2
local GRID_LEFT = 3

local GRID_DIR_VECS =
{
	[GRID_UP] = { 1, 0 },
	[GRID_RIGHT] = { 0, 1 },
	[GRID_DOWN] = { -1, 0 },
	[GRID_LEFT] = { 0, -1 },
}

local PuzzlePiece = Class(function(self, ent, gridfacing)
	self.ent = ent
	self.gridfacing = gridfacing
end)

function PuzzlePiece:GetDir()
	local vec = GRID_DIR_VECS[self.gridfacing]
	return unpack(vec)
end

function PuzzlePiece:ChangeDir(drow, dcol)
	for gridfacing = 0, 3 do
		local vec = GRID_DIR_VECS[gridfacing]
		if drow == vec[1] and dcol == vec[2] then
			local turn = gridfacing - self.gridfacing
			self.gridfacing = gridfacing
			return turn
		end
	end
end

function PuzzlePiece:Turn(turn)
	self.gridfacing = (self.gridfacing + turn + 4) % 4
end

--dirx, dirz is the world orientation of the puzzle
--drow, dcol is the direction relative to the puzzle grid
function PuzzlePiece:SetWorldRotationRelativeTo(dirx, dirz)
	--assert(IsValidDir(dirx, dirz))
	local drow, dcol = self:GetDir()
	local dx, dz
	if dirx ~= 0 then
		dx = drow * dirx
		dz = -dcol * dirx
	else--if dirz ~= 0 then
		dz = drow * dirz
		dx = dcol * dirz
	end
	self.ent.Transform:SetRotation(math.floor(math.atan2(-dz, dx) * RADIANS + 0.5))
end

--------------------------------------------------------------------------

local function TrySpawnMinionAt(inst, row, col, gridfacing, leftminion, flip)
	if flip then
		col = -col
		gridfacing = (gridfacing == GRID_LEFT and GRID_RIGHT) or
					(gridfacing == GRID_RIGHT and GRID_LEFT) or
					gridfacing
		leftminion = not leftminion
	end

	local minion = inst.components.entitytracker:GetEntity(leftminion and "leftminion" or "rightminion")
	if minion and not minion:IsActivated() then
		local pillar = GetGridPillar(inst, row, col)
		if pillar and pillar:TryToReservePlatform(minion) then
			minion:RemoveFromBigPillar()
			minion:Activate()
			minion = PuzzlePiece(minion, gridfacing)
			minion.ent.Physics:Teleport(pillar.Transform:GetWorldPosition())
			minion:SetWorldRotationRelativeTo(inst.dirx, inst.dirz)
			table.insert(inst.minions, minion)
			inst:ListenForEvent("onremove", inst._onremoveminion, minion.ent)
			return minion
		end
	end
end

local function SpawnMinions(inst, flip)
	local gridtype = CheckGridType(inst)
	if gridtype == 1 then
		TrySpawnMinionAt(inst, 3, -1, GRID_RIGHT, true, flip)
		TrySpawnMinionAt(inst, 3, 1, GRID_LEFT, false, flip)
	elseif gridtype == 2 then
		TrySpawnMinionAt(inst, 5, -2, GRID_DOWN, true, flip)
		TrySpawnMinionAt(inst, 4, 2, GRID_LEFT, false, flip)
	elseif gridtype == 3 then
		TrySpawnMinionAt(inst, 3, 0, GRID_UP, true, flip)
		TrySpawnMinionAt(inst, 4, 2, GRID_DOWN, false, flip)
	end
end

local function PreSpawnMinions(inst)
	if CheckGridType(inst) then
		local minion = inst.components.entitytracker:GetEntity("leftminion")
		if minion then
			minion:PreActivate()
		end
		minion = inst.components.entitytracker:GetEntity("rightminion")
		if minion then
			minion:PreActivate()
		end
	end
end

local function SetMinion(inst, minion, leftminion)
	inst.components.entitytracker:TrackEntity(leftminion and "leftminion" or "rightminion", minion)
end

local function SetSpawnXZ(inst, x, z)
	inst.spawnx, inst.spawnz = x, z
end

--------------------------------------------------------------------------
--These are so we can detect earlier when a player is about to jump onto the first pillar

local function OnEntityWake(inst)
	if inst.players == nil then
		inst.players = {}

		inst:ListenForEvent("ms_playerjoined", inst._onplayerjoined, TheWorld)
		inst:ListenForEvent("ms_playerleft", inst._onplayerleft, TheWorld)

		for _, v in ipairs(AllPlayers) do
			inst._onplayerjoined(nil, v)
		end
	end
end

local function OnEntitySleep(inst)
	if inst.players then
		inst:RemoveEventCallback("ms_playerjoined", inst._onplayerjoined, TheWorld)
		inst:RemoveEventCallback("ms_playerleft", inst._onplayerleft, TheWorld)

		for k in pairs(inst.players) do
			inst._onplayerleft(nil, k)
		end

		inst.players = nil
	end
end

--------------------------------------------------------------------------

local function OnSave(inst, data)
	data.spawnx = inst.spawnx
	data.spawnz = inst.spawnz
	data.x0 = inst.x0
	data.z0 = inst.z0
	data.dirx = inst.dirx ~= 0 and inst.dirx or nil
	data.dirz = inst.dirz ~= 0 and inst.dirz or nil
end

local function OnLoad(inst, data, ents)
	if data then
		inst.spawnx = data.spawnx
		inst.spawnz = data.spawnz
		inst.x0 = data.x0
		inst.z0 = data.z0
		inst.dirx = data.dirx or (data.dirz and 0)
		inst.dirz = data.dirz or (data.dirx and 0)
	end
	if inst.components.abysspillargroup:HasSpawnPoints() then
		inst.keepsamepuzzle = true
	end
end

local function GetActivateVerb(inst, doer)
	return "PULL"
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	MakeSmallObstaclePhysics(inst, 0.5)

	inst.MiniMapEntity:SetIcon("vault_switch.png")

	inst.Transform:SetTwoFaced()

	inst.AnimState:SetBank("vault_switch")
	inst.AnimState:SetBuild("vault_switch")
	inst.AnimState:PlayAnimation("idle")

	inst.GetActivateVerb = GetActivateVerb

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")

	inst:AddComponent("abysspillargroup")
	inst.components.abysspillargroup:SetSpawnAtXZFn(DoSpawnPillarAtXZ)
	inst.components.abysspillargroup:SetCollapseFn(DoCollapsePillar)
	inst.components.abysspillargroup:SetOnAddPillarFn(OnAddPillar)
	inst.components.abysspillargroup:SetOnRemovePillarFn(OnRemovePillar)

	inst:AddComponent("activatable")
	inst.components.activatable.standingaction = true
	inst.components.activatable.OnActivate = OnActivate

	inst:AddComponent("entitytracker")

	inst.spawnx = nil
	inst.spawnz = nil
	inst.grid = {}
	inst.minions = {}
	inst.players = nil
	inst.contestant = nil

	inst._onplayeroccupiedpillar = function(pillar, player)
		if inst.contestant == nil and IsValidTrial(inst) and pillar.row == 0 and
			not inst.components.abysspillargroup:HasSpawnPoints()
		then
			inst.contestant = PuzzlePiece(player, GRID_UP)
			SpawnMinions(inst, pillar.col < 0 or (pillar.col == 0 and math.random() < 0.5))
			inst.keepsamepuzzle = true
		elseif inst.contestant and inst.contestant.ent == player and pillar.row == 6 then
			inst.keepsamepuzzle = nil
		end
	end

	inst._onplayervacatedpillar = function(pillar, player)
		if inst.contestant and player == inst.contestant.ent and IsValidTrial(inst) and
			player.components.embarker and player.sg:HasStateTag("boathopping")
		then
			local dest = player.components.embarker.embarkable
			if IsGridPillar(inst, dest) then
				local drow1 = dest.row - pillar.row
				local dcol1 = dest.col - pillar.col
				local turn = inst.contestant:ChangeDir(drow1, dcol1)
				if turn then
					for _, v in ipairs(inst.minions) do
						if v.ent.sg:HasStateTag("idle") then
							local vpillar = v.ent:GetCurrentPlatform()
							if IsGridPillar(inst, vpillar) then
								v:Turn(turn)
								v:SetWorldRotationRelativeTo(inst.dirx, inst.dirz)
								drow1, dcol1 = v:GetDir()
								vpillar = GetGridPillar(inst, vpillar.row + drow1, vpillar.col + dcol1)
								if vpillar and vpillar ~= dest and vpillar:TryToReservePlatform(v.ent) then
									local x1, _, z1 = vpillar.Transform:GetWorldPosition()
									v.ent.components.locomotor:StartHopping(x1, z1, vpillar)
								end
							end
						end
					end
				end
			end
		end
	end

	local function _onremoveplayer(player)
		inst.players[player] = nil
	end

	local function _onplayerhop(player)
		if inst.contestant == nil and IsValidTrial(inst) and
			not inst.components.abysspillargroup:HasSpawnPoints() and
			player:GetCurrentPlatform() == nil and player.components.embarker
		then
			local dest = player.components.embarker.embarkable
			if IsGridPillar(inst, dest) and dest.row == 0 then
				PreSpawnMinions(inst)
			end
		end
	end

	inst._onplayerjoined = function(_, player)
		if not inst.players[player] then
			inst.players[player] = true
			inst:ListenForEvent("onremove", _onremoveplayer, player)
			inst:ListenForEvent("onhop", _onplayerhop, player)
		end
	end

	inst._onplayerleft = function(_, player)
		if inst.players[player] then
			inst.players[player] = nil
			inst:RemoveEventCallback("onremove", _onremoveplayer, player)
			inst:RemoveEventCallback("onhop", _onplayerhop, player)
		end
	end

	inst._onremoveminion = function(ent)
		for i, v in ipairs(inst.minions) do
			if v.ent == ent then
				table.remove(inst.minions, i)
				break
			end
		end

		if not POPULATING then
			--Backup code to return tracked minions back to their off pillar in case
			--they were removed by means other than hitting the lever to reset.
			local bigpillar, leftminion = ent:GetBigPillar()
			if bigpillar then
				local newent = SpawnPrefab("abysspillar_minion")
				newent:SetOnBigPillar(bigpillar, leftminion)
				inst:SetMinion(newent, leftminion)
			end
		end
	end

	inst.SetSpawnXZ = SetSpawnXZ
	inst.SetMinion = SetMinion
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	inst.OnEntityWake = OnEntityWake
	inst.OnEntitySleep = OnEntitySleep

	return inst
end

return Prefab("abysspillar_trial", fn, assets, prefabs)
