local assets =
{
	Asset("ANIM", "anim/vault_ground_pattern_large.zip"),
	Asset("ANIM", "anim/vault_ground_pattern_socket.zip"),
}

local prefabs =
{
	"vault_crawler_chandelier",
	"vault_crawler_socket",
	"vault_pillar_guard_dormant",
	"vault_key_activator_plate",
	"vault_key_pedestal_plate",
	"vault_ground_pattern_fx",
}

--------------------------------------------------------------------------

local NUM_PROGRESS_MARKERS = 4

local function _dbg_print(...)
	print("[vault_key_trial.lua]:", ...)
end

local function KillSounds(inst)
	for i = 1, 7 do
		inst.SoundEmitter:KillSound("machine"..tostring(i))
	end
end

local function RevealKey(inst)
	inst.task = nil
	local pedestal = inst.components.entitytracker:GetEntity("keypedestal")
	if pedestal and pedestal.activator == nil then
		pedestal:OpenPlate("vault_key_pedestal")
	end
end

local function CheckChasm(inst)
	local pedestal = inst.components.entitytracker:GetEntity("keypedestal")
	if pedestal and pedestal:GetOpenPrefab() == "vault_refiner_pedestal" then
		local keyexit = inst.components.entitytracker:GetEntity("exit")
		if keyexit then
			keyexit:Open()
		end
	end
end

local function CheckPuzzleProgress(inst)
	local bitfield = 0
	local puzzleprogress = 0

	local function IncrementPuzzleProgress()
		puzzleprogress = puzzleprogress + 1
		if puzzleprogress >= 8 then
			if inst.task == nil then
				if POPULATING then
					RevealKey(inst)
				else
					inst.task = inst:DoTaskInTime(1, RevealKey)
				end
			end
			local middlering = inst.components.entitytracker:GetEntity("middlering")
			if middlering then
				middlering:EnableOn(true)
			end
		end
		if not POPULATING then
			if puzzleprogress >= 8 then
				KillSounds(inst)
				inst.SoundEmitter:PlaySound("grotto/common/archive_orchestrina/8")
			else
				inst.SoundEmitter:PlaySound("grotto/common/archive_orchestrina/"..  tostring(puzzleprogress) .."_OS")
				if not inst.SoundEmitter:PlayingSound("machine"..tostring(puzzleprogress)) then
					inst.SoundEmitter:PlaySound("grotto/common/archive_orchestrina/"..  tostring(puzzleprogress) .."_LP_only", "machine"..tostring(puzzleprogress))
				end
			end
		else
			if puzzleprogress <= 7 then
				if not inst.SoundEmitter:PlayingSound("machine"..tostring(puzzleprogress)) then
					inst.SoundEmitter:PlaySound("grotto/common/archive_orchestrina/"..  tostring(puzzleprogress) .."_LP_only", "machine"..tostring(puzzleprogress))
				end
			else
				KillSounds(inst)
			end

			for i = puzzleprogress+1, 7 do -- If we lose progress somehow
				inst.SoundEmitter:KillSound("machine"..tostring(i))
			end
		end
	end

	for i = 1, 4 do
		local activator = inst.components.entitytracker:GetEntity("activator"..tostring(i))
		if activator and activator:GotSpark() then
			-- Correct the offset
			i = i - 1
			if i <= 0 then
				i = i + 4
			end
			local marker_bit = 2 ^ i
			bitfield = bit.bor(bitfield, marker_bit)
			local ring = inst.components.entitytracker:GetEntity("pillarring"..tostring(i))
			if ring then
				ring:EnableOn(true)
			end
			IncrementPuzzleProgress()
		end
	end

	for i = 1, 4 do
		local socket = inst.components.entitytracker:GetEntity("socket"..tostring(i))
		if socket and socket:IsSocketed() then
			local marker_bit1 = 2 ^ (NUM_PROGRESS_MARKERS+i)
			bitfield = bit.bor(bitfield, marker_bit1)
			IncrementPuzzleProgress()
		end
	end

	inst.puzzle_progress:set(bitfield)
