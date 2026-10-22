--NOTE: this handles both charlie_boss and shrouden, sorry for the name!

local easing = require("easing")

local TEXTURE = "fx/debris.tex"
local SHADER = "shaders/vfx_particle_add.ksh"

local ROCKTEXTURE = "fx/debris_rock.tex"
local ROCKGLOWTEXTURE = "fx/debris_rock_glow.tex"
local ROCKSHADER = "shaders/vfx_particle.ksh"

local EMBERTEXTURE = "fx/snow.tex"
local EMBERSHADER = "shaders/vfx_particle_add.ksh"

local assets =
{
	Asset("ANIM", "anim/atrium_charlie_arena_ground.zip"),
	Asset("ANIM", "anim/atrium_charlie_arena_ground_portal.zip"),

    Asset("IMAGE", TEXTURE),
    Asset("SHADER", SHADER),
    Asset("IMAGE", ROCKTEXTURE),
    Asset("IMAGE", ROCKGLOWTEXTURE),
    Asset("SHADER", ROCKSHADER),
    Asset("IMAGE", EMBERTEXTURE),
    Asset("SHADER", EMBERSHADER),

    Asset("MINIMAP_IMAGE", "charlie_boss_trial0"),
    Asset("MINIMAP_IMAGE", "charlie_boss_trial1"),
    Asset("MINIMAP_IMAGE", "charlie_boss_trial2"),
    Asset("MINIMAP_IMAGE", "charlie_boss_trial3"),
    Asset("MINIMAP_IMAGE", "charlie_boss_trial4"),
    Asset("MINIMAP_IMAGE", "charlie_boss_trial5"),
    Asset("MINIMAP_IMAGE", "charlie_boss_trial6"),
    Asset("MINIMAP_IMAGE", "charlie_boss_trial7"),
}

local prefabs =
{
	"charlie_boss",

	"charliearena_lightray",
	"miasma_cloud_visual",
    "shadowhand_shrouded",
    "charlie_boss_runner",

    "charliearena_spike",
    "charliearena_teleporter",
}

local TILE_SCALE = TILE_SCALE
local ARENA_DIST_TO_SQUARE_EDGE = 3.5 * TILE_SCALE

--------------------------------------------------------------------------

local SHROUDED_HAND_TARGETS = {} -- Intentionally for only hands spawned by a charlie_boss_trial.

local function _dbg_print(...)
	print("[charlie_boss_trial.lua]:", ...)
end

local function UntrackCharlieBoss(inst)
    local boss = inst.components.entitytracker:GetEntity("charlie_boss")
    if boss then
        inst.components.entitytracker:ForgetEntity("charlie_boss")
	    inst:RemoveEventCallback("onremove", inst._oncharliebossremoved, boss)
	    inst:RemoveEventCallback("track_charlie_boss", inst._oncharliebosssettracking, boss)
	    inst:RemoveEventCallback("ms_charlie_boss_defeated", inst._oncharliebossdied, boss)
	    inst:RemoveEventCallback("ms_charliearena_shadowrunners_setenabled", inst._onshadowrunnersenabled, boss)
	    inst:RemoveEventCallback("ms_charliearena_shadowhands_setenabled", inst._onshadowhandsenabled, boss)
	    inst:RemoveEventCallback("ms_charliearena_becomeunstable", inst._onarenaunstable, boss)
	    inst:RemoveEventCallback("ms_charliearena_dreadstonespikes_setenabled", inst._ondreadstonespikesenabled, boss)
    end
end

local function TrackCharlieBoss(inst, boss)
    UntrackCharlieBoss(inst)

    inst.components.entitytracker:TrackEntity("charlie_boss", boss)
	inst:ListenForEvent("onremove", inst._oncharliebossremoved, boss)
	inst:ListenForEvent("track_charlie_boss", inst._oncharliebosssettracking, boss)
    inst:ListenForEvent("ms_charlie_boss_defeated", inst._oncharliebossdied, boss)
	inst:ListenForEvent("ms_charliearena_shadowrunners_setenabled", inst._onshadowrunnersenabled, boss)
	inst:ListenForEvent("ms_charliearena_shadowhands_setenabled", inst._onshadowhandsenabled, boss)
	inst:ListenForEvent("ms_charliearena_becomeunstable", inst._onarenaunstable, boss)
    inst:ListenForEvent("ms_charliearena_dreadstonespikes_setenabled", inst._ondreadstonespikesenabled, boss)
end

local function TrackDreadstoneSpike(inst, spike)
    inst.dreadstonespikesdata.totalspikescount = inst.dreadstonespikesdata.totalspikescount + 1
    inst.dreadstonespikesdata.dreadstonespikes[spike] = true
    spike:ListenForEvent("onremove", inst._onremove_dreadstonespike)
end

local function UntrackDreadstoneSpike(inst, spike)
    inst.dreadstonespikesdata.totalspikescount = inst.dreadstonespikesdata.totalspikescount - 1
    inst.dreadstonespikesdata.dreadstonespikes[spike] = nil
    spike:RemoveEventCallback("onremove", inst._onremove_dreadstonespike)
end

local function SpawnTrackedPrefabAtXZ(inst, id, prefab, x, z)
	local ent = SpawnPrefab(prefab)
	ent.Transform:SetPosition(x, 0, z)
	inst.components.entitytracker:TrackEntity(id, ent)
	return ent
end

local function SpawnPrefabAtXZ(prefab, x, z)
	local ent = SpawnPrefab(prefab)
	ent.Transform:SetPosition(x, 0, z)
	return ent
end

local INNER_MINX, INNER_MAXX, INNER_MINY, INNER_MAXY = -3 - 1, 3 + 1, -3 - 1, 3 + 1 -- 1 extra length to take into account overhang
local INNER_PHASE2_MINX, INNER_PHASE2_MAXX, INNER_PHASE2_MINY, INNER_PHASE2_MAXY = -4 - 1, 4 + 1, -4 - 1, 4 + 1 -- 1 extra length to take into account overhang

