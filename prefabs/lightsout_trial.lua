local prefabs =
{
	"abysspillar",
	"abysspillar_fx",
	"shadowhand",
	"vault_torch",
}

local function OnTorchAdded(inst, torch)
	inst:ListenForEvent("machineturnedon", inst._ontorchtoggled, torch)
	inst:ListenForEvent("machineturnedoff", inst._ontorchtoggled, torch)
end

local GridVariations =
{
	{	stuck = { -1, 1 },	nointeract = { 0, 0 }	},
	{	stuck = { -1, 1 },	nointeract = { 1, 0 }	},
	{	stuck = { -1, 1 },	nointeract = { 1, -1 }	},
	{	stuck = { 0, 1 },	nointeract = { -1, 1 }	},
	{	stuck = { 0, 0 },	nointeract = { -1, 1 }	},
	{	stuck = { 0, 0 },	nointeract = { 0, 1 }	},
}

local function ResetTorch(inst, torch)
	torch:MakeNormal()
	torch.components.machine:TurnOff()
end

local function SetupPuzzle(inst)
	inst.busytoggling = true

	if inst.components.vaulttorchgrid.numcols == 3 and inst.components.vaulttorchgrid.numrows == 3 then
		inst.components.vaulttorchgrid:ForEach(ResetTorch)
	else
		inst.components.vaulttorchgrid:Initialize(3, 3, 6)
	end

	local var = GridVariations[math.random(#GridVariations)]
	local stuckcol, stuckrow = unpack(var.stuck)
	local nointeractcol, nointeractrow = unpack(var.nointeract)

	if math.random() < 0.5 then
		--flip horizontal
		stuckcol = -stuckcol
		nointeractcol = -nointeractcol
	end

	local rnd = math.random()
	if rnd < 0.25 then
		--rotate 90 degrees
		local temp = stuckcol
		stuckcol = stuckrow
		stuckrow = -temp
		temp = nointeractcol
		nointeractcol = nointeractrow
		nointeractrow = -temp
	elseif rnd < 0.5 then
		--rotate -90 degrees
		local temp = stuckcol
		stuckcol = -stuckrow
		stuckrow = temp
		temp = nointeractcol
		nointeractcol = -nointeractrow
		nointeractrow = temp
	elseif rnd < 0.75 then
		--rotate 180 degrees (double flip)
		stuckcol = -stuckcol
		stuckrow = -stuckrow
		nointeractcol = -nointeractcol
		nointeractrow = -nointeractrow
	end

	local torch = inst.components.vaulttorchgrid:GetTorch(stuckcol, stuckrow)
	if torch then
		torch:MakeStuckOn()
	end
	torch = inst.components.vaulttorchgrid:GetTorch(nointeractcol, nointeractrow)
	if torch then
		torch:MakeBroken()
	end

	inst.busytoggling = false

	if inst.components.abysspillargroup:HasPillars() then
		inst.components.abysspillargroup:CollapseAllPillars()
	elseif not inst.components.abysspillargroup:HasSpawnPoints() then
		local x, _, z = inst.Transform:GetWorldPosition()
		local spacing = 3.25
		local dz = 3.5 * 4
		for dx1 = -0.5, 0.5, 1 do
			local dx = dx1 * spacing
			inst.components.abysspillargroup:AddPillarSpawnPointXZ(x + dx, z + dz)
			inst.components.abysspillargroup:AddPillarSpawnPointXZ(x + dz, z + dx)
			inst.components.abysspillargroup:AddPillarSpawnPointXZ(x - dz, z + dx)
		end
	end
end

local function GatherHandSpawnPoints(inst, torch)
	if torch.col and torch.row then
		local toskip = {}
		if torch.col == 0 then
			if torch.row == 0 then
				--center torch, skip all corner spawns
				table.insert(toskip, { -1.5, -1.5 })
				table.insert(toskip, { 1.5, -1.5 })
				table.insert(toskip, { -1.5, 1.5 })
				table.insert(toskip, { 1.5, 1.5 })
			else
				--edge torch:
				--skip far corners
				table.insert(toskip, { -1.5, -1.5 * torch.row })
				table.insert(toskip, { 1.5, -1.5 * torch.row })
				--skip adjacent edges far spawns
				table.insert(toskip, { -1.5, -0.5 * torch.row })
				table.insert(toskip, { 1.5, -0.5 * torch.row })
			end
		elseif torch.row == 0 then
			--edge torch:
			--skip far corners
			table.insert(toskip, { -1.5 * torch.col, -1.5 })
			table.insert(toskip, { -1.5 * torch.col, 1.5 })
			--skip adjacent edges far spawns
			table.insert(toskip, { -0.5 * torch.col, -1.5 })
			table.insert(toskip, { -0.5 * torch.col, 1.5 })
		else
			--corner torch:
			--exclude opposite corner
			table.insert(toskip, { -1.5 * torch.col, -1.5 * torch.row })
			--exclude oppsite edges far spawns
			table.insert(toskip, { -1.5 * torch.col, -0.5 * torch.row })
			table.insert(toskip, { -0.5 * torch.col, -1.5 * torch.row })
		end

		local pts = {}
		for row = -1.5, 1.5, 1 do
			for col = -1.5, 1.5, row == 1.5 and 1 or 3 do
				local skip = false
				for _, v in ipairs(toskip) do
					if v[1] == col and v[2] == row then
						skip = true
						break
					end
				end
				if not skip then
					if math.abs(col - torch.col) < 1 and (torch.row == 0 or ((row < 0) == (torch.row < 0))) then
						col = col < torch.col and col - 0.25 or col + 0.25
					elseif math.abs(row - torch.row) < 1 and (torch.col == 0 or ((col < 0) == (torch.col < 0))) then
						row = row < torch.row and row - 0.25 or row + 0.25
					end
					local x = (col <= -1.5 and -11) or (col >= 1.5 and 11) or 6 * col
					local z = (row <= -1.5 and -11) or (row >= 1.5 and 11) or 6 * row
					table.insert(pts, { x, z })
				end
			end
		end

		--special spawn points on the entrance side
		if torch.col == 0 or torch.row == -1 then
			table.insert(pts, { -7, -11 })
			table.insert(pts, { 7, -11 })
		end

		return pts
	end
end

local function GetNearestPlayerDistSq(x, z)
	local dsq = math.huge
	local vaultroommanager = TheWorld.components.vaultroommanager
	if vaultroommanager then
		for k in pairs(vaultroommanager.players) do
			local x1, _, z1 = k.Transform:GetWorldPosition()
			dsq = math.min(dsq, distsq(x, z, x1, z1))
		end
	else
		for _, v in ipairs(AllPlayers) do
			local x1, _, z1 = k.Transform:GetWorldPosition()
			dsq = math.min(dsq, distsq(x, z, x1, z1))
		end
	end
	return dsq
end

local function SortByScore(a, b)
	return a.score < b.score
end

local function PickHandSpawnPoint(inst, torch)
	local pts = GatherHandSpawnPoints(inst, torch)
	if pts then
		local x, z = torch.col * 6, torch.row * 6
		for i, v in ipairs(pts) do
			v.distsq = distsq(x, z, v[1], v[2])
			v.distsq = math.abs(12 - math.sqrt(v.distsq))
			v.distsq = math.floor(v.distsq / 2) * 2
			v.distsq = v.distsq * v.distsq
			v.score = math.huge
			local nearsq = GetNearestPlayerDistSq(unpack(v))
			for d = 6, 1, -1 do
				local dd = d * d
				if nearsq >= dd then
					v.score = v.distsq / dd
					break
				end
			end
		end
		table.sort(pts, SortByScore)
		local score = pts[1].score
		local n = #pts
		for i = 2, n do
			if pts[i].score ~= score then
				n = i - 1
				break
			end
		end
		return pts[math.random(n)]
	end
end

local function IsPlayerNear(player, x, z)
	if IsEntityDeadOrGhost(player) or not player.entity:IsVisible() then
		return false
	end
	local x1, _, z1 = player.Transform:GetWorldPosition()
	return math.abs(x - x1) < 12 and math.abs(z - z1) < 12
end

local function DoPlayerAnnounce(hand, players, inst, x, z)
	if inst:IsValid() then
		while #players > 0 do
			local player = table.remove(players, math.random(#players))
			if player:IsValid() and IsPlayerNear(player, x, z) then
				player:PushEvent("see_lightsout_shadowhand")
				hand:DoTaskInTime(2 + 2 * math.random(), DoPlayerAnnounce, players, inst, x, z)
				return
			end
		end
	end
end

local function TryHelpBrokenTorch(inst, torch)
	if torch:IsBroken() and torch.components.machine:IsOn() then
		assert(inst.hand == nil)
		local pt = PickHandSpawnPoint(inst, torch)
		if pt then
			local x, _, z = inst.Transform:GetWorldPosition()
			inst.hand = SpawnPrefab("shadowhand")
			inst.hand.Transform:SetPosition(x + pt[1], 0, z + pt[2])
			inst.hand:SetTargetFire(torch, ACTIONS.TURNOFF)
			inst:ListenForEvent("onremove", inst._onhandremoved, inst.hand)

			local players = {}
			local vaultroommanager = TheWorld.components.vaultroommanager
			if vaultroommanager then
				for k in pairs(vaultroommanager.players) do
					if IsPlayerNear(k, x, z) then
						table.insert(players, k)
					end
				end
			else
				for _, v in ipairs(AllPlayers) do
					if IsPlayerNear(v, x, z) then
						table.insert(players, v)
					end
				end
			end

			inst.hand:DoTaskInTime(1 + math.random(), DoPlayerAnnounce, players, inst, x, z)
		end
		return true --breaks out of ForEach
	end
end

local function OnHandDelayOver(inst)
	inst.handdelay = nil
	if not inst.helped then
		local x, _, z = inst.Transform:GetWorldPosition()
		local playernear
		local vaultroommanager = TheWorld.components.vaultroommanager
		if vaultroommanager then
			for k in pairs(vaultroommanager.players) do
				if IsPlayerNear(k, x, z) then
					playernear = true
					break
				end
			end
		else
			for _, v in ipairs(AllPlayers) do
				if IsPlayerNear(v, x, z) then
					playernear = true
					break
				end
			end
		end
		if playernear then
			inst.components.vaulttorchgrid:ForEach(TryHelpBrokenTorch)
		else
			inst.handdelay = inst:DoTaskInTime(3, OnHandDelayOver)
		end
	end
end

local function ToggleTorch(inst, torch)
	torch:ToggleOnOff()
	if torch:IsBroken() then
		if inst.handdelay then
			inst.handdelay:Cancel()
			inst.handdelay = nil
		end
		if not (inst.helped or inst.hand or inst:IsAsleep()) and torch.components.machine:IsOn() then
			inst.handdelay = inst:DoTaskInTime(1.5 + math.random() * 0.5, OnHandDelayOver)
		end
	end
end

--------------------------------------------------------------------------

local function DoSpawnPillarAtXZ(inst, x, z, instant)
	if not instant then
		local fx = SpawnPrefab("abysspillar_fx")
		fx.Transform:SetPosition(x, 0, z)
		if not fx:IsAsleep() then
			if math.random() < 0.5 then
				fx:Flip()
			end
			local delay = math.random() * 0.5
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
		pillar:DoTaskInTime(math.random() * 0.3, pillar.CollapsePillar)
	end
end

local function RefreshPillars(inst)
	if inst.refreshpillarstask then
		inst.refreshpillarstask:Cancel()
		inst.refreshpillarstask = nil
	end
	if inst.solved then
		inst.components.abysspillargroup:RespawnAllPillars()
	else
		inst.components.abysspillargroup:CollapseAllPillars()
	end
end

local function OnAddPillar(inst, pillar)
	if pillar.MakeNonCollapsible then --make sure it's not a forming fx
		pillar:MakeNonCollapsible()
	end
	if not inst.solved and inst.refreshpillarstask == nil then
		inst.refreshpillarstask = inst:DoTaskInTime(0, RefreshPillars)
	end
end

local function OnRemovePillar(inst, pillar)
	if inst.solved and inst.refreshpillarstask == nil then
		inst.refreshpillarstask = inst:DoTaskInTime(0, RefreshPillars)
	end
end

--------------------------------------------------------------------------

local function CheckAllTorchesSolved(inst, torch)
	if not torch.components.machine:IsOn() then
		inst.solved = false
		return true --breaks out of ForEach
	end
end

local function CheckForHelpOnWake(inst, torch)
	if torch:IsBroken() then
		if torch.components.machine:IsOn() then
			inst.handdelay = inst:DoTaskInTime(3 + math.random(), OnHandDelayOver)
		end
		return true --breaks out of ForEach
	end
end

local function OnEntityWake(inst)
	if not (inst.helped or inst.hand or inst.handdelay) then
		inst.components.vaulttorchgrid:ForEach(CheckForHelpOnWake)
	end
end

local function OnEntitySleep(inst)
	if inst.handdelay then
		inst.handdelay:Cancel()
		inst.handdelay = nil
	end
	if inst.hand then
		inst:RemoveEventCallback("onremove", inst._onhandremoved, inst.hand)
		inst.hand:Remove()
		inst.hand = nil
	end
end

local function OnSave(inst, data)
	data.helped = inst.helped or nil
end

local function OnPreLoad(inst)--, data, ents)
	inst.busytoggling = true
	inst.components.abysspillargroup:SetOnAddPillarFn(nil)
	inst.components.abysspillargroup:SetOnRemovePillarFn(nil)
end

local function ValidateHandHelp(inst)
	if inst.solved then
		--just in case of error, force all the values to be correct
		inst.helped = true
		if inst.handdelay then
			inst.handdelay:Cancel()
			inst.handdelay = nil
		end
		if inst.hand then
			inst:RemoveEventCallback("onremove", inst._onhandremoved, inst.hand)
			if inst.hand.dissipatefn then
				inst.hand.dissipatefn()
			else
				inst.hand:Remove()
			end
			inst.hand = nil
		end
	end
end

local function OnLoad(inst, data)--, ents)
	inst.busytoggling = false
	inst.helped = data and data.helped or false
	inst.components.abysspillargroup:SetOnAddPillarFn(OnAddPillar)
	inst.components.abysspillargroup:SetOnRemovePillarFn(OnRemovePillar)

	inst.solved = true
	local helpchecked = (inst.helped or inst.hand or inst.handdelay or inst:IsAsleep()) and true or false
	inst.components.vaulttorchgrid:ForEach(function(inst, torch)
		local ison = torch.components.machine:IsOn()
		if not ison then
			inst.solved = false
			if helpchecked then
				return true --breaks out of ForEach
			end
		end
		if not helpchecked and torch:IsBroken() then
			if ison then
				inst.handdelay = inst:DoTaskInTime(3 + math.random(), OnHandDelayOver)
			end
			if not inst.solved then
				return true --breaks out of ForEach
			end
			helpchecked = true
		end
	end)
	ValidateHandHelp(inst)

	if inst.refreshpillarstask == nil then
		inst.refreshpillarstask = inst:DoTaskInTime(0, RefreshPillars)
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()

	--don't use CLASSIFIED or it won't save with the rooms
	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst._ontorchtoggled = function(torch)
		if torch:IsBroken() then
			if not inst.busytoggling then
				--V2C: was a direct toggle, not setup/loading/adjacent
				inst.helped = true
				if not torch.components.machine:IsOn() then
					inst.solved = false
					RefreshPillars(inst)
				end
			end
		elseif not (inst.busytoggling or torch:IsStuck()) then
			inst.busytoggling = true
			inst.components.vaulttorchgrid:ForEachAdjacent(torch, ToggleTorch)
			inst.busytoggling = false

			if torch.components.machine:IsOn() then
				inst.solved = true
				inst.components.vaulttorchgrid:ForEach(CheckAllTorchesSolved)
				ValidateHandHelp(inst)
			else
				inst.solved = false
			end
			RefreshPillars(inst)
		end
	end

	inst:AddComponent("vaulttorchgrid")
	inst.components.vaulttorchgrid:SetOnTorchAddedFn(OnTorchAdded)

	inst:AddComponent("abysspillargroup")
	inst.components.abysspillargroup:SetSpawnAtXZFn(DoSpawnPillarAtXZ)
	inst.components.abysspillargroup:SetCollapseFn(DoCollapsePillar)
	inst.components.abysspillargroup:SetOnAddPillarFn(OnAddPillar)
	inst.components.abysspillargroup:SetOnRemovePillarFn(OnRemovePillar)

	inst._onhandremoved = function(hand)
		assert(inst.hand == hand)
		inst.hand = nil
		if not (inst.helped or inst:IsAsleep()) then
			inst.handdelay = inst:DoTaskInTime(6 + math.random() * 2, OnHandDelayOver)
		end
	end

	inst.hand = nil
	inst.handdelay = nil
	inst.busytoggling = false
	inst.refreshpillarstask = nil
	inst.helped = false
	inst.solved = false

	inst.SetupPuzzle = SetupPuzzle
	inst.OnEntityWake = OnEntityWake
	inst.OnEntitySleep = OnEntitySleep
	inst.OnSave = OnSave
	inst.OnPreLoad = OnPreLoad
	inst.OnLoad = OnLoad

	return inst
end

return Prefab("lightsout_trial", fn, nil, prefabs)