end

local function CheckAllSockets(inst)
	local n = 0
	for i = 1, 4 do
		local socket = inst.components.entitytracker:GetEntity("socket"..tostring(i))
		if socket and socket:IsSocketed() then
			n = n + 1
		end
	end

	CheckPuzzleProgress(inst)

	_dbg_print(string.format("socketed %d/4", n))
end

local function OnLeverPulled(inst, activator, doer)
	for i = 1, 4 do
		if activator == inst.components.entitytracker:GetEntity("activator"..tostring(i)) then
			local light = inst.components.entitytracker:GetEntity("light"..tostring(i))
			if light and light.DropCrawler then
				light:DropCrawler()
				if doer and doer:IsValid() then
					for i = 1, 4 do
						local guard = inst.components.entitytracker:GetEntity("guard"..tostring(i))
						if guard and not guard.components.health:IsDead() then
							guard.components.combat:SuggestTarget(doer)
						end
					end
				end
				return
			end
		end
	end
end

local function CheckAllLevers(inst)
	for i = 1, 4 do
		local light = inst.components.entitytracker:GetEntity("light"..tostring(i))
		if light then
			local activator = inst.components.entitytracker:GetEntity("activator"..tostring(i))
			if activator and activator:GetOpenPrefab() ~= "vault_crawler_lever" then
				activator:OpenPlate("vault_crawler_lever")
				if not POPULATING then
					return
				end
			end
		end
	end
	inst.task:Cancel()
	inst.task = nil
end

local function TrackGuard(inst, guard)
	inst:ListenForEvent("attacked", inst._onattacked, guard)
	inst:ListenForEvent("droppedtarget", inst._onguarddroppedtarget, guard)
	inst:ListenForEvent("death", inst._onguarddied, guard)

	guard.trial = inst
	guard:AddTag("vault_key_trial_guardian")
	guard.components.damagetypebonus:AddBonus("shadowcreature", inst, TUNING.VAULT_SHADOW_SUPPRESSION_MULT, "vault_shadow_suppression")
	guard.components.damagetyperesist:AddResist("shadowcreature", inst, TUNING.VAULT_SHADOW_SUPPRESSION_MULT, "vault_shadow_suppression")
end

local function TrackCrawler(inst, crawler)
	inst:ListenForEvent("attacked", inst._onattacked, crawler)

	crawler.trial = inst
	crawler:AddTag("vault_key_trial_guardian")
	crawler.components.damagetypebonus:AddBonus("shadowcreature", inst, TUNING.VAULT_SHADOW_SUPPRESSION_MULT, "vault_shadow_suppression")
	crawler.components.damagetyperesist:AddResist("shadowcreature", inst, TUNING.VAULT_SHADOW_SUPPRESSION_MULT, "vault_shadow_suppression")
end

local function CheckAllPillars(inst)
	for i = 1, 4 do
		local pillar = inst.components.entitytracker:GetEntity("pillar"..tostring(i))
		if pillar then
			local guard = pillar:ActivatePillarGuard(inst)
			if guard then
				inst.components.entitytracker:TrackEntity("guard"..tostring(i), guard)
				TrackGuard(inst, guard)
			end
			local socket = inst.components.entitytracker:GetEntity("socket"..tostring(i))
			if socket then
				socket:TryOpenSocket()
			end
			return
		elseif POPULATING then
			local socket = inst.components.entitytracker:GetEntity("socket"..tostring(i))
			if socket then
				socket:TryOpenSocket()
			end
		end
	end
	inst.task:Cancel()
	if POPULATING then
		inst.task = inst:DoPeriodicTask(0.5, CheckAllLevers)
		CheckAllLevers(inst)
	else
		inst.task = inst:DoPeriodicTask(0.5, CheckAllLevers, 5)
	end
end