local function GetBoundingBox(inst)
    if inst._unstable:value() then
        return INNER_PHASE2_MINX, INNER_PHASE2_MAXX, INNER_PHASE2_MINY, INNER_PHASE2_MAXY
    end

    return INNER_MINX, INNER_MAXX, INNER_MINY, INNER_MAXY
end

local function GetBorderTiles(inst, otx, oty, padding)
    padding = padding or 0
    local exits = {}

    local minx, maxx, miny, maxy = GetBoundingBox(inst)

    for xx = minx - padding, maxx + padding do
        local tx, ty = otx + xx, oty + miny - padding
        table.insert(exits, { x = tx, y = ty })

        tx, ty = otx + xx, oty + maxy + padding
        table.insert(exits, { x = tx, y = ty })
    end

    for yy = miny - padding, maxy + padding do
        local tx, ty = otx + minx - padding, oty + yy
        table.insert(exits, { x = tx, y = ty })

        tx, ty = otx + maxx + padding, oty + yy
        table.insert(exits, { x = tx, y = ty })
    end

    return exits
end

local function SpawnBorder(inst)
    if inst.visuals then
        for i, v in ipairs(inst.visuals) do
            v:Remove()
        end
    end
    inst.visuals = {}

	local x, _, z = inst.Transform:GetWorldPosition()
	local otx, oty = TheWorld.Map:GetTileCoordsAtPoint(x, 0, z)
	local exits = GetBorderTiles(inst, otx, oty)
    for i, v in ipairs(exits) do
		local tx, ty, tz = TheWorld.Map:GetTileCenterPoint(v.x, v.y)
        local cloud = SpawnPrefab("miasma_cloud_arenabordervisual")
		cloud.entity:SetParent(inst.entity)
		cloud.Transform:SetPosition(x - tx, 0, z - tz)
        table.insert(inst.visuals, cloud)
    end
end

local function SpawnExitCrack(inst)
	local x, _, z = inst.Transform:GetWorldPosition()
    SpawnTrackedPrefabAtXZ(inst, "exit", "charliearena_teleporter", x, z):Open()
end

