--------------------------------------------------------------------------
--[[ brightmarespawner class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "Brightmare spawner should not exist on client")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local POP_CHANGE_INTERVAL = 10
local POP_CHANGE_VARIANCE = 2

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _map = TheWorld.Map
local _players = {}
local _gestalts = {}
local _poptask = nil
local _checktask = nil
local _evolved_spawn_pool = 0

local _worldsettingstimer = TheWorld.components.worldsettingstimer
local ADDEVOLVED_TIMERNAME = "add_evolved_gestalt_to_pool"

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function despawn_evolved_gestalt(gestalt)
	gestalt._do_despawn = true
	_evolved_spawn_pool = _evolved_spawn_pool + 1
end

local function on_sleep_despawned(gestalt)
	_evolved_spawn_pool = _evolved_spawn_pool + 1
end

local function GetTuningLevelForPlayer(player)
	local shard_wagbossinfo = TheWorld.shard.components.shard_wagbossinfo
    local sanity = (
			(player.components.sanity:IsLunacyMode() or (shard_wagbossinfo and shard_wagbossinfo:IsWagbossDefeated()))
			and player.components.sanity:GetPercentWithPenalty()
		) or 0
	if sanity >= TUNING.GESTALT_MIN_SANITY_TO_SPAWN then
		for k, v in ipairs(TUNING.GESTALT_POPULATION_LEVEL) do
			if sanity <= v.MAX_SANITY then
				return k, v
			end
		end
	end

	return 0, nil
end

local function IsValidTrackingTarget(target)
	return (target.components.health ~= nil and not target.components.health:IsDead())
		and not target:HasTag("playerghost")
		and target.entity:IsVisible()
end

local function StopTracking(ent)
	_gestalts[ent] = nil
	if _checktask and next(_gestalts) == nil then
		_checktask:Cancel()
		_checktask = nil
	end
end

local function GetGestaltSpawnType(player, pt)
	local type = "gestalt"

	if not TheWorld.Map:IsPointInWagPunkArenaAndBarrierIsUp(pt:Get()) then
		local do_extra_spawns = (player.components.inventory ~= nil and player.components.inventory:EquipHasTag("lunarseedmaxed"))

		local shard_wagbossinfo = TheWorld.shard.components.shard_wagbossinfo
		if shard_wagbossinfo and shard_wagbossinfo:IsWagbossDefeated() then
			local num_evolved = 0
			for ent in pairs(_gestalts) do
				if ent.prefab == "gestalt_guard_evolved" then
					num_evolved = num_evolved + 1
				end
			end

			--[[
			if (num_evolved < TUNING.GESTALT_EVOLVED_MAXSPAWN or (do_extra_spawns and num_evolved < TUNING.GESTALT_EVOLVED_MAXSPAWN_INDUCED))
					and _evolved_spawn_pool > 0 then
				type = "gestalt_guard_evolved"
				_evolved_spawn_pool = _evolved_spawn_pool - 1
			end
			]]
			--Inimicals will only spawn on players with the crown (for now?)
			if (do_extra_spawns and num_evolved < TUNING.GESTALT_EVOLVED_MAXSPAWN_INDUCED) and _evolved_spawn_pool > 0 then
				type = "gestalt_guard_evolved"
				_evolved_spawn_pool = _evolved_spawn_pool - 1
			end
		end
	end

	return type
end

local SPAWN_ONEOF_TAGS = {"brightmare_gestalt", "player", "playerghost"}
local function FindGestaltSpawnPtForPlayer(player, wantstomorph)
	local x, y, z = player.Transform:GetWorldPosition()

	local function IsValidGestaltSpawnPt(offset)
		local x1, z1 = x + offset.x, z + offset.z
		return #TheSim:FindEntities(x1, 0, z1, 6, nil, nil, SPAWN_ONEOF_TAGS) == 0
	end

    local offset = FindValidPositionByFan(
		math.random() * TWOPI,
		(wantstomorph and TUNING.GESTALT_SPAWN_MORPH_DIST or TUNING.GESTALT_SPAWN_DIST) + math.random() * 2 * TUNING.GESTALT_SPAWN_DIST_VAR - TUNING.GESTALT_SPAWN_DIST_VAR,
		8,
		IsValidGestaltSpawnPt
	)
	if offset ~= nil then
		offset.x = offset.x + x
		offset.z = offset.z + z
	end

	return offset
end

local function check_for_despawns()
	local gestalts_marked_for_remove = nil

	-- First find all of the gestalts whose tracking targets died or left or whatever else.
	for gestalt in pairs(_gestalts) do
		if gestalt.prefab == "gestalt_guard_evolved" and not gestalt._do_despawn and gestalt.tracking_target == nil then
			gestalts_marked_for_remove = gestalts_marked_for_remove or {}
			table.insert(gestalts_marked_for_remove, gestalt)
		end
	end

	-- Then collect all of the gestalts that don't fit into their target's maximum anymore.
	local player_sanity, player_maximum = nil, nil
	local gestalt_count = nil
	local player_maximums = nil
	local players_under_maximum = nil
	for _, player in pairs(AllPlayers) do
		player_sanity = player.components.sanity

		player_maximums = player_maximums or {}
		player_maximum = player_maximums[player]
			or (player_sanity.inducedlunacy and TUNING.GESTALT_EVOLVED_MAXSPAWN_INDUCED)
			or (player_sanity:GetSanityMode() == SANITY_MODE_LUNACY and TUNING.GESTALT_EVOLVED_MAXSPAWN)
			or 0
		player_maximums[player] = player_maximum

		gestalt_count = 0
		for gestalt in pairs(_gestalts) do
			if gestalt.prefab == "gestalt_guard_evolved" and not gestalt._do_despawn and gestalt.tracking_target == player then
				gestalt_count = gestalt_count + 1
				if gestalt_count > player_maximum then
					gestalts_marked_for_remove = gestalts_marked_for_remove or {}
					table.insert(gestalts_marked_for_remove, gestalt)
				end
			end
		end
	end

	-- Check to see if the gestalts marked for removal have another valid option nearby to transfer to.
	-- If not, _actually_ mark them to despawn.
	if gestalts_marked_for_remove then
		local player_locations = {}
		local gx, gy, gz = nil, nil, nil
		local ppos = nil
		local did_transfer = nil
		for _, gestalt in pairs(gestalts_marked_for_remove) do
			did_transfer = false
			gx, gy, gz = gestalt.Transform:GetWorldPosition()
			-- TODO might be worth trying to find a way to randomize the AllPlayers list each time.
			-- Maybe shallowcopy + shuffleArray is ok?
			for _, player in pairs(AllPlayers) do
				if IsValidTrackingTarget(player) then
					if not player_locations[player] then
						ppos = player:GetPosition()
						player_locations[player] = ppos
					else
						ppos = player_locations[player]
					end

					local player_gestalt_dsq = distsq(ppos.x, ppos.z, gx, gz)
					if player_gestalt_dsq < 625 then
						gestalt:SetTrackingTarget(player, GetTuningLevelForPlayer(player))
						did_transfer = true
						break
					end
				end
			end

			if not did_transfer then
				despawn_evolved_gestalt(gestalt)
			end
		end
	end

	-- Finally, queue up another despawn check.
	if _checktask then
		_checktask:Cancel()
	end
	_checktask = inst:DoTaskInTime(TUNING.GESTALT_POPULATION_CHECK_TIME, check_for_despawns)
end

local function TrySpawnGestaltForPlayer(player, level, data)
	local pt = FindGestaltSpawnPtForPlayer(player, false)
	if pt ~= nil then
        local ent = SpawnPrefab(GetGestaltSpawnType(player, pt))
		_gestalts[ent] = true
		inst:ListenForEvent("onremove", StopTracking, ent)
		inst:ListenForEvent("sleep_despawn", on_sleep_despawned, ent)
        ent.Transform:SetPosition(pt.x, 0, pt.z)
		ent:SetTrackingTarget(player, GetTuningLevelForPlayer(player))
		ent:PushEvent("spawned")

		if not _checktask then
			_checktask = inst:DoTaskInTime(TUNING.GESTALT_POPULATION_CHECK_TIME, check_for_despawns)
		end
	end
end

local BRIGHTMARE_TAGS = {"brightmare"}
local function UpdatePopulation()
	local shard_wagbossinfo = TheWorld.shard.components.shard_wagbossinfo
	local increased_spawn_factor = (shard_wagbossinfo
		and shard_wagbossinfo:IsWagbossDefeated()
		and TUNING.WAGBOSS_DEFEATED_GESTALT_SPAWN_FACTOR)
		or 1

	local total_levels = 0
	for player in pairs(_players) do
		-- Try spawning a new gestalt for this player.
		if IsValidTrackingTarget(player) then
			local level, data = GetTuningLevelForPlayer(player)
			total_levels = total_levels + level

			if level > 0 then
				local x, y, z = player.Transform:GetWorldPosition()
				local gestalts = TheSim:FindEntities(x, y, z, TUNING.GESTALT_POPULATION_DIST, BRIGHTMARE_TAGS)
				local maxpop = data.MAX_SPAWNS
				local inc_chance = (#gestalts >= maxpop and 0)
								or (level == 1 and 0.2)
								or (level == 2 and 0.3)
								or 0.4

				inc_chance = inc_chance * increased_spawn_factor
				if math.random() < inc_chance then
					TrySpawnGestaltForPlayer(player, level, data)
				end
			end
		end
	end

	local min_change = math.min(total_levels, TUNING.GESTALT_POP_CHANGE_INTERVAL / 2)
	local random_change = TUNING.GESTALT_POP_CHANGE_VARIANCE * math.random()

	local next_task_time = TUNING.GESTALT_POP_CHANGE_INTERVAL - min_change + random_change
    _poptask = inst:DoTaskInTime(next_task_time, UpdatePopulation)
end

local function Start()
	_poptask = _poptask or inst:DoTaskInTime(0, UpdatePopulation)
end

local function Stop()
    if _poptask ~= nil then
        _poptask:Cancel()
        _poptask = nil
    end
end

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

function self:FindBestPlayer(gestalt)
	local closest_player = nil
	local closest_distsq = TUNING.GESTALT_POPULATION_DIST * TUNING.GESTALT_POPULATION_DIST
	local closest_level = 0

	for player in pairs(_players) do
        if IsValidTrackingTarget(player) then
			local x, y, z = player.Transform:GetWorldPosition()
            local distsq = gestalt:GetDistanceSqToPoint(x, y, z)
            if distsq < closest_distsq then
				local level, data = GetTuningLevelForPlayer(player)
				if level > 0 and #TheSim:FindEntities(x, y, z, TUNING.GESTALT_POPULATION_DIST, BRIGHTMARE_TAGS) <= (data.MAX_SPAWNS + 1) then
	                closest_distsq = distsq
		            closest_player = player
					closest_level = level
				end
            end
        end
	end

	return closest_player, closest_level
end

function self:FindRelocatePoint(gestalt)
	return gestalt.tracking_target ~= nil and FindGestaltSpawnPtForPlayer(gestalt.tracking_target, gestalt.wantstomorph) or nil
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnSanityModeChanged(player, data)
	local is_lunacy = (data ~= nil and data.mode == SANITY_MODE_LUNACY)
	if is_lunacy then
		_players[player] = true
	else
		_players[player] = nil
	end

	if next(_players) ~= nil then
		Start()
	else
		Stop()
	end
end

local function OnPlayerJoined(i, player)
    i:ListenForEvent("sanitymodechanged", OnSanityModeChanged, player)
	if player.components.sanity:IsLunacyMode() then
		OnSanityModeChanged(player, {mode = player.components.sanity:GetSanityMode()})
	end
end

local function OnPlayerLeft(i, player)
    i:RemoveEventCallback("sanitymodechanged", OnSanityModeChanged, player)
	OnSanityModeChanged(player, nil)
end

local function OnWagbossDefeated()
	_evolved_spawn_pool = math.max(1, _evolved_spawn_pool or 0)
	if not _worldsettingstimer:TimerExists(ADDEVOLVED_TIMERNAME) then
		_worldsettingstimer:StartTimer(ADDEVOLVED_TIMERNAME, TUNING.GESTALT_EVOLVED_ADDTOPOOLTIME)
	end
end

local function OnEvolvedAddedToPool(_, data)
	if _evolved_spawn_pool < TUNING.GESTALT_EVOLVED_MAXPOOL then
		_evolved_spawn_pool = _evolved_spawn_pool + 1
	end
	_worldsettingstimer:StartTimer(ADDEVOLVED_TIMERNAME, TUNING.GESTALT_EVOLVED_ADDTOPOOLTIME)
end
_worldsettingstimer:AddTimer(ADDEVOLVED_TIMERNAME, TUNING.GESTALT_EVOLVED_ADDTOPOOLTIME, TUNING.GESTALT_EVOLVED_MAXPOOL > 0, OnEvolvedAddedToPool)

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

function self:OnSave()
	local spawn_pool_size = _evolved_spawn_pool

	for gestalt in pairs(_gestalts) do
		if gestalt.prefab == "gestalt_guard_evolved" then
			spawn_pool_size = spawn_pool_size + 1
		end
	end

	return (spawn_pool_size > 0 and {
		evolved_spawn_pool = spawn_pool_size,
	}) or nil
end

function self:OnLoad(data)
	if data and data.evolved_spawn_pool then
		_evolved_spawn_pool = data.evolved_spawn_pool or 0
	end
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

--Initialize variables
for i, v in pairs(AllPlayers) do
    OnPlayerJoined(inst, v)
end

--Register events
inst:ListenForEvent("ms_playerjoined", OnPlayerJoined)
inst:ListenForEvent("ms_playerleft", OnPlayerLeft)
inst:ListenForEvent("wagboss_defeated", OnWagbossDefeated)

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
	local update_time = (_poptask and GetTaskRemaining(_poptask)) or 0
	local check_time = (_checktask and GetTaskRemaining(_checktask)) or 0
	return string.format(
		"%d Gestalts; Evolved Pool size is %d; Next update in %2.2f; Next pop check in %2.2f",
		GetTableSize(_gestalts),
		_evolved_spawn_pool,
		update_time,
		check_time
	)
end

function self:Debug_SetSpawnPoolSize(size)
	-- Don't nuke it out if we accidentally debug with nil
	_evolved_spawn_pool = size or _evolved_spawn_pool
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)