local function CheckAllActivators(inst)
	local n = 0
	for i = 1, 4 do
		local activator = inst.components.entitytracker:GetEntity("activator"..tostring(i))
		if activator then
			if activator:GotSpark() then
				n = n + 1
			elseif POPULATING then
				activator:OpenPlate("vault_key_activator")
			end
		end
	end

	CheckPuzzleProgress(inst)

	_dbg_print(string.format("sparks %d/4", n))

	if n == 4 and inst.task == nil then
		if POPULATING then
			inst.task = inst:DoPeriodicTask(1.5, CheckAllPillars)
			CheckAllPillars(inst)
		else
			inst.task = inst:DoPeriodicTask(1.5, CheckAllPillars, 3)
		end
	end
end

local function TrackLight(inst, light)
	inst:ListenForEvent("ms_vaultcrawler_dropped", inst._onvaultcrawler_dropped, light)
end

local function TrackSocket(inst, socket)
	inst:ListenForEvent("ms_vaultsocketed_changed", inst._onvaultsocketed_changed, socket)
end

local function TrackActivator(inst, activator)
	inst:ListenForEvent("ms_vaultactivator_changed", inst._onvaultactivator_changed, activator)
	inst:ListenForEvent("ms_vaultcrawlerlever_pulled", inst._onvaultcrawlerlever_pulled, activator)
end

local function TrackKeyPedestal(inst, keypedestal)
	inst:ListenForEvent("ms_vaultrefiner_revealed", inst._onvaultrefiner_revealed, keypedestal)
	keypedestal.trial = inst
end

local function TrackExit(inst, exit)
	exit.trial = inst
end

local function SpawnTrackedPrefabAtXZ(inst, id, prefab, x, z)
	local ent = SpawnPrefab(prefab)
	ent.Transform:SetPosition(x, 0, z)
	inst.components.entitytracker:TrackEntity(id, ent)
	return ent
end

local function SpawnActivatorAtXZ(inst, id, x, z)
	local activator = SpawnTrackedPrefabAtXZ(inst, id, "vault_key_activator_plate", x, z)
	activator:OpenPlate("vault_key_activator")
	return activator
end