local function InitializeLayout(inst)
	local x, _, z = inst.Transform:GetWorldPosition()

	local charlie = SpawnPrefabAtXZ("charlie_boss", x, z)
	charlie.sg:GoToState("spawn")
	TrackCharlieBoss(inst, charlie)

	--light rays
	local rotationvars = { 1, 2, 3, 4, 5, 6, 7, 8, math.random(8) }

	local halftile = 0.5 * TILE_SCALE
	local base_r = 2 * TILE_SCALE
	local lx, lz = x + GetRandomWithVariance(base_r, halftile), z + math.random() * halftile
	SpawnTrackedPrefabAtXZ(inst, "light1", "charliearena_lightray", lx, lz).Transform:SetRotation(table.remove(rotationvars, math.random(#rotationvars)) * 45)
	SpawnPrefabAtXZ("miasma_cloud_visual", lx, lz)
	lx, lz = x - GetRandomWithVariance(base_r, halftile), z + math.random() * halftile
	SpawnTrackedPrefabAtXZ(inst, "light2", "charliearena_lightray", lx, lz).Transform:SetRotation(table.remove(rotationvars, math.random(#rotationvars)) * 45)
	SpawnPrefabAtXZ("miasma_cloud_visual", lx, lz)
	lx, lz = x + math.random() * halftile, z + GetRandomWithVariance(base_r, halftile)
	SpawnTrackedPrefabAtXZ(inst, "light1", "charliearena_lightray", lx, lz).Transform:SetRotation(table.remove(rotationvars, math.random(#rotationvars)) * 45)
	SpawnPrefabAtXZ("miasma_cloud_visual", lx, lz)
	lx, lz = x + math.random() * halftile, z - GetRandomWithVariance(base_r, halftile)
	SpawnTrackedPrefabAtXZ(inst, "light1", "charliearena_lightray", lx, lz).Transform:SetRotation(table.remove(rotationvars, math.random(#rotationvars)) * 45)
	SpawnPrefabAtXZ("miasma_cloud_visual", lx, lz)

	SpawnBorder(inst)
end

local function OnSave(inst, data)
    data.unstable = inst._unstable:value()

    local refs = {}

    data.dreadstonespikes = {}
    for spike in pairs(inst.dreadstonespikesdata.dreadstonespikes) do
        table.insert(data.dreadstonespikes, spike.GUID)
        table.insert(refs, spike.GUID)
    end

    return refs
end

local function OnLoadPostPass(inst, newents, data)
    local ent = inst.components.entitytracker:GetEntity("charlie_boss")
	if ent then
		TrackCharlieBoss(inst, ent)
	end

    if data then
        if data.dreadstonespikes and ent then
            for _, spikeuid in ipairs(data.dreadstonespikes) do
                local spike = newents[spikeuid] and newents[spikeuid].entity
                if spike then
                    spike:SetShrouden(ent)
                    TrackDreadstoneSpike(inst, spike)
                end
            end
        end

        if data.unstable then
            inst:SetUnstable(true)
        end
    end

	SpawnBorder(inst)
end

local function DissipateAllShadowHands(inst)
    for hand, _ in pairs(inst.shadowhandsdata.hands) do
        hand:Dissipate()
    end
end

local function TryToFindSpawnPointForHand(inst, target)
    -- NOTES(JBK): For this we will find a point along the square permiter closest to the target and then add a jiggle offset so the hand approaches not always tangentially.
    -- This adds some predictability to the engagement but also makes all hands immediate threats to light sources since they travel as minimal as possible.
    local cx, cy, cz = inst.Transform:GetWorldPosition()
    local tx, ty, tz = target.Transform:GetWorldPosition()
    local dx, dz = tx - cx, tz - cz

    local minx = cx - ARENA_DIST_TO_SQUARE_EDGE
    local maxx = cx + ARENA_DIST_TO_SQUARE_EDGE
    local minz = cz - ARENA_DIST_TO_SQUARE_EDGE
    local maxz = cz + ARENA_DIST_TO_SQUARE_EDGE

    local x, z = tx, tz
    if -ARENA_DIST_TO_SQUARE_EDGE < dx and dx < ARENA_DIST_TO_SQUARE_EDGE and -ARENA_DIST_TO_SQUARE_EDGE < dz and dz < ARENA_DIST_TO_SQUARE_EDGE then
        -- Target is inside the square must find the closest edge.
        local distleft = dx + ARENA_DIST_TO_SQUARE_EDGE
        local distright = ARENA_DIST_TO_SQUARE_EDGE - dx
        local distdown = dz + ARENA_DIST_TO_SQUARE_EDGE
        local distup = ARENA_DIST_TO_SQUARE_EDGE - dz

        local mindist = math.min(distleft, distright, distdown, distup)

        if mindist == distleft then
            x = minx
            z = GetRandomWithVariance(z, TILE_SCALE)
        elseif mindist == distright then
            x = maxx
            z = GetRandomWithVariance(z, TILE_SCALE)
        elseif mindist == distdown then
            x = GetRandomWithVariance(x, TILE_SCALE)
            z = minz
        else--if mindist == distup then
            x = GetRandomWithVariance(x, TILE_SCALE)
            z = maxz
        end
    end

    -- Always clamp to force being on an edge.
    x = math.clamp(x, minx, maxx)
    z = math.clamp(z, minz, maxz)

    return x, 0, z
end

local HANDTARGET_ONEOF_TAGS = { "fire", "light", "staffstar", "torch" }
local HANDTARGET_CANT_TAGS = { "INLIMBO", "shadow_fire" }

local FUEL_TAGS = nil -- Cached once.
local function TryToFindHandTargetForPlayer(inst, player)
    if not FUEL_TAGS then
        FUEL_TAGS = {}
        for _, v in pairs(FUELTYPE) do
            if v ~= FUELTYPE.USAGE then --Not a real fuel
                table.insert(FUEL_TAGS, v.."_fueled")
            end
        end
    end

    local x, y, z = player.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.SHADOWHAND_SHROUDED_FINDLIGHT_RADIUS, nil, HANDTARGET_CANT_TAGS, HANDTARGET_ONEOF_TAGS)
    for _, ent in ipairs(ents) do
        if not SHROUDED_HAND_TARGETS[ent] then
            if ent:HasTag("torch") then -- Torches have fire tag must be before.
                if ent.components.fueled and ent.components.burnable and ent.components.burnable:IsBurning() then
                    return ent
                end
            elseif ent:HasTag("fire") then
                if ent:HasAnyTag(FUEL_TAGS) then
                    return ent
                end
            elseif ent:HasTag("light") then
                if ent:HasTag("turnedon") then
                    return ent
                end
            else--if ent:HasTag("staffstar") then
                return ent
            end
        end
    end

    return nil
end

local function TryToMakeHandForPlayer(inst, player)
    local totalhandscount = inst.shadowhandsdata.totalhandscount
    if totalhandscount >= TUNING.SHADOWHAND_SHROUDED_MAX_OUTATONCE then
        return false
    end

    local target = inst:TryToFindHandTargetForPlayer(player)
    if not target then
        return false
    end

    local x, y, z = inst:TryToFindSpawnPointForHand(target)
    if not x then
        return false
    end

    local hand = SpawnPrefab("shadowhand_shrouded")
    inst.shadowhandsdata.totalhandscount = totalhandscount + 1
    inst.shadowhandsdata.hands[hand] = target
    SHROUDED_HAND_TARGETS[target] = true
    hand:ListenForEvent("onremove", inst._onremove_shadowhand)
    hand.Transform:SetPosition(x, y, z)
    local actionoverride = target.components.machine and ACTIONS.TURNOFF or nil
    hand:SetTargetFire(target, actionoverride)
end

local function OnShadowHandsTick(inst)
    if inst.shadowhandsdata.totalhandscount < TUNING.SHADOWHAND_SHROUDED_MAX_OUTATONCE then
        local players, numberplayers = GetPlayersInfoForVirtualRoomSetName(VIRTUALROOMSETS.ATRIUM)
        if players then
            for player, _ in pairs(players) do
                if not inst:TryToMakeHandForPlayer(player) then
                    if inst.shadowhandsdata.totalhandscount >= TUNING.SHADOWHAND_SHROUDED_MAX_OUTATONCE then
                        break
                    end
                end
            end
        end
    end
end

local function OnShadowHandsEnabled(inst, enabled)
    if enabled then
        if not inst.shadowhandsdata.task then
            inst.shadowhandsdata.task = inst:DoPeriodicTask(1, OnShadowHandsTick)
        end
    else
        if inst.shadowhandsdata.task then
            inst.shadowhandsdata.task:Cancel()
            inst.shadowhandsdata.task = nil
        end
        inst:DissipateAllShadowHands()
    end
end

local function TryToFindSpawnPointForRunner(inst)
    local cx, cy, cz = inst.Transform:GetWorldPosition()

    local minx = cx - ARENA_DIST_TO_SQUARE_EDGE
    local maxx = cx + ARENA_DIST_TO_SQUARE_EDGE
    local minz = cz - ARENA_DIST_TO_SQUARE_EDGE
    local maxz = cz + ARENA_DIST_TO_SQUARE_EDGE

    local x, z
    local r = math.random(4)
    if r == 1 then
        x = minx
        z = GetRandomWithVariance(cz, ARENA_DIST_TO_SQUARE_EDGE)
    elseif r == 2 then
        x = maxx
        z = GetRandomWithVariance(cz, ARENA_DIST_TO_SQUARE_EDGE)
    elseif r == 3 then
        x = GetRandomWithVariance(cx, ARENA_DIST_TO_SQUARE_EDGE)
        z = minz
    elseif r == 4 then
        x = GetRandomWithVariance(cx, ARENA_DIST_TO_SQUARE_EDGE)
        z = maxz
    end

    return x, 0, z
end

local function OnShadowRunnersTick(inst)
    local totalrunnerscount = inst.shadowrunnersdata.totalrunnerscount
    if totalrunnerscount >= TUNING.CHARLIE_BOSS_RUNNER_MAXCOUNT then
        return
    end

    local num_runners = TUNING.CHARLIE_BOSS_RUNNER_BASE_AMOUNT
    local num_players = 0
    for _, v in ipairs(AllPlayers) do
        if not IsEntityDeadOrGhost(v) and v.entity:IsVisible() then
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			if TheWorld.Map:IsPointInCharlieBossArena(x1, y1, z1) then
                num_players = num_players + 1
            end
        end
    end
    num_runners = num_runners + RoundBiasedDown(num_players*TUNING.CHARLIE_BOSS_RUNNER_AMOUNT_PER_PLAYER)

    local charlieboss = inst.components.entitytracker:GetEntity("charlie_boss")
    for i = 1, num_runners do
        totalrunnerscount = inst.shadowrunnersdata.totalrunnerscount
        if totalrunnerscount >= TUNING.CHARLIE_BOSS_RUNNER_MAXCOUNT then
            return
        end

        local x, y, z = TryToFindSpawnPointForRunner(inst)
        local angle = ReduceAngle(inst:GetAngleToPoint(x, y, z) - 180)

        local runner = SpawnPrefab("charlie_boss_runner")
        runner.Transform:SetPosition(x, y, z)
        runner.Transform:SetRotation(angle)
        runner.caster = charlieboss
		runner.components.spawnfader:FadeIn()
		if not runner.components.locomotor:WantsToMoveForward() then
			local theta = angle * DEGREES
			runner.components.locomotor:GoToPoint(Vector3(x + 3 * math.cos(theta), 0, z - 3 * math.sin(theta)), nil, false)
		end

		runner:ListenForEvent("resetboss", function() runner:Remove() end, charlieboss)

        inst.shadowrunnersdata.totalrunnerscount = totalrunnerscount + 1
        inst.shadowrunnersdata.runners[runner] = true
        runner:ListenForEvent("onremove", inst._onremove_shadowrunner)
    end
end

local function DissipateAllShadowRunners(inst)
    for runner, _ in pairs(inst.shadowrunnersdata.runners) do
        runner:DoTaskInTime(0.5 * math.random(), function()
            runner.components.lootdropper:SetLoot({})
            runner.components.lootdropper:SetChanceLootTable(nil)
            runner.components.health:Kill()
        end)
    end
end

local function OnShadowRunnersEnabled(inst, enabled)
    if enabled then
        if not inst.shadowrunnersdata.task then
            inst.SoundEmitter:PlaySound("rifts8/shadow_insanity_player/horde_warning_LP", "horde_lp")
            inst.shadowrunnersdata.task = inst:DoPeriodicTask(4, OnShadowRunnersTick, 0.3 + math.random() * 0.2)
        end
    else
        if inst.shadowrunnersdata.task then
            inst.SoundEmitter:KillSound("horde_lp")
            inst.shadowrunnersdata.task:Cancel()
            inst.shadowrunnersdata.task = nil
        end
        DissipateAllShadowRunners(inst)
    end
end

local SPIKE_EXCLUDE_RADIUS_SQ = 6.5*6.5 -- can't spawn too close to the center, because the center is a portal
local BOSS_PADDING_RADIUS = 2 * 2

local SPIKE_CANT_TAGS, SPIKE_ONEOF_TAGS
local function CanSpawnDreadstoneSpikeAt(inst, pos, boss)
    if SPIKE_CANT_TAGS == nil then
        SPIKE_CANT_TAGS = { }
        SPIKE_ONEOF_TAGS = { "groundspike", "antlion_sinkhole_blocker", "shadowboss", "shadowthrall" }
    end
    if inst:GetDistanceSqToPoint(pos) <= SPIKE_EXCLUDE_RADIUS_SQ then
        return false
    end
    if boss:GetDistanceSqToPoint(pos) <= boss:GetPhysicsRadius(0) + BOSS_PADDING_RADIUS then
        return false
    end
    local radius = 1
    for i, v in ipairs(TheSim:FindEntities(pos.x, 0, pos.z, radius + MAX_PHYSICS_RADIUS, nil, SPIKE_CANT_TAGS, SPIKE_ONEOF_TAGS)) do
        if v.Physics == nil then
            return false
        end
        local spacing = radius + v:GetPhysicsRadius(0)
        if v:GetDistanceSqToPoint(pos) < spacing * spacing then
            return false
        end
    end
    return true
end

local function SpawnDreadstoneSpikes_Random(inst, boss, pos)
    local function WalkableOffsetCheckFn(pt)
        return CanSpawnDreadstoneSpikeAt(inst, pt, boss)
    end
    if TheWorld.Map:IsAboveGroundAtPoint(pos:Get()) and CanSpawnDreadstoneSpikeAt(inst, pos, boss) then
        local spike = SpawnPrefab("charliearena_spike")
        spike.Transform:SetPosition(pos:Get())
        spike:OnShroudenSummon(boss)
        TrackDreadstoneSpike(inst, spike)
    end

    for i = 1, math.random(5, 6) do
        local offset = FindWalkableOffset(pos, math.random() * TWOPI, 2 + math.random() * 2, 3, false, true, WalkableOffsetCheckFn, false, false)
        if offset ~= nil then
            local spike = SpawnPrefab("charliearena_spike")
            spike.Transform:SetPosition(pos.x + offset.x, 0, pos.z + offset.z)
            spike:OnShroudenSummon(boss)
            TrackDreadstoneSpike(inst, spike)
        end
    end
end

local function SpawnDreadstoneSpikes_Trap(inst, boss, pos)
    local function WalkableOffsetCheckFn(pt)
        return CanSpawnDreadstoneSpikeAt(inst, pt, boss)
    end
    local c = math.random(5, 6)
    for i = 1, c do
        local theta = TWOPI * (i/c)
        local offset = FindWalkableOffset(pos, theta, 2.1, 3, false, true, WalkableOffsetCheckFn, false, false)
        if offset ~= nil then
            local spike = SpawnPrefab("charliearena_spike")
            spike.Transform:SetPosition(pos.x + offset.x, 0, pos.z + offset.z)
            spike:OnShroudenSummon(boss)
            TrackDreadstoneSpike(inst, spike)
        end
    end
end

local function SpawnDreadstoneSpikes(inst, boss, pos, mode)
	if mode == "trap" then
        SpawnDreadstoneSpikes_Trap(inst, boss, pos)
    elseif true then
        SpawnDreadstoneSpikes_Random(inst, boss, pos)
    end
end

local function OnDreadstoneSpikesTick(inst, targetcds)
    local boss = inst.components.entitytracker:GetEntity("charlie_boss")
	if not (boss and boss.components.grouptargeter) or (boss.sg and boss.sg:HasStateTag("spawning")) then
        return
    end

	local num = boss.components.grouptargeter:GetNumTargets()
	if num <= 0 then
		return
	end

	local t = GetTime()
	--local cdscale = math.clamp(Remap(num, 1, 6, 1, 3), 1, 3)
	local force0cd = math.random(num)

	for player in pairs(boss.components.grouptargeter:GetTargets()) do
		local cd = TUNING.CHARLIEARENA_SPIKE_SANITY_CD[2]
		local mode = "random"
		if player.components.sanity then
			if player.components.sanity:IsLunacyMode() then
				local lowcd, highcd = unpack(TUNING.CHARLIEARENA_SPIKE_LUNACY_CD)
				local lowpct, highpct = 0.2, TUNING.SANITY_BECOME_ENLIGHTENED_THRESH
				local pct = math.clamp(player.components.sanity:GetPercentWithPenalty(), lowpct, highpct)
				local cd1 = easing.inQuad(pct - lowpct, lowcd, highcd - lowcd, highpct - lowpct)
				local cd2 = Remap(pct, lowpct, highpct, lowcd, highcd)
				cd = (cd1 + cd2) * 0.5
				mode = "trap"
			else
				local lowcd, highcd = unpack(TUNING.CHARLIEARENA_SPIKE_SANITY_CD)
				local lowpct, highpct = TUNING.SANITY_BECOME_INSANE_THRESH, 0.8
				local pct = math.clamp(player.components.sanity:GetPercentWithPenalty(), lowpct, highpct)
				local cd1 = easing.outQuad(pct - lowpct, lowcd, highcd - lowcd, highpct - lowpct)
				local cd2 = Remap(pct, lowpct, highpct, lowcd, highcd)
				cd = (cd1 + cd2) * 0.5
			end
		end
		--cd = cd * cdscale
		if player.components.health and player.components.health:IsInvincible() then
			local x, _, z = player.Transform:GetWorldPosition()
			if TheWorld.Map:IsPointInCharlieBossArena(x, 0, z) then
				--reset cd to max when reviving
				targetcds[player] = t
			end
		else
			local lastspiket = targetcds[player]
			if lastspiket == nil then
				force0cd = force0cd - 1
				lastspiket = force0cd == 0 and -math.huge or t - cd * math.max(0, GetRandomMinMax(-0.25, 1))
			end
			if lastspiket + cd < t then
				local x, _, z = player.Transform:GetWorldPosition()
				if TheWorld.Map:IsPointInCharlieBossArena(x, 0, z) and not IsEntityDeadOrGhost(player) then
					local vx, _, vz = player.Physics:GetVelocity()
					local pos = Vector3(x + vx * 0.5, 0, z + vz * 0.5)
					SpawnDreadstoneSpikes(inst, boss, pos, mode)
					targetcds[player] = t
				end
			end
		end
    end
end

local function DestroyAllDreadstoneSpikes(inst)
    for spike, _ in pairs(inst.dreadstonespikesdata.dreadstonespikes) do
        spike.persists = false
        UntrackDreadstoneSpike(inst, spike)
        spike:DestroyInTime(math.random())
    end
end

local function OnDreadstoneSpikesEnabled(inst, enabled)
    if enabled then
        if not inst.dreadstonespikesdata.task then
			inst.dreadstonespikesdata.task = inst:DoPeriodicTask(1, OnDreadstoneSpikesTick, nil, {})
        end
    else
        if inst.dreadstonespikesdata.task then
            inst.dreadstonespikesdata.task:Cancel()
            inst.dreadstonespikesdata.task = nil
        end
        DestroyAllDreadstoneSpikes(inst)
    end
end

----------------------------------------------------

local function AddPortalLayer(inst, layer, height)
	local fx = CreateEntity()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(TheWorld.ismastersim)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx.AnimState:SetBuild("atrium_charlie_arena_ground_portal")
	fx.AnimState:SetBank("atrium_charlie_arena_ground_portal")
	fx.AnimState:PlayAnimation("idle", true)
	fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	fx.AnimState:SetLayer(LAYER_BACKGROUND)
	fx.AnimState:Hide("edge")
	fx.AnimState:Hide(layer == "deep" and "mid" or "deep")
	fx.AnimState:SetSortOrder(-2)

	fx.entity:SetParent(inst.entity)
	fx.Transform:SetPosition(0, height, 0)

	return fx
end

local function CreatePortal()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("atrium_charlie_arena_ground_portal")
	inst.AnimState:SetBuild("atrium_charlie_arena_ground_portal")
	inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:Hide("mid")
    inst.AnimState:Hide("deep")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(-1)

	inst.animlayers =
	{
		AddPortalLayer(inst, "mid", -0.25),
		AddPortalLayer(inst, "deep", -0.5),
	}

	return inst
end

----------------------------------------------------------

local ARENA_SIZE = 20
local TERRAFORM_BLOCKER_RADIUS = math.ceil(ARENA_SIZE / 3)

local function CreateTerraformBlocker(parent)
    local inst = CreateEntity()

    inst:AddTag("FX")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()

    inst:SetTerraformExtraSpacing(TERRAFORM_BLOCKER_RADIUS + 0.01)

    return inst
end

local function AddTerraformBlockers(inst) -- NOTES(JBK): Keep in sync with atrium_gate. [ARTBES]
    local diameter = 2 * TERRAFORM_BLOCKER_RADIUS
    local rowoffset = 3 * TERRAFORM_BLOCKER_RADIUS
    for row = -rowoffset, rowoffset, diameter do
        for col = -diameter, diameter, diameter do
            local blocker = CreateTerraformBlocker(inst)
            blocker.entity:SetParent(inst.entity)
            blocker.Transform:SetPosition(row, 0, col)

            blocker = CreateTerraformBlocker(inst)
            blocker.entity:SetParent(inst.entity)
            blocker.Transform:SetPosition(col, 0, row)
        end
    end
end

----------------------------------------------------------

local function IntColour(r, g, b, a)
    return { r / 255, g / 255, b / 255, a / 255 }
end

local COLOUR_ENVELOPE_NAME = "charliearenadebriscolourenvelope"
local SCALE_ENVELOPE_NAME = "charliearenadebrisscaleenvelope"

local ROCK_COLOUR_ENVELOPE_NAME = "charliearenarockcolourenvelope"
local ROCK_SCALE_ENVELOPE_NAME = "charliearenarockscaleenvelope"

local EMBER_COLOUR_ENVELOPE_NAME = "charliearenaembercolourenvelope"
local EMBER_SCALE_ENVELOPE_NAME = "charliearenaemberscaleenvelope"

local function InitEnvelope()
    EnvelopeManager:AddColourEnvelope(
        COLOUR_ENVELOPE_NAME,
        {
            { 0,        IntColour(255, 220, 234, 0) },
            { .2,       IntColour(255, 220, 234, 190) },
            { .75,      IntColour(255, 220, 234, 168) },
            { 1,        IntColour(255, 220, 234, 0) },
        }
    )

    local min_scale = .43
    local max_scale = .50
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME,
        {
            { 0,    { min_scale, min_scale } },
            { .5,   { max_scale, max_scale } },
            { 1,    { min_scale, min_scale } },
        }
    )

    EnvelopeManager:AddColourEnvelope(
        ROCK_COLOUR_ENVELOPE_NAME,
        {
            { 0,        IntColour(255, 255, 255, 255) },
            { 1,        IntColour(255, 255, 255, 255) },
        }
    )

    EnvelopeManager:AddVector2Envelope(
        ROCK_SCALE_ENVELOPE_NAME,
        {
            { 0,    { 1, 1 } },
            { 1,    { 1, 1 } },
        }
    )

    EnvelopeManager:AddColourEnvelope(
        EMBER_COLOUR_ENVELOPE_NAME,
        {
            { 0,    IntColour(225, 60, 40, 25) },
            { .2,   IntColour(235, 90, 80, 200) },
            { .3,   IntColour(255, 65, 40, 255) },
            { .6,   IntColour(255, 65, 40, 255) },
            { .9,   IntColour(255, 65, 40, 230) },
            { 1,    IntColour(255, 30, 40, 0) },
        }
    )

    local ember_max_scale = 0.7
    EnvelopeManager:AddVector2Envelope(
        EMBER_SCALE_ENVELOPE_NAME,
        {
            {   0, { ember_max_scale, ember_max_scale } },
            { 0.5, { ember_max_scale * 0.8, ember_max_scale * 0.8 } },
            {   1, { ember_max_scale * 0.1, ember_max_scale * 0.1 } },
        }
    )

    InitEnvelope = nil
    IntColour = nil
end

local function InitParticles(inst)
	if InitEnvelope ~= nil then
        InitEnvelope()
    end

    local ROCK_MAX_LIFETIME = 60*60*24

	local MAX_LIFETIME = 40
	local MIN_LIFETIME = 25

    local EMBER_MAX_LIFETIME = 4

    local effect = inst.entity:AddVFXEffect()
    effect:InitEmitters(3)

    effect:SetRenderResources(0, TEXTURE, SHADER)
    effect:SetMaxNumParticles(0, 300)
    effect:SetMaxLifetime(0, MAX_LIFETIME)
    effect:SetColourEnvelope(0, COLOUR_ENVELOPE_NAME)
    effect:SetScaleEnvelope(0, SCALE_ENVELOPE_NAME)
    effect:SetBlendMode(0, BLENDMODE.Additive)
    effect:SetSortOrder(0, 0)
    -- effect:SetLayer(0, LAYER_BELOW_GROUND)
    effect:SetAcceleration(0, 0, .0001, 0)
    effect:SetDragCoefficient(0, .0001)
    effect:EnableDepthTest(0, false)
    effect:SetKillOnEntityDeath(0, true)
    effect:SetUVFrameSize(0, .25, 1)
    effect:SetRotationStatus(0, true)

    -- rock
    effect:SetRenderResources(1, ROCKTEXTURE, ROCKSHADER)
    effect:SetMaxNumParticles(1, 25)
    effect:SetMaxLifetime(1, ROCK_MAX_LIFETIME)
    effect:SetColourEnvelope(1, ROCK_COLOUR_ENVELOPE_NAME)
    effect:SetScaleEnvelope(1, ROCK_SCALE_ENVELOPE_NAME)
    effect:SetSortOrder(1, 1)
    effect:SetAcceleration(1, 0, .0001, 0)
    effect:SetDragCoefficient(1, .0001)
    effect:SetKillOnEntityDeath(1, true)
    effect:SetUVFrameSize(1, .25, 0.5)
    effect:SetRotationStatus(1, true)

    -- EMBER
    effect:SetRenderResources(2, EMBERTEXTURE, EMBERSHADER)
    effect:SetMaxNumParticles(2, 512)
    effect:SetMaxLifetime(2, EMBER_MAX_LIFETIME)
    effect:SetColourEnvelope(2, EMBER_COLOUR_ENVELOPE_NAME)
    effect:SetScaleEnvelope(2, EMBER_SCALE_ENVELOPE_NAME)
    effect:SetBlendMode(2, BLENDMODE.Additive)
    effect:EnableBloomPass(2, true)
	effect:SetSortOrder(2, 0)
    effect:SetSortOffset(2, 0)
    effect:SetAcceleration(2, 0, 0.035, 0)
    effect:SetDragCoefficient(2, 0.08)
    effect:SetKillOnEntityDeath(2, true)

    local tick_time = TheSim:GetTickTime()
    inst.SetEffectUnstable = function(inst, unstable)
        effect:SetRenderResources(1, unstable and ROCKGLOWTEXTURE or ROCKTEXTURE, ROCKSHADER)
        inst.embers_per_tick = unstable and 20 * tick_time or 0
    end

    inst.particles_per_tick = 20 * tick_time
    inst.num_particles_to_emit = inst.particles_per_tick * 2 -- x2 on first tick to populate quickly
    inst.num_rocks_to_emit = 25
    inst.num_embers_to_emit = 0
    inst.embers_per_tick = 0

    local halfheight = 2
    local emitter_shape = CreateBoxEmitter(0, 0, 0, 35, halfheight, 35)
    local emitter_rock_shape = CreateBoxEmitter(0, 0, 0, 35, 4, 35)
    local emitter_ember_shape = CreateBoxEmitter(0, 0, 0, 20, 0, 20)

    -- for discarding
    local minx, maxx, minz, maxz = -3 * TILE_SCALE, 3 * TILE_SCALE, -3 * TILE_SCALE, 3 * TILE_SCALE

    local function emit_fn()
        local px, py, pz = emitter_shape()
        py = py + halfheight -- otherwise the particles appear under the ground

        local vx = .0015 * (math.random() - .5)
        local vy = .0005
        local vz = .0015 * (math.random() - .5)

        local lifetime = MIN_LIFETIME + (MAX_LIFETIME - MIN_LIFETIME) * UnitRand()

        local uv_offset = math.random(0, 3) * .25
        effect:AddRotatingParticleUV(
            0,
            lifetime,           -- lifetime
            px, py, pz,         -- position
            vx, vy, vz,         -- velocity
            math.random() * 360, UnitRand(),
            uv_offset, 0        -- uv offset
        )
    end

    local function emit_rock_fn()
        local px, py, pz = emitter_rock_shape()
        py = py + 4

        if px <= minx or px >= maxx or pz <= minz or pz >= maxz then
            local vx = .0010 * (math.random() - .5)
            local vy = .0
            local vz = .0010 * (math.random() - .5)

            local u_offset = math.random(0, 3) * .25
            local v_offset = math.random(0, 1) * .5
            effect:AddRotatingParticleUV(
                1,
                ROCK_MAX_LIFETIME,           -- lifetime
                px, py, pz,         -- position
                vx, vy, vz,         -- velocity
                math.random() * 360, UnitRand() * 0.3,
                u_offset, v_offset  -- uv offset
            )
        end
    end

    local function emit_ember_fn()
        local ox, oy, oz = emitter_ember_shape()
        local ovx, ovy, ovz = .06 * UnitRand(), 0.15 + 0.15 * math.random(), .06 * UnitRand()

        effect:AddParticle(
            2,
            EMBER_MAX_LIFETIME * (math.random() * 0.4 + 0.6), -- lifetime
            ox, -0.5, oz,   -- position
            ovx, ovy, ovz -- velocity
        )
    end

    inst.time = 0
    inst.interval = 0
    EmitterManager:AddEmitter(inst, nil, function()
        if not (ThePlayer and TheWorld.Map:IsPointInCharlieBossArena(ThePlayer.Transform:GetWorldPosition())) then
            return
        end
        while inst.num_particles_to_emit > 1 do
            emit_fn()
            inst.num_particles_to_emit = inst.num_particles_to_emit - 1
        end
        inst.num_particles_to_emit = inst.num_particles_to_emit + inst.particles_per_tick
        while inst.num_rocks_to_emit > 1 do
            emit_rock_fn()
            inst.num_rocks_to_emit = inst.num_rocks_to_emit - 1
        end
        inst.num_rocks_to_emit = inst.num_rocks_to_emit + inst.particles_per_tick
        while inst.num_embers_to_emit > 1 do
            emit_ember_fn()
            inst.num_embers_to_emit = inst.num_embers_to_emit - 1
        end
        inst.num_embers_to_emit = inst.num_embers_to_emit + inst.embers_per_tick

        inst.time = inst.time + tick_time
        inst.interval = inst.interval + 1
        if inst.interval >= 10 then
            inst.interval = 0
            local debris_val = .001 * math.sin(inst.time * .8)
            local rock_val = .002 * math.sin(inst.time)
            effect:SetAcceleration(0, 0, debris_val, 0)
            effect:SetAcceleration(1, 0, rock_val, 0)
        end
    end)
end

--------------------------------------------------------

local function OnUnstableDirty(inst)
    local unstable = inst._unstable:value()
    inst:SetEffectUnstable(unstable)
end

local function OnServerUnstable(inst, enabled)
	SpawnBorder(inst)
    if enabled then
        TheWorld:PushEvent("ms_charliearena_expand")
    end
end

local function SetUnstable(inst, enabled)
    if enabled ~= inst._unstable:value() then
        inst._unstable:set(enabled)
        if not TheNet:IsDedicated() then
            OnUnstableDirty(inst)
        end

        OnServerUnstable(inst, enabled)
    end
end

--------------------------------------------------------

local function do_marker_minimap_swap(inst)
    inst.marker_index = inst.marker_index == nil and 1 or ((inst.marker_index + 1) % 8)
    inst.icon.MiniMapEntity:SetIcon("charlie_boss_trial"..inst.marker_index..".png")
end

local function CreateGlobalIcon(inst)
    inst.icon = SpawnPrefab("globalmapicon")
    inst.icon:TrackEntity(inst)
    inst.icon.MiniMapEntity:SetIcon("charlie_boss_trial0.png")
    inst.icon.MiniMapEntity:SetPriority(21)
    inst.icon.MiniMapEntity:SetAlwaysOutsideVRS(true)

    inst:DoPeriodicTask(TUNING.STORM_SWAP_TIME, do_marker_minimap_swap)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("atrium_charlie_arena_ground")
	inst.AnimState:SetBuild("atrium_charlie_arena_ground")
	inst.AnimState:PlayAnimation("idle_active_on")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(0)

	inst:AddComponent("charliearenawatcher")
	inst:AddComponent("temperatureoverrider") -- configured server-side

	--Dedicated server does not need to spawn the markers or local particle fx
	if not TheNet:IsDedicated() then
		InitParticles(inst)

		local portal = CreatePortal()
		portal.entity:SetParent(inst.entity)
	end

    --Dedicated servers need this too
    AddTerraformBlockers(inst)

    inst._unstable = net_bool(inst.GUID, "charlie_boss_trial.unstable", "onunstabledirty")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
        inst:ListenForEvent("onunstabledirty", OnUnstableDirty)
		return inst
	end

    inst.SetUnstable = SetUnstable

	inst.components.temperatureoverrider:SetRadius(TUNING.CHARLIE_ARENA_RADIUS)
	inst.components.temperatureoverrider:SetTemperature(TUNING.CHARLIE_ARENA_TEMPERATURE_OVERRIDE)
    inst.components.temperatureoverrider:Enable()

	inst:AddComponent("entitytracker")

	inst._oncharliebossdied = function(boss)
        UntrackCharlieBoss(inst)
        TheWorld:PushEvent("resetvault") -- defeating fuelweaver also resets vault
        TheWorld:PushEvent("ms_defeated_shrouden")
        Shard_SyncCharlieDefeated(true)
        SpawnExitCrack(inst)
	end

    inst._oncharliebosssettracking = function(boss, newboss)
        TrackCharlieBoss(inst, newboss)
    end

    -- charlie boss tries to set these but inst.OnRemoveEntity is called after event callbacks are removed, so we have to listen remove event here.
    inst._oncharliebossremoved = function(boss)
        OnShadowRunnersEnabled(inst, false)
        OnShadowHandsEnabled(inst, false)
        OnDreadstoneSpikesEnabled(inst, false)
    end
    inst._onshadowrunnersenabled = function(boss, enabled) OnShadowRunnersEnabled(inst, enabled) end
    inst._onshadowhandsenabled = function(boss, enabled) OnShadowHandsEnabled(inst, enabled) end

    inst.shadowrunnersdata = {
        totalrunnerscount = 0,
        runners = {},
    }
    inst._onremove_shadowrunner = function(runner)
        inst.shadowrunnersdata.totalrunnerscount = inst.shadowrunnersdata.totalrunnerscount - 1
        inst.shadowrunnersdata.runners[runner] = nil
    end

    inst.shadowhandsdata = {
        totalhandscount = 0,
        hands = {},
    }
    inst.TryToFindSpawnPointForHand = TryToFindSpawnPointForHand
    inst.TryToFindHandTargetForPlayer = TryToFindHandTargetForPlayer
    inst.TryToMakeHandForPlayer = TryToMakeHandForPlayer
    inst.DissipateAllShadowHands = DissipateAllShadowHands
    inst._onremove_shadowhand = function(hand)
        inst.shadowhandsdata.totalhandscount = inst.shadowhandsdata.totalhandscount - 1
        SHROUDED_HAND_TARGETS[inst.shadowhandsdata.hands[hand]] = nil
        inst.shadowhandsdata.hands[hand] = nil
    end

    --

    inst._onarenaunstable = function(boss) inst:SetUnstable(true) end
    inst._ondreadstonespikesenabled = function(boss, enabled) OnDreadstoneSpikesEnabled(inst, enabled) end

    inst.dreadstonespikesdata = {
        totalspikescount = 0,
        dreadstonespikes = {},
    }
    inst._onremove_dreadstonespike = function(spike)
        inst.dreadstonespikesdata.totalspikescount = inst.dreadstonespikesdata.totalspikescount - 1
        inst.dreadstonespikesdata.dreadstonespikes[spike] = nil
    end

	inst.InitializeLayout = InitializeLayout
    inst.OnSave = OnSave
	inst.OnLoadPostPass = OnLoadPostPass

    inst:DoTaskInTime(0, CreateGlobalIcon)

	return inst
end

return Prefab("charlie_boss_trial", fn, assets, prefabs)