local function InitializeLayout(inst)
	local x, _, z = inst.Transform:GetWorldPosition()

	--lights
	local r = 2 * TILE_SCALE
	--ordered to match pillar order
	TrackLight(inst, SpawnTrackedPrefabAtXZ(inst, "light1", "vault_crawler_chandelier", x, z - r))
	TrackLight(inst, SpawnTrackedPrefabAtXZ(inst, "light2", "vault_crawler_chandelier", x - r, z))
	TrackLight(inst, SpawnTrackedPrefabAtXZ(inst, "light3", "vault_crawler_chandelier", x, z + r))
	TrackLight(inst, SpawnTrackedPrefabAtXZ(inst, "light4", "vault_crawler_chandelier", x + r, z))

	--pillars & sockets (grid aligned to register pathfinding)
	local i = 0
	local sign = 1
	local groundvars = { 3, 4, 5, math.random(3, 5) }
	local groundvar2 = math.random(3, 4)
	if groundvar2 >= groundvars[4] then
		groundvar2 = groundvar2 + 1
	end
	local groundorientations = { 1, 2, 3, 4 }
	for dx = -2.125, 2.125, 4.25 do
		for dz = -2.125, 2.125, 4.25 do
			i = i + 1
			local x1 = x + dx * TILE_SCALE
			local z1 = z + dz * sign * TILE_SCALE
			SpawnTrackedPrefabAtXZ(inst, "pillarring"..tostring(i), "vault_ground_pattern_fx", x1, z1):SetVariation(table.remove(groundvars, math.random(#groundvars))):SetOrientation(table.remove(groundorientations, math.random(#groundorientations))):ChangeSortOrder(-2)
			SpawnTrackedPrefabAtXZ(inst, "pillar"..tostring(i), "vault_pillar_guard_dormant", x1, z1)
			TrackSocket(inst, SpawnTrackedPrefabAtXZ(inst, "socket"..tostring(i), "vault_crawler_socket", x1, z1))
		end
		sign = -sign
	end

	--activators
	local r = 1 * TILE_SCALE
	--ordered to match pillar order
	TrackActivator(inst, SpawnActivatorAtXZ(inst, "activator1", x, z - r))
	TrackActivator(inst, SpawnActivatorAtXZ(inst, "activator2", x - r, z))
	TrackActivator(inst, SpawnActivatorAtXZ(inst, "activator3", x, z + r))
	TrackActivator(inst, SpawnActivatorAtXZ(inst, "activator4", x + r, z))

	-- key pedestal
	SpawnTrackedPrefabAtXZ(inst, "middlering", "vault_ground_pattern_fx", x, z):SetVariation(groundvar2):SetOrientation(math.random(4)):ChangeSortOrder(-2)
	TrackKeyPedestal(inst, SpawnTrackedPrefabAtXZ(inst, "keypedestal", "vault_key_pedestal_plate", x, z))

	-- key exit
	local r = 4.75 * TILE_SCALE
	TrackExit(inst, SpawnTrackedPrefabAtXZ(inst, "exit", "vault_key_exit", x, z + r):SetCracks())
end

local function OnLoadPostPass(inst, ents, data)
	for i = 1, 4 do
		local ent = inst.components.entitytracker:GetEntity("socket"..tostring(i))
		if ent then
			TrackSocket(inst, ent)
		end

		ent = inst.components.entitytracker:GetEntity("activator"..tostring(i))
		if ent then
			TrackActivator(inst, ent)
		end

		ent = inst.components.entitytracker:GetEntity("guard"..tostring(i))
		if ent then
			TrackGuard(inst, ent)
		end

		ent = inst.components.entitytracker:GetEntity("light"..tostring(i))
		if ent then
			TrackLight(inst, ent)
		end

		ent = inst.components.entitytracker:GetEntity("crawler"..tostring(i))
		if ent then
			TrackCrawler(inst, ent)
		end
	end

	local ent = inst.components.entitytracker:GetEntity("keypedestal")
	if ent then
		TrackKeyPedestal(inst, ent)
	end

	ent = inst.components.entitytracker:GetEntity("exit")
	if ent then
		TrackExit(inst, ent)
	end

	CheckAllActivators(inst)
	CheckAllSockets(inst)
	CheckChasm(inst)
end

local function CreateMarking()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("vault_ground_pattern_socket")
	inst.AnimState:SetBuild("vault_ground_pattern_socket")
	inst.AnimState:PlayAnimation("idle1")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(-3)

	return inst
end

local function OnPuzzleProgressDirty(inst)
	local bitfield = inst.puzzle_progress:value()
	for i, v in ipairs(inst.markers) do
		v.AnimState:PlayAnimation(
			(bit.band(bitfield, 2 ^ (NUM_PROGRESS_MARKERS+i)) > 0 and "idle1_on") or
			(bit.band(bitfield, 2 ^ i) > 0 and "idle1_halfon") or
			"idle1"
		)
	end
end

local function IsPillarGuardAggro(inst)
	for i = 1, 4 do
		local guard = inst.components.entitytracker:GetEntity("guard"..tostring(i))
		if guard and guard.components.combat:HasTarget() then
			return true
		end
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("vault_ground_pattern_large")
	inst.AnimState:SetBuild("vault_ground_pattern_large")
	inst.AnimState:PlayAnimation("idle1")
	inst.AnimState:Hide("center")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(-3)
	inst.AnimState:SetFinalOffset(-1)

	inst.puzzle_progress = net_ushortint(inst.GUID, "vault_key_trial.puzzle_progress", "puzzleprogressdirty")

	--Dedicated server does not need to spawn the markers
	if not TheNet:IsDedicated() then
		inst.markers = {}
		for i = 1, NUM_PROGRESS_MARKERS do
			local marker = CreateMarking()
			marker.entity:SetParent(inst.entity)
			marker.Transform:SetRotation((i-1) * 90)
			table.insert(inst.markers, marker)
		end
		inst:ListenForEvent("puzzleprogressdirty", OnPuzzleProgressDirty)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("entitytracker")

	inst._onvaultcrawler_dropped = function(light, crawler)
		for i = 1, 4 do
			local light1 = inst.components.entitytracker:GetEntity("light"..tostring(i))
			if light == light1 then
				inst:RemoveEventCallback("ms_vaultcrawler_dropped", inst._onvaultcrawler_dropped, light)
				inst.components.entitytracker:ForgetEntity("light"..tostring(i))
				inst.components.entitytracker:TrackEntity("crawler"..tostring(i), crawler)
				TrackCrawler(inst, crawler)
				return
			end
		end
	end
	inst._onvaultsocketed_changed = function() CheckAllSockets(inst) end
	inst._onvaultactivator_changed = function() CheckAllActivators(inst) end
	inst._onvaultcrawlerlever_pulled = function(activator, doer) OnLeverPulled(inst, activator, doer) end
	inst._onvaultrefiner_revealed = function() CheckChasm(inst) end

	--used for vault_pillar_guard and vault_crawler => both to share aggro other guards
	--NOTE: crawler already handles sharing target to other crawlers
	inst._onattacked = function(ent, data)
		if data and data.attacker and data.attacker:IsValid() then
			if data.attacker:HasTag("vault_key_trial_guardian") and not data.attacker.components.combat:TargetIs(ent) then
				--ignore stray hits from pillar guard and crawler AOE
				return
			end
			for i = 1, 4 do
				local guard = inst.components.entitytracker:GetEntity("guard"..tostring(i))
				if guard and guard ~= ent and not guard.components.health:IsDead() then
					guard.components.combat:SuggestTarget(data.attacker)
				end
			end
		end
	end

	inst._onguarddroppedtarget = function(guard)
		if not guard.components.health:IsDead() then
			local x, y, z = guard.Transform:GetWorldPosition()
			local closest_target
			local mindsq = math.huge
			for i = 1, 4 do
				local guard1 = inst.components.entitytracker:GetEntity("guard"..tostring(i))
				if guard1 and guard ~= guard1 then
					local target = guard1.components.combat.target
					if target then
						local dsq = guard1:GetDistanceSqToPoint(x, y, z)
						if not target.isplayer then
							dsq = dsq * 2
						end
						if dsq < mindsq then
							mindsq = dsq
							closest_target = target
						end
					end
				end
			end
			if closest_target == nil then
				for _, v in ipairs(AllPlayers) do
					if not IsEntityDeadOrGhost(v) and v.entity:IsVisible() then
						local x1, y1, z1 = v.Transform:GetWorldPosition()
						if TheWorld.Map:IsPointInVaultRoom(x1, y1, z1) then
							local distsq = math2d.DistSq(x, z, x1, z1)
							if distsq < mindsq then
								mindsq = distsq
								closest_target = v
							end
						end
					end
				end
			end
			if closest_target then
				guard.components.combat:SetTarget(closest_target)
			end
		end
	end

	inst._onguarddied = function(guard)
		guard._vault_death_triggered = true
		for i = 1, 4 do
			if inst.components.entitytracker:GetEntity("pillar"..tostring(i)) then
				--still has pillars
				return
			end
			local guard1 = inst.components.entitytracker:GetEntity("guard"..tostring(i))
			if guard1 and guard1 ~= guard and not guard1._vault_death_triggered then
				--not last guard to die
				return
			end
		end
		--Last guard to die, additional loot
		_dbg_print(string.format("%ss defeated => adding vault loot", STRINGS.NAMES.VAULT_PILLAR_GUARD))
		guard._vault_death_loot = true
	end

	inst.InitializeLayout = InitializeLayout
	inst.IsPillarGuardAggro = IsPillarGuardAggro
	inst.OnLoadPostPass = OnLoadPostPass

	return inst
end

return Prefab("vault_key_trial", fn, assets, prefabs)